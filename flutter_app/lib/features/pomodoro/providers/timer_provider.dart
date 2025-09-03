import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/services/timer_session_controller.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/app_constants.dart'; // Import AppConstants
import '../../todo/providers/todos_provider.dart';
import '../../todo/models/todo.dart';
import '../notifications/persistent_timer_notification_model.dart';
import '../../../core/data/todo_repository.dart';
import '../models/timer_state.dart';
import '../services/timer_persistence_manager.dart';
import '../../../core/constants/sound_assets.dart'; // added
import '../../../core/services/workmanager_timer_service.dart'; // added
import '../services/timer_autosave_service.dart';
import '../services/timer_background_scheduler.dart';
import '../services/timer_overdue_service.dart';
import '../services/phase_transition_service.dart';
import '../services/foreground_ticker.dart';
import '../services/notification_action_handler.dart';
import '../../../core/constants/timer_defaults.dart';

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

  int _lastAutoSavedSeconds = 0;
  bool _processingOverdue = false;
  TimerSessionController? _sessionController;
  DateTime? _lastStartAttempt;
  late final TimerPersistenceManager _persistenceManager;
  late SharedPreferences _prefs; // Hold SharedPreferences instance
  late String _apiBaseUrl; // Store API base URL from main app
  late bool _isDebugMode; // Store debug mode from main app
  final WorkmanagerTimerService _wmService =
      WorkmanagerTimerService(); // new service
  TimerAutoSaveService? _autoSaveService; // extracted
  final Logger logger = Logger();
  TimerBackgroundScheduler? _backgroundScheduler; // extracted
  TimerOverdueService? _overdueService; // extracted
  PhaseTransitionService? _phaseService;
  ForegroundTicker? _foregroundTicker;
  NotificationActionHandler? _actionHandler;

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
      _autoSaveService ??= TimerAutoSaveService(this, ref);
      _backgroundScheduler ??= TimerBackgroundScheduler(_persistenceManager);
      _overdueService ??= TimerOverdueService(notifier: this, ref: ref);
      _phaseService ??= PhaseTransitionService(notifier: this, ref: ref);
      _foregroundTicker ??= ForegroundTicker();
      _actionHandler ??= NotificationActionHandler(notifier: this, ref: ref);
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
      _autoSaveService?.stop();
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
        logger.i('[TimerNotifier] Workmanager task cancelled on dispose.');
      }
    });

    return const TimerState();
  }

  /// Public helper for services to persist current state safely.
  Future<void> persistState() async {
    await _persistenceManager.saveTimerState(state);
  }

  /// Restores the timer state from SharedPreferences when the notifier is built.
  Future<void> _restoreTimerState() async {
    final TimerState? savedState = _persistenceManager.loadTimerState();
    if (savedState != null) {
      logger.i(
        '[TimerNotifier] Restoring timer state from preferences: $savedState',
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

        logger.d(
          '[TimerNotifier] Elapsed since background: $elapsedSinceBackground seconds.',
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
    logger.i('[TimerNotifier] Handling background session completion...');

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

    logger.i(
      '[TimerNotifier] Background session completion handled. State reset.',
    );
  }

  /// Saves the current timer state to SharedPreferences.
  Future<void> _saveTimerStateToPrefs() async {
    await _persistenceManager.saveTimerState(state);
    logger.d('[TimerNotifier] State saved to prefs.');
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

    logger.i(
      '[TimerNotifier] Scheduling Workmanager task for $remainingSeconds seconds for Task ID: $taskId',
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
    logger.i(
      '[TimerNotifier] Workmanager task scheduled to fire in ${delay.inSeconds} seconds.',
    );
  }

  /// Cancels any scheduled Workmanager task.
  Future<void> _cancelWorkmanagerTask() async {
    await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
    await _persistenceManager.setSessionScheduled(false);
    logger.i('[TimerNotifier] Workmanager task cancelled.');
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
    _ticker?.cancel(); // legacy timer
    _startAutoSaveTimer();
    _autoSaveService?.start();
    _foregroundTicker?.start(
      onTick: () {
        if (state.currentMode == 'focus' && state.activeTaskId != null) {
          final int taskId = state.activeTaskId!;
          final int currentFocused = state.focusedTimeCache[taskId] ?? 0;
          final newCache = Map<int, int>.from(state.focusedTimeCache);
          newCache[taskId] = currentFocused + 1;
          update(focusedTimeCache: newCache);
        }
        if (state.timeRemaining > 0) {
          update(timeRemaining: state.timeRemaining - 1);
        }
      },
      onPhaseComplete: () {
        _handlePhaseCompletion();
      },
      onOverdueCheck: () {
        final int focused = state.focusedTimeCache[state.activeTaskId] ?? 0;
        final int? planned = state.plannedDurationSeconds;
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
      },
      stateProvider: () => state,
    );
  }

  void _handlePhaseCompletion() {
    _phaseService?.handlePhaseCompletion(state);

    // Reschedule or cancel background task depending on new state
    if (state.isRunning &&
        state.activeTaskId != null &&
        state.activeTaskName != null) {
      _scheduleWorkmanagerTask(
        state.activeTaskId!,
        state.activeTaskName!,
        state.timeRemaining,
      );
    } else {
      _cancelWorkmanagerTask();
    }
  }

  // Focus/break completion logic now resides in PhaseTransitionService

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _autoSaveService?.stop();
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
      logger.e('[TimerNotifier] SOUND/NOTIFICATION ERROR: $e');
    }

    _ticker?.cancel();
    _ticker = null;
    // Delegate to service
    _overdueService?.markOverdueAndFreeze(taskId);
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
        ? (state.focusDurationSeconds ?? TimerDefaults.focusSeconds)
        : (state.breakDurationSeconds ?? TimerDefaults.breakSeconds);
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
      logger.e('[TimerNotifier] Error saving progress: $e');
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
      logger.e('[TimerNotifier] SOUND/NOTIFICATION ERROR: $e');
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
    logger.i('⏸️ PAUSE requested. Current state: $state');
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
    logger.i('⏸️ PAUSE complete. New state: $state');
  }

  void resumeTask() {
    if (!state.isRunning) {
      logger.i('▶️ RESUME requested. Current state: $state');
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
      logger.i('▶️ RESUME complete. New state: $state');
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
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: TimerDefaults.autoSaveIntervalSeconds),
      (_) {
        _triggerDeferredAutoSave();
      },
    );
  }

  void _triggerDeferredAutoSave() {
    final taskId = state.activeTaskId;
    if (taskId == null) return;
    final currentFocused = state.focusedTimeCache[taskId] ?? 0;
    if (currentFocused - _lastAutoSavedSeconds <
        TimerDefaults.autoSaveIntervalSeconds)
      return;
    _autoSaveService?.triggerDeferredAutoSave();
  }

  void skipPhase() {
    _phaseService?.skipPhase(state);
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
    logger.i(
      '[TimerNotifier] Background persistence scheduled via Workmanager.',
    );
  }

  /// Cancel any background persistence Workmanager tasks.
  Future<void> cancelBackgroundPersistence() async {
    if (_persistenceManager.isSessionScheduled()) {
      await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
      await _persistenceManager.setSessionScheduled(false);
      logger.i('[TimerNotifier] Background persistence cancelled.');
    }

    // Reset background tracking flags when returning to foreground
    update(wasInBackground: false, backgroundStartTime: null);

    // If a persistent notification was shown by Workmanager, cancel it.
    ref.read(notificationServiceProvider).cancelPersistentTimerNotification();
  }

  /// Handle action button taps from the persistent notification.
  Future<void> handleNotificationAction(String actionId) async {
    logger.i("⚙️ TimerNotifier handling notification action: '$actionId'");
    await _actionHandler?.handle(actionId);
    logger.d("✅ TimerNotifier finished handling action: '$actionId'");
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);
