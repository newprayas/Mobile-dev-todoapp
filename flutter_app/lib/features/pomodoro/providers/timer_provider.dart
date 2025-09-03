import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/services/timer_session_controller.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/utils/app_constants.dart'; // Import AppConstants
import '../../../core/utils/helpers.dart'; // Import formatTime
import '../../todo/providers/todos_provider.dart';
import '../../todo/models/todo.dart';
import '../notifications/persistent_timer_notification_model.dart';
import '../../../core/data/todo_repository.dart';
import '../models/timer_state.dart';
import '../services/timer_persistence_manager.dart';
import '../../../core/constants/sound_assets.dart'; // added
import '../../../core/services/workmanager_timer_service.dart'; // added

/// Business logic + orchestration layer for the Pomodoro timer feature.
///
/// Responsibilities:
/// - Drive countdown / phase transitions
/// - Persist & restore state via [TimerPersistenceManager]
/// - Interact with Workmanager for background completion
/// - Dispatch user notifications / sounds
/// - Maintain focused time cache (optimistic updates ahead of DB writes)
class TimerNotifier extends Notifier<TimerState> {
  Timer? _ticker;
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  int _lastAutoSavedSeconds = 0;
  bool _processingOverdue = false;
  TimerSessionController? _sessionController;
  DateTime? _lastStartAttempt;
  late final TimerPersistenceManager _persistenceManager;
  late SharedPreferences _prefs; // Hold SharedPreferences instance
  late String _apiBaseUrl; // Store API base URL from main app
  late bool _isDebugMode; // Store debug mode from main app
  final WorkmanagerTimerService _wmService = WorkmanagerTimerService(); // new service

  @override
  TimerState build() {
    _sessionController ??= TimerSessionController();

    Future(() async {
      _prefs = await SharedPreferences.getInstance();
      _persistenceManager = TimerPersistenceManager(_prefs);

      // Retrieve ApiService config: prefer saved SharedPreferences (set by main.dart or TimerNotifier before scheduling WM tasks).
      // Fallback to sensible defaults if missing.
      _apiBaseUrl =
          _prefs.getString(AppConstants.prefApiBaseUrl) ??
          'http://127.0.0.1:5000';
      _isDebugMode = _prefs.getBool(AppConstants.prefIsDebugMode) ?? kDebugMode;

      await _restoreTimerState(); // Restore state during build
    });

    ref.listen<AsyncValue<List<Todo>>>(todosProvider, (_, next) {
      next.whenData((todos) {
        final currentCache = state.focusedTimeCache;
        final newCacheFromDB = {
          for (var todo in todos) todo.id: todo.focusedTime,
        };
        final mergedCache = Map<int, int>.from(newCacheFromDB);

        currentCache.forEach((taskId, liveSeconds) {
          if (liveSeconds > (newCacheFromDB[taskId] ?? -1)) {
            mergedCache[taskId] = liveSeconds;
          }
        });

        if (!mapEquals(state.focusedTimeCache, mergedCache)) {
          Future.microtask(() {
            state = state.copyWith(focusedTimeCache: mergedCache);
            _persistenceManager.saveTimerState(state); // Save after update
          });
        }
      });
    });

    ref.onDispose(() {
      _ticker?.cancel();
      _autoSaveTimer?.cancel();
      // Ensure state is saved on dispose, marking as not running
      _persistenceManager.saveTimerState(
        state.copyWith(
          isRunning: false,
          wasInBackground: false,
          backgroundStartTime: null,
        ),
      );
      // Cancel Workmanager task if one exists and timer was running
      if (state.activeTaskId != null &&
          _persistenceManager.isSessionScheduled()) {
        _wmService.cancelPomodoroTask();
        _persistenceManager.setSessionScheduled(false);
        ref
            .read(notificationServiceProvider)
            .cancelPersistentTimerNotification(); // Cancel notification
        debugLog('TimerNotifier', 'Workmanager task cancelled on dispose.');
      }
    });

    return const TimerState();
  }

  /// Restores the timer state from SharedPreferences when the notifier is built.
  Future<void> _restoreTimerState() async {
    final TimerState? savedState = _persistenceManager.loadTimerState();
    if (savedState != null) {
      debugLog(
        'TimerNotifier',
        'Restoring timer state from preferences: $savedState',
      );

      // Adjust timeRemaining if it was running in the background
      if (savedState.wasInBackground &&
          savedState.isRunning &&
          savedState.backgroundStartTime != null) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        final int elapsedSinceBackground =
            (now - savedState.backgroundStartTime!) ~/ 1000;
        int restoredTimeRemaining =
            savedState.timeRemaining - elapsedSinceBackground;

        debugLog(
          'TimerNotifier',
          'Elapsed since background: $elapsedSinceBackground seconds.',
        );

        if (restoredTimeRemaining <= 0) {
          // If the session completed in the background, update state accordingly
          await _handleBackgroundSessionCompletion(
            savedState,
          ); // Pass savedState directly
          state = state.copyWith(
            isRunning: false,
            timeRemaining: 0,
            isTimerActive: false,
            wasInBackground: false,
            backgroundStartTime: null,
            allSessionsComplete:
                _prefs.getBool(AppConstants.prefAllSessionsComplete) ?? false,
            overdueSessionsComplete:
                _prefs.getBool(AppConstants.prefOverdueSessionsComplete) ??
                false,
          );
        } else {
          // Resume normal operation with adjusted time
          state = savedState.copyWith(
            timeRemaining: restoredTimeRemaining,
            wasInBackground: false,
            backgroundStartTime: null,
          );
          // If it was running and scheduled, restart ticker and show persistent notification
          if (state.isRunning && _persistenceManager.isSessionScheduled()) {
            startTicker();
            await _showPersistentNotification(); // Show notification on restore
          }
        }
      } else {
        // Not running in background or no background time to adjust
        state = savedState.copyWith(
          wasInBackground: false,
          backgroundStartTime: null,
        );
        // If it was running, ensure ticker is started and notification shown.
        if (state.isRunning) {
          startTicker();
          await _showPersistentNotification(); // Show notification on restore
        }
      }
    }
  }

  /// Handles session completion that occurred while the app was in the background.
  Future<void> _handleBackgroundSessionCompletion(
    TimerState backgroundState,
  ) async {
    debugLog('TimerNotifier', 'Handling background session completion...');

    final int? activeTaskId = backgroundState.activeTaskId;
    if (activeTaskId == null) return;

    // Retrieve focused time updated by background Workmanager task
    final String? focusedTimeCacheJson = _prefs.getString(
      AppConstants.prefFocusedTimeCache,
    );
    final Map<int, int> focusedTimeCache = focusedTimeCacheJson != null
        ? Map<String, int>.from(
            json.decode(focusedTimeCacheJson),
          ).map((k, v) => MapEntry(int.parse(k), v))
        : {};

    // Ensure the main app's focused time cache is updated
    state = state.copyWith(focusedTimeCache: focusedTimeCache);

    // Update todo in DB with final focused time
    final todoRepository = ref.read(todoRepositoryProvider);
    await todoRepository.updateFocusTime(
      activeTaskId,
      focusedTimeCache[activeTaskId] ?? 0,
    );

    // Clear Workmanager task if it's still registered
    await _cancelWorkmanagerTask();

    // Clear all persisted timer state as session is complete
    await _persistenceManager.clearTimerState();

    debugLog(
      'TimerNotifier',
      'Background session completion handled. State reset.',
    );
  }

  /// Saves the current timer state to SharedPreferences.
  Future<void> _saveTimerStateToPrefs() async {
    await _persistenceManager.saveTimerState(state);
    debugLog('TimerNotifier', 'State saved to prefs.');
  }

  /// Schedules a one-off Workmanager task for the remaining time.
  Future<void> _scheduleWorkmanagerTask(
    int taskId,
    String taskName,
    int remainingSeconds,
  ) async {
    // Only schedule if actually running
    if (remainingSeconds <= 0 || !state.isRunning) {
      await _cancelWorkmanagerTask();
      return;
    }

    await _cancelWorkmanagerTask(); // Cancel any existing before scheduling new

    // Save ApiService config for the background isolate
    await _persistenceManager.saveApiConfig(_apiBaseUrl, _isDebugMode);

    // Ensure state is saved right before scheduling, marking as in background
    await _saveTimerStateToPrefs();

    debugLog(
      'TimerNotifier',
      'Scheduling Workmanager task for $remainingSeconds seconds for Task ID: $taskId',
    );

    // Workmanager min duration for one-off task is 10 minutes on Android/iOS for guarantee.
    // Use actual remainingSeconds + a buffer.
    final Duration delay = Duration(seconds: remainingSeconds + 5);

    await Workmanager().registerOneOffTask(
      AppConstants.pomodoroTimerTask,
      AppConstants.pomodoroTimerTask,
      initialDelay: delay,
      existingWorkPolicy:
          ExistingWorkPolicy.replace, // Replaces if task with same name exists
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresDeviceIdle: false, // Ensure it runs even if device is active
        requiresCharging: false,
        requiresBatteryNotLow: false,
      ),
      inputData: {
        'apiBaseUrl': _apiBaseUrl,
        'isDebugMode': _isDebugMode,
        // Pass essential current state for the background task to start correctly
        'activeTaskId': taskId,
        'activeTaskText': taskName,
        'timeRemaining': remainingSeconds,
        'currentMode': state.currentMode,
        'focusedTimeCache': json.encode(
          state.focusedTimeCache.map((k, v) => MapEntry(k.toString(), v)),
        ),
        'plannedDurationSeconds': state.plannedDurationSeconds ?? 0,
        'focusDurationSeconds': state.focusDurationSeconds ?? 0,
        'breakDurationSeconds': state.breakDurationSeconds ?? 0,
        'currentCycle': state.currentCycle,
        'totalCycles': state.totalCycles,
        'completedSessions': state.completedSessions,
        'isPermanentlyOverdue': state.isPermanentlyOverdue,
      },
    );
    await _persistenceManager.setSessionScheduled(true); // Mark as scheduled
    debugLog(
      'TimerNotifier',
      'Workmanager task scheduled to fire in ${delay.inSeconds} seconds.',
    );
  }

  /// Cancels any scheduled Workmanager task.
  Future<void> _cancelWorkmanagerTask() async {
    await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
    await _persistenceManager.setSessionScheduled(false);
    debugLog('TimerNotifier', 'Workmanager task cancelled.');
  }

  void update({
    int? activeTaskId,
    String? activeTaskName,
    int? timeRemaining,
    bool? isRunning,
    bool? isTimerActive,
    String? currentMode,
    int? plannedDurationSeconds,
    int? focusDurationSeconds,
    int? breakDurationSeconds,
    int? currentCycle,
    int? totalCycles,
    int? completedSessions,
    bool? isProgressBarFull,
    bool? allSessionsComplete,
    bool? overdueSessionsComplete,
    int? overdueCrossedTaskId,
    String? overdueCrossedTaskName,
    Set<int>? overduePromptShown,
    Set<int>? overdueContinued,
    Map<int, int>? focusedTimeCache,
    bool? suppressNextActivation,
    bool? cycleOverflowBlocked,
    bool? isPermanentlyOverdue,
    int? backgroundStartTime,
    int? pausedTimeTotal,
    bool? wasInBackground,
  }) {
    final newState = state.copyWith(
      activeTaskId: activeTaskId,
      activeTaskName: activeTaskName,
      timeRemaining: timeRemaining,
      isRunning: isRunning,
      isTimerActive: isTimerActive,
      currentMode: currentMode,
      plannedDurationSeconds: plannedDurationSeconds,
      focusDurationSeconds: focusDurationSeconds,
      breakDurationSeconds: breakDurationSeconds,
      currentCycle: currentCycle,
      totalCycles: totalCycles,
      completedSessions: completedSessions,
      isProgressBarFull: isProgressBarFull,
      allSessionsComplete: allSessionsComplete,
      overdueSessionsComplete: overdueSessionsComplete,
      overdueCrossedTaskId: overdueCrossedTaskId,
      overdueCrossedTaskName: overdueCrossedTaskName,
      overduePromptShown: overduePromptShown,
      overdueContinued: overdueContinued,
      focusedTimeCache: focusedTimeCache,
      suppressNextActivation: suppressNextActivation,
      cycleOverflowBlocked: cycleOverflowBlocked,
      isPermanentlyOverdue: isPermanentlyOverdue,
      backgroundStartTime: backgroundStartTime,
      pausedTimeTotal: pausedTimeTotal,
      wasInBackground: wasInBackground,
    );

    if (newState != state) {
      state = newState;
      _saveTimerStateToPrefs(); // Save state whenever it changes

      // Update persistent notification if timer is active
      if (state.isTimerActive && state.activeTaskId != null) {
        _showPersistentNotification();
      } else {
        ref
            .read(notificationServiceProvider)
            .cancelPersistentTimerNotification();
      }
    }
  }

  // Helper to show/update the persistent notification
  Future<void> _showPersistentNotification() async {
    final notificationService = ref.read(notificationServiceProvider);
    final todos = ref.read(todosProvider).value;
    final active = todos?.firstWhere(
      (t) => t.id == state.activeTaskId,
      orElse: () => null as dynamic,
    );
    final model = PersistentTimerNotificationModel.fromState(
      state: state,
      activeTodo: active is Todo ? active : null,
    );
    await notificationService.showOrUpdatePersistent(
      title: model.title,
      body: model.body,
      actionIds: model.actionIds,
    );
  }

  void markOverduePromptShown(int taskId) {
    final newPromptShown = Set<int>.from(state.overduePromptShown)..add(taskId);
    update(overduePromptShown: newPromptShown);
  }

  void markOverdueContinued(int taskId) {
    final newOverdueContinued = Set<int>.from(state.overdueContinued)
      ..add(taskId);
    update(overdueContinued: newOverdueContinued);
  }

  void updateFocusedTime(int taskId, int seconds) {
    final newFocusedTimeCache = Map<int, int>.from(state.focusedTimeCache);
    newFocusedTimeCache[taskId] = seconds;
    update(focusedTimeCache: newFocusedTimeCache);
  }

  int getFocusedTime(int taskId) {
    return state.focusedTimeCache[taskId] ?? 0;
  }

  void startTicker() {
    _ticker?.cancel();
    _startAutoSaveTimer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;

      if (state.currentMode == 'focus' && state.activeTaskId != null) {
        final taskId = state.activeTaskId!;
        final currentFocused = state.focusedTimeCache[taskId] ?? 0;
        final newCache = Map<int, int>.from(state.focusedTimeCache);
        newCache[taskId] = currentFocused + 1;
        update(focusedTimeCache: newCache);
      }

      if (state.timeRemaining > 0) {
        update(timeRemaining: state.timeRemaining - 1);
      } else {
        _handlePhaseCompletion();
      }

      final focused = state.focusedTimeCache[state.activeTaskId] ?? 0;
      final planned = state.plannedDurationSeconds;
      if (!state.isPermanentlyOverdue &&
          !_processingOverdue &&
          state.currentMode == 'focus' &&
          state.activeTaskId != null &&
          planned != null &&
          planned > 0) {
        if (focused >= planned &&
            state.overdueCrossedTaskId != state.activeTaskId) {
          _processingOverdue = true;
          _markOverdueAndFreeze(state.activeTaskId!);
          _processingOverdue = false;
        }
      }
    });
  }

  void _handlePhaseCompletion() {
    if (state.currentMode == 'focus') {
      _handleFocusPhaseCompletion();
    } else if (state.currentMode == 'break') {
      _handleBreakPhaseCompletion();
    } else {
      stop();
    }

    // Reschedule or cancel background task depending on new state
    if (state.isRunning && state.activeTaskId != null && state.activeTaskName != null) {
      _scheduleWorkmanagerTask(
        state.activeTaskId!,
        state.activeTaskName!,
        state.timeRemaining,
      );
    } else {
      _cancelWorkmanagerTask();
    }
  }

  void _handleFocusPhaseCompletion() {
    final int completed = state.completedSessions + 1;
    if (completed >= state.totalCycles) {
      if (state.isPermanentlyOverdue && !state.overdueSessionsComplete) {
        debugLog('TimerNotifier', 'Overdue task session complete taskId=${state.activeTaskId}');
        ref.read(notificationServiceProvider).playSoundWithNotification(
          soundFileName: SoundAsset.sessionComplete.fileName,
          title: 'Session Complete!',
          body: 'Overdue task session completed for "${state.activeTaskName}".',
        );
        update(overdueSessionsComplete: true, isRunning: false, completedSessions: completed);
        stopTicker();
      } else if (!state.allSessionsComplete) {
        debugLog('TimerNotifier', 'All focus sessions complete taskId=${state.activeTaskId}');
        ref.read(notificationServiceProvider).playSoundWithNotification(
          soundFileName: SoundAsset.sessionComplete.fileName,
          title: 'All Sessions Complete!',
          body: 'All planned sessions completed for "${state.activeTaskName}".',
        );
        update(allSessionsComplete: true, isRunning: false, completedSessions: completed);
        stopTicker();
      }
      if (!state.isRunning && state.timeRemaining == 0) {
        stopTicker();
        return;
      }
    } else {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.playSoundWithNotification(
        soundFileName: SoundAsset.breakStart.fileName,
        title: 'Focus Session Complete!',
        body: 'Time for a break for "${state.activeTaskName}".',
      );
      final nextCycle = (state.currentCycle + 1) <= state.totalCycles
          ? state.currentCycle + 1
          : state.totalCycles;
      update(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds,
        currentCycle: nextCycle,
        completedSessions: completed,
      );
    }
  }

  void _handleBreakPhaseCompletion() {
    if (state.focusDurationSeconds != null) {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.playSound(SoundAsset.focusStart.fileName);
      notificationService.showNotification(
        title: 'Break Complete!',
        body: 'Time to focus on "${state.activeTaskName}" again!',
      );
      update(currentMode: 'focus', timeRemaining: state.focusDurationSeconds);
    } else {
      stop();
    }
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _cancelWorkmanagerTask();
    _saveTimerStateToPrefs();
  }

  void _markOverdueAndFreeze(int taskId) {
    _sessionController?.handleEvent(TimerSessionEvent.overdueReached);

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final todos = ref.read(todosProvider).value ?? [];
      try {
        final task = todos.firstWhere((t) => t.id == taskId);
        // Play sound with notification for better background operation
        notificationService.playSoundWithNotification(
          soundFileName: SoundAsset.sessionComplete.fileName,
          title: 'Planned Time Complete!',
          body:
              'Time for "${task.text}" is up. Decide whether to continue or complete.',
        );
      } catch (e) {
        // Task not found, skip notification
      }
    } catch (e) {
      debugLog('TimerNotifier', 'SOUND/NOTIFICATION ERROR: $e');
    }

    _ticker?.cancel();
    _ticker = null;
    update(
      isRunning: false,
      timeRemaining: 0,
      isProgressBarFull: true,
      overdueCrossedTaskId: taskId,
      plannedDurationSeconds: null,
      focusDurationSeconds: null,
      breakDurationSeconds: null,
      currentCycle: 1,
      totalCycles: 1,
    );
    _cancelWorkmanagerTask();
  }

  void stop() {
    update(isRunning: false);
    stopTicker();
    _saveTimerStateToPrefs();
  }

  void clear() {
    stopTicker();
    _sessionController?.forceReset();
    _persistenceManager.clearTimerState();
    state = const TimerState();
    _cancelWorkmanagerTask();
  }

  void resetCurrentPhase() {
    if (state.activeTaskId == null) return;

    final currentPhaseDuration = state.currentMode == 'focus'
        ? (state.focusDurationSeconds ?? 25 * 60)
        : (state.breakDurationSeconds ?? 5 * 60);
    final elapsedTime = currentPhaseDuration - state.timeRemaining;

    if (state.currentMode == 'focus' && elapsedTime > 0) {
      final taskId = state.activeTaskId!;
      final currentFocusedTime = getFocusedTime(taskId);
      final newFocusedTime = (currentFocusedTime - elapsedTime)
          .clamp(0, double.infinity)
          .toInt();
      updateFocusedTime(taskId, newFocusedTime);
    }

    update(timeRemaining: currentPhaseDuration, isRunning: false);
    stopTicker();
    _cancelWorkmanagerTask();
  }

  void clearPreserveProgress() {
    stopTicker();
    _sessionController?.handleEvent(TimerSessionEvent.abort);
    state = TimerState(focusedTimeCache: state.focusedTimeCache);
    _persistenceManager.clearTimerState();
    _persistenceManager.saveTimerState(
      state.copyWith(focusedTimeCache: state.focusedTimeCache),
    );
    _cancelWorkmanagerTask();
  }

  Future<bool> stopAndSaveProgress(int todoId) async {
    if (state.activeTaskId == null) {
      clear();
      return true;
    }

    try {
      final currentFocusedTime = state.focusedTimeCache[todoId] ?? 0;
      final todoRepository = ref.read(todoRepositoryProvider);
      await todoRepository.updateFocusTime(todoId, currentFocusedTime);
      clearPreserveProgress();
      return true;
    } catch (e) {
      debugLog('TimerNotifier', 'Error saving progress: $e');
      clearPreserveProgress();
      return false;
    }
  }

  void toggleRunning() {
    final nextRunning = !state.isRunning;
    update(isRunning: nextRunning);
    if (nextRunning) {
      startTicker();
      if (state.activeTaskId != null && state.activeTaskName != null) {
        _scheduleWorkmanagerTask(
          state.activeTaskId!,
          state.activeTaskName!,
          state.timeRemaining,
        );
      }
    } else {
      stopTicker();
      _cancelWorkmanagerTask();
      _saveTimerStateToPrefs();
    }
  }

  bool startTask({
    required int taskId,
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int plannedDuration,
    required int totalCycles,
    bool isPermanentlyOverdue = false,
  }) {
    final now = DateTime.now();
    if (_lastStartAttempt != null &&
        now.difference(_lastStartAttempt!).inMilliseconds < 500) {
      return false;
    }
    _lastStartAttempt = now;

    if (_sessionController?.currentState != TimerSessionState.idle) {
      _sessionController?.forceReset();
    }

    final success =
        _sessionController?.startSession(
          taskName: taskName,
          focusDurationSeconds: focusDuration,
          breakDurationSeconds: breakDuration,
          totalCycles: totalCycles,
        ) ??
        false;

    if (!success) return false;

    try {
      final notificationService = ref.read(notificationServiceProvider);
      // Play sound immediately for better user feedback
  notificationService.playSound(SoundAsset.focusStart.fileName);
      notificationService.showNotification(
        title: 'Focus Session Started!',
        body: 'Focus time for "$taskName". You\'ve got this!',
      );
    } catch (e) {
      debugLog('TimerNotifier', 'SOUND/NOTIFICATION ERROR: $e');
    }

    update(
      activeTaskId: taskId,
      activeTaskName: taskName,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      plannedDurationSeconds: plannedDuration,
      totalCycles: totalCycles,
      currentCycle: 1,
      timeRemaining: focusDuration,
      currentMode: 'focus',
      isTimerActive: true, // Mark as active when task starts
      isRunning: true,
      isPermanentlyOverdue: isPermanentlyOverdue,
      wasInBackground: false,
      backgroundStartTime: null,
      pausedTimeTotal: 0,
    );
    startTicker();
    _scheduleWorkmanagerTask(taskId, taskName, focusDuration);
    _showPersistentNotification(); // Show persistent notification
    return true;
  }

  void pauseTask() {
    update(
      isRunning: false,
      // Record elapsed time if the timer was active in a phase
      pausedTimeTotal:
          state.pausedTimeTotal +
          (state.currentMode == 'focus'
              ? (state.focusDurationSeconds ?? 0)
              : (state.breakDurationSeconds ?? 0)) -
          state.timeRemaining,
    );
    stopTicker();
    _triggerDeferredAutoSave();
    _cancelWorkmanagerTask();
  _showPersistentNotification();
  }

  void resumeTask() {
    if (!state.isRunning) {
      update(isRunning: true);
      startTicker();
      _startAutoSaveTimer();
      if (state.activeTaskId != null && state.activeTaskName != null) {
        _scheduleWorkmanagerTask(
          state.activeTaskId!,
          state.activeTaskName!,
          state.timeRemaining,
        );
      }
      _showPersistentNotification(); // Update notification on resume
    }
  }

  void updateDurations({
    int? focusDuration,
    int? breakDuration,
    int? totalCycles,
  }) {
    update(
      focusDurationSeconds: focusDuration ?? state.focusDurationSeconds,
      breakDurationSeconds: breakDuration ?? state.breakDurationSeconds,
      totalCycles: totalCycles ?? state.totalCycles,
      timeRemaining:
          (!state.isRunning &&
              state.currentMode == 'focus' &&
              focusDuration != null &&
              state.currentCycle == 0)
          ? focusDuration
          : state.timeRemaining,
    );
  }

  void resetForSetupWithTask({
    required int taskId,
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
    required int plannedDuration,
    required bool isPermanentlyOverdue,
  }) {
    stopTicker();
    final cache = state.focusedTimeCache;
    update(
      activeTaskId: taskId,
      activeTaskName: taskName,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      totalCycles: totalCycles,
      plannedDurationSeconds: plannedDuration,
      timeRemaining: focusDuration,
      currentMode: 'focus',
      isRunning: false,
      currentCycle: 0,
      completedSessions: 0,
      isProgressBarFull: false,
      allSessionsComplete: false,
      overdueSessionsComplete: false,
      focusedTimeCache: cache,
      overdueCrossedTaskId: null,
      isTimerActive: false,
      isPermanentlyOverdue: isPermanentlyOverdue,
      wasInBackground: false,
      backgroundStartTime: null,
      pausedTimeTotal: 0,
    );
    _lastAutoSavedSeconds = state.focusedTimeCache[taskId] ?? 0;
    _cancelWorkmanagerTask();
    ref
        .read(notificationServiceProvider)
        .cancelPersistentTimerNotification(); // Ensure notification is off
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _triggerDeferredAutoSave();
    });
  }

  void _triggerDeferredAutoSave() {
    final taskId = state.activeTaskId;
    if (taskId == null) return;
    final currentFocused = state.focusedTimeCache[taskId] ?? 0;
    if (currentFocused - _lastAutoSavedSeconds < 30) return;

    _autoSaveFocusedTime(todoId: taskId);
  }

  Future<void> _autoSaveFocusedTime({
    required int todoId,
    bool force = false,
  }) async {
    final taskId = state.activeTaskId;
    if (taskId == null) return;
    final currentFocused = state.focusedTimeCache[taskId] ?? 0;
    if (!force && currentFocused <= _lastAutoSavedSeconds) return;
    if (_isAutoSaving) return;
    _isAutoSaving = true;
    try {
      final todoRepository = ref.read(todoRepositoryProvider);
      await todoRepository.updateFocusTime(todoId, currentFocused);
      _lastAutoSavedSeconds = currentFocused;
      _saveTimerStateToPrefs();
    } catch (e) {
      debugLog('TimerNotifier', 'Error auto-saving focused time: $e');
    } finally {
      _isAutoSaving = false;
    }
  }

  void skipPhase() {
    final notificationService = ref.read(notificationServiceProvider);
    if (state.currentMode == 'focus') {
      if (state.currentCycle >= state.totalCycles) {
        update(cycleOverflowBlocked: true);
        return;
      }
      // Play sound with notification for better background operation
      notificationService.playSoundWithNotification(
        soundFileName: SoundAsset.breakStart.fileName,
        title: 'Focus Phase Skipped',
        body: 'Moving to break time for "${state.activeTaskName}".',
      );
      final completed = state.completedSessions + 1;
      final nextCycle = state.currentCycle + 1;
      update(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds ?? state.timeRemaining,
        completedSessions: completed,
        currentCycle: nextCycle,
      );
    } else if (state.currentMode == 'break') {
      // Play sound immediately for better user feedback
  notificationService.playSound(SoundAsset.focusStart.fileName);
      update(
        currentMode: 'focus',
        timeRemaining: state.focusDurationSeconds ?? state.timeRemaining,
      );
    }
    if (state.activeTaskId != null && state.activeTaskName != null) {
      _scheduleWorkmanagerTask(
        state.activeTaskId!,
        state.activeTaskName!,
        state.timeRemaining,
      );
    }
    _showPersistentNotification(); // Update notification on skip
  }

  void clearAllSessionsCompleteFlag() {
    update(allSessionsComplete: false);
    _prefs.setBool(AppConstants.prefAllSessionsComplete, false);
  }

  void clearOverdueSessionsCompleteFlag() {
    if (state.overdueSessionsComplete) {
      update(overdueSessionsComplete: false);
      _prefs.setBool(AppConstants.prefOverdueSessionsComplete, false);
    }
  }

  void clearCycleOverflowBlockedFlag() {
    if (state.cycleOverflowBlocked) {
      update(cycleOverflowBlocked: false);
    }
  }

  /// Schedule a Workmanager one-off task to persist timer state while app is backgrounded.
  Future<void> scheduleBackgroundPersistence() async {
    if (state.activeTaskId == null || !state.isRunning) return;

    // Set background flags and save state BEFORE scheduling
    update(
      wasInBackground: true,
      backgroundStartTime: DateTime.now().millisecondsSinceEpoch,
    );

    // Save current API config for background isolate usage
    await _persistenceManager.saveApiConfig(_apiBaseUrl, _isDebugMode);

    await Workmanager().registerOneOffTask(
      AppConstants.pomodoroTimerTask,
      AppConstants.pomodoroTimerTask,
      // Schedule to fire after the current phase theoretically ends + a buffer
      initialDelay: Duration(seconds: state.timeRemaining + 5),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
      inputData: {
        'apiBaseUrl': _apiBaseUrl,
        'isDebugMode': _isDebugMode,
        // Pass essential current state for the background task to start correctly
        'activeTaskId': state.activeTaskId!,
        'activeTaskText': state.activeTaskName!,
        'timeRemaining': state.timeRemaining,
        'currentMode': state.currentMode,
        'focusedTimeCache': json.encode(
          state.focusedTimeCache.map((k, v) => MapEntry(k.toString(), v)),
        ),
        'plannedDurationSeconds': state.plannedDurationSeconds ?? 0,
        'focusDurationSeconds': state.focusDurationSeconds ?? 0,
        'breakDurationSeconds': state.breakDurationSeconds ?? 0,
        'currentCycle': state.currentCycle,
        'totalCycles': state.totalCycles,
        'completedSessions': state.completedSessions,
        'isPermanentlyOverdue': state.isPermanentlyOverdue,
      },
    );
    await _persistenceManager.setSessionScheduled(true);
    debugLog(
      'TimerNotifier',
      'Background persistence scheduled via Workmanager.',
    );
  }

  /// Cancel any background persistence Workmanager tasks.
  Future<void> cancelBackgroundPersistence() async {
    if (_persistenceManager.isSessionScheduled()) {
      await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
      await _persistenceManager.setSessionScheduled(false);
      debugLog('TimerNotifier', 'Background persistence cancelled.');
    }

    // Reset background tracking flags when returning to foreground
    update(wasInBackground: false, backgroundStartTime: null);

    // If a persistent notification was shown by Workmanager, cancel it.
    ref.read(notificationServiceProvider).cancelPersistentTimerNotification();
  }

  /// Handle action button taps from the persistent notification.
  Future<void> handleNotificationAction(String actionId) async {
    switch (actionId) {
  case 'pause_timer':
        if (state.isRunning) pauseTask();
        break;
  case 'resume_timer':
        if (!state.isRunning) resumeTask();
        break;
      case 'stop_timer':
        if (state.activeTaskId != null) {
          await stopAndSaveProgress(state.activeTaskId!);
        } else {
          clear();
        }
        break;
      case 'mark_complete':
        if (state.activeTaskId != null) {
          // Toggle completion; focused time already cached & persisted by autosave.
          await ref.read(todosProvider.notifier).toggleTodo(state.activeTaskId!);
          await stopAndSaveProgress(state.activeTaskId!);
        }
        break;
      case 'continue_working':
        if (state.activeTaskId != null) {
          state = state.copyWith(
            overdueContinued: Set<int>.from(state.overdueContinued)
              ..add(state.activeTaskId!),
            isPermanentlyOverdue: true,
            isProgressBarFull: false,
            plannedDurationSeconds: null,
            focusDurationSeconds: null,
          );
          _showPersistentNotification();
        }
        break;
    }
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);
