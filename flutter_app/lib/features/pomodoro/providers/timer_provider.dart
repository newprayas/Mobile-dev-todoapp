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
import '../../todo/providers/todos_provider.dart';
import '../../todo/models/todo.dart';
import '../../../core/data/todo_repository.dart';

class TimerState {
  final int? activeTaskId;
  final String? activeTaskName;
  final int timeRemaining; // seconds
  final bool isRunning;
  final bool isTimerActive; // whether mini-bar should show
  final String currentMode;
  final int? plannedDurationSeconds;
  final int? focusDurationSeconds;
  final int? breakDurationSeconds;
  final int currentCycle;
  final int totalCycles;
  final int completedSessions;
  final bool isProgressBarFull;
  final bool allSessionsComplete;
  final bool overdueSessionsComplete;
  final int? overdueCrossedTaskId;
  final String? overdueCrossedTaskName;
  final Set<int> overduePromptShown;
  final Set<int> overdueContinued;
  final Map<int, int> focusedTimeCache;
  final bool suppressNextActivation;
  final bool cycleOverflowBlocked;
  final bool isPermanentlyOverdue;

  // New fields for background timer management
  final int? backgroundStartTime; // Timestamp when app went to background
  final int pausedTimeTotal; // Total time spent paused (in seconds)
  final bool
  wasInBackground; // Flag if timer was active when app went to background

  const TimerState({
    this.activeTaskId,
    this.activeTaskName,
    this.timeRemaining = 0,
    this.isRunning = false,
    this.isTimerActive = false,
    this.currentMode = 'focus',
    this.plannedDurationSeconds,
    this.focusDurationSeconds,
    this.breakDurationSeconds,
    this.currentCycle = 1,
    this.totalCycles = 1,
    this.completedSessions = 0,
    this.isProgressBarFull = false,
    this.allSessionsComplete = false,
    this.overdueSessionsComplete = false,
    this.overdueCrossedTaskId,
    this.overdueCrossedTaskName,
    this.overduePromptShown = const {},
    this.overdueContinued = const {},
    this.focusedTimeCache = const {},
    this.suppressNextActivation = false,
    this.cycleOverflowBlocked = false,
    this.isPermanentlyOverdue = false,
    this.backgroundStartTime, // Initialize new fields
    this.pausedTimeTotal = 0,
    this.wasInBackground = false,
  });

  @override
  String toString() {
    return '''
TimerState(
  activeTaskId: $activeTaskId,
  timeRemaining: $timeRemaining,
  isRunning: $isRunning,
  isTimerActive: $isTimerActive,
  currentMode: $currentMode,
  currentCycle: $currentCycle / $totalCycles,
  completedSessions: $completedSessions,
  isPermanentlyOverdue: $isPermanentlyOverdue,
  overdueSessionsComplete: $overdueSessionsComplete,
  allSessionsComplete: $allSessionsComplete,
  backgroundStartTime: $backgroundStartTime,
  pausedTimeTotal: $pausedTimeTotal,
  wasInBackground: $wasInBackground
)''';
  }

  TimerState copyWith({
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
    // New fields for copyWith
    int? backgroundStartTime,
    int? pausedTimeTotal,
    bool? wasInBackground,
  }) {
    return TimerState(
      activeTaskId: activeTaskId ?? this.activeTaskId,
      activeTaskName: activeTaskName ?? this.activeTaskName,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isRunning: isRunning ?? this.isRunning,
      isTimerActive: isTimerActive ?? this.isTimerActive,
      currentMode: currentMode ?? this.currentMode,
      plannedDurationSeconds:
          plannedDurationSeconds ?? this.plannedDurationSeconds,
      focusDurationSeconds: focusDurationSeconds ?? this.focusDurationSeconds,
      breakDurationSeconds: breakDurationSeconds ?? this.breakDurationSeconds,
      currentCycle: currentCycle ?? this.currentCycle,
      totalCycles: totalCycles ?? this.totalCycles,
      completedSessions: completedSessions ?? this.completedSessions,
      isProgressBarFull: isProgressBarFull ?? this.isProgressBarFull,
      allSessionsComplete: allSessionsComplete ?? this.allSessionsComplete,
      overdueSessionsComplete:
          overdueSessionsComplete ?? this.overdueSessionsComplete,
      overdueCrossedTaskId: overdueCrossedTaskId ?? this.overdueCrossedTaskId,
      overdueCrossedTaskName:
          overdueCrossedTaskName ?? this.overdueCrossedTaskName,
      overduePromptShown: overduePromptShown ?? this.overduePromptShown,
      overdueContinued: overdueContinued ?? this.overdueContinued,
      focusedTimeCache: focusedTimeCache ?? this.focusedTimeCache,
      suppressNextActivation:
          suppressNextActivation ?? this.suppressNextActivation,
      cycleOverflowBlocked: cycleOverflowBlocked ?? this.cycleOverflowBlocked,
      isPermanentlyOverdue: isPermanentlyOverdue ?? this.isPermanentlyOverdue,
      // Pass new fields
      backgroundStartTime: backgroundStartTime ?? this.backgroundStartTime,
      pausedTimeTotal: pausedTimeTotal ?? this.pausedTimeTotal,
      wasInBackground: wasInBackground ?? this.wasInBackground,
    );
  }
}

/// A utility class for persisting and restoring TimerState using SharedPreferences.
class TimerPersistenceManager {
  final SharedPreferences _prefs;

  TimerPersistenceManager(this._prefs);

  Future<void> saveTimerState(TimerState state) async {
    // Save minimal state required for background execution or app restoration
    await _prefs.setInt(
      AppConstants.prefActiveTaskId,
      state.activeTaskId ?? -1,
    );
    await _prefs.setString(
      AppConstants.prefActiveTaskText,
      state.activeTaskName ?? '',
    );
    await _prefs.setInt(AppConstants.prefTimeRemaining, state.timeRemaining);
    await _prefs.setBool(AppConstants.prefIsRunning, state.isRunning);
    await _prefs.setBool(AppConstants.prefIsTimerActive, state.isTimerActive);
    await _prefs.setString(AppConstants.prefCurrentMode, state.currentMode);
    await _prefs.setInt(
      AppConstants.prefPlannedDurationSeconds,
      state.plannedDurationSeconds ?? 0,
    );
    await _prefs.setInt(
      AppConstants.prefFocusDurationSeconds,
      state.focusDurationSeconds ?? 0,
    );
    await _prefs.setInt(
      AppConstants.prefBreakDurationSeconds,
      state.breakDurationSeconds ?? 0,
    );
    await _prefs.setInt(AppConstants.prefCurrentCycle, state.currentCycle);
    await _prefs.setInt(AppConstants.prefTotalCycles, state.totalCycles);
    await _prefs.setInt(
      AppConstants.prefCompletedSessions,
      state.completedSessions,
    );
    await _prefs.setBool(
      AppConstants.prefIsProgressBarFull,
      state.isProgressBarFull,
    );
    await _prefs.setBool(
      AppConstants.prefAllSessionsComplete,
      state.allSessionsComplete,
    );
    await _prefs.setBool(
      AppConstants.prefOverdueSessionsComplete,
      state.overdueSessionsComplete,
    );
    await _prefs.setInt(
      AppConstants.prefOverdueCrossedTaskId,
      state.overdueCrossedTaskId ?? -1,
    );
    await _prefs.setString(
      AppConstants.prefOverdueCrossedTaskName,
      state.overdueCrossedTaskName ?? '',
    );
    await _prefs.setStringList(
      AppConstants.prefOverduePromptShown,
      state.overduePromptShown.map((e) => e.toString()).toList(),
    );
    await _prefs.setStringList(
      AppConstants.prefOverdueContinued,
      state.overdueContinued.map((e) => e.toString()).toList(),
    );

    final Map<String, int> focusedTimeCacheStringKeys = state.focusedTimeCache
        .map((k, v) => MapEntry(k.toString(), v));
    await _prefs.setString(
      AppConstants.prefFocusedTimeCache,
      json.encode(focusedTimeCacheStringKeys),
    );

    await _prefs.setBool(
      AppConstants.prefSuppressNextActivation,
      state.suppressNextActivation,
    );
    await _prefs.setBool(
      AppConstants.prefCycleOverflowBlocked,
      state.cycleOverflowBlocked,
    );
    await _prefs.setBool(
      AppConstants.prefIsPermanentlyOverdue,
      state.isPermanentlyOverdue,
    );
    await _prefs.setInt(
      AppConstants.prefBackgroundStartTime,
      state.backgroundStartTime ?? 0,
    );
    await _prefs.setInt(
      AppConstants.prefPausedTimeTotal,
      state.pausedTimeTotal,
    );
    await _prefs.setBool(
      AppConstants.prefWasInBackground,
      state.wasInBackground,
    );

    debugLog(
      'TimerPersistenceManager',
      'TimerState saved: ${state.toString()}',
    );
  }

  TimerState? loadTimerState() {
    final int? activeTaskIdRaw = _prefs.getInt(AppConstants.prefActiveTaskId);
    if (activeTaskIdRaw == null || activeTaskIdRaw == -1)
      return null; // No active timer saved

    final String? focusedTimeCacheJson = _prefs.getString(
      AppConstants.prefFocusedTimeCache,
    );
    final Map<int, int> focusedTimeCache = focusedTimeCacheJson != null
        ? Map<String, int>.from(
            json.decode(focusedTimeCacheJson),
          ).map((k, v) => MapEntry(int.parse(k), v))
        : {};

    final loadedState = TimerState(
      activeTaskId: activeTaskIdRaw,
      activeTaskName: _prefs.getString(AppConstants.prefActiveTaskText),
      timeRemaining: _prefs.getInt(AppConstants.prefTimeRemaining) ?? 0,
      isRunning: _prefs.getBool(AppConstants.prefIsRunning) ?? false,
      isTimerActive: _prefs.getBool(AppConstants.prefIsTimerActive) ?? false,
      currentMode: _prefs.getString(AppConstants.prefCurrentMode) ?? 'focus',
      plannedDurationSeconds:
          _prefs.getInt(AppConstants.prefPlannedDurationSeconds) ?? 0,
      focusDurationSeconds:
          _prefs.getInt(AppConstants.prefFocusDurationSeconds) ?? 0,
      breakDurationSeconds:
          _prefs.getInt(AppConstants.prefBreakDurationSeconds) ?? 0,
      currentCycle: _prefs.getInt(AppConstants.prefCurrentCycle) ?? 1,
      totalCycles: _prefs.getInt(AppConstants.prefTotalCycles) ?? 1,
      completedSessions: _prefs.getInt(AppConstants.prefCompletedSessions) ?? 0,
      isProgressBarFull:
          _prefs.getBool(AppConstants.prefIsProgressBarFull) ?? false,
      allSessionsComplete:
          _prefs.getBool(AppConstants.prefAllSessionsComplete) ?? false,
      overdueSessionsComplete:
          _prefs.getBool(AppConstants.prefOverdueSessionsComplete) ?? false,
      overdueCrossedTaskId:
          _prefs.getInt(AppConstants.prefOverdueCrossedTaskId) == -1
          ? null
          : _prefs.getInt(AppConstants.prefOverdueCrossedTaskId),
      overdueCrossedTaskName: _prefs.getString(
        AppConstants.prefOverdueCrossedTaskName,
      ),
      overduePromptShown: Set<int>.from(
        _prefs
                .getStringList(AppConstants.prefOverduePromptShown)
                ?.map(int.parse) ??
            [],
      ),
      overdueContinued: Set<int>.from(
        _prefs
                .getStringList(AppConstants.prefOverdueContinued)
                ?.map(int.parse) ??
            [],
      ),
      focusedTimeCache: focusedTimeCache,
      suppressNextActivation:
          _prefs.getBool(AppConstants.prefSuppressNextActivation) ?? false,
      cycleOverflowBlocked:
          _prefs.getBool(AppConstants.prefCycleOverflowBlocked) ?? false,
      isPermanentlyOverdue:
          _prefs.getBool(AppConstants.prefIsPermanentlyOverdue) ?? false,
      backgroundStartTime: _prefs.getInt(AppConstants.prefBackgroundStartTime),
      pausedTimeTotal: _prefs.getInt(AppConstants.prefPausedTimeTotal) ?? 0,
      wasInBackground:
          _prefs.getBool(AppConstants.prefWasInBackground) ?? false,
    );
    debugLog(
      'TimerPersistenceManager',
      'TimerState loaded: ${loadedState.toString()}',
    );
    return loadedState;
  }

  Future<void> clearTimerState() async {
    await _prefs.remove(AppConstants.prefActiveTaskId);
    await _prefs.remove(AppConstants.prefActiveTaskText);
    await _prefs.remove(AppConstants.prefTimeRemaining);
    await _prefs.remove(AppConstants.prefIsRunning);
    await _prefs.remove(AppConstants.prefIsTimerActive);
    await _prefs.remove(AppConstants.prefCurrentMode);
    await _prefs.remove(AppConstants.prefPlannedDurationSeconds);
    await _prefs.remove(AppConstants.prefFocusDurationSeconds);
    await _prefs.remove(AppConstants.prefBreakDurationSeconds);
    await _prefs.remove(AppConstants.prefCurrentCycle);
    await _prefs.remove(AppConstants.prefTotalCycles);
    await _prefs.remove(AppConstants.prefCompletedSessions);
    await _prefs.remove(AppConstants.prefIsProgressBarFull);
    await _prefs.remove(AppConstants.prefAllSessionsComplete);
    await _prefs.remove(AppConstants.prefOverdueSessionsComplete);
    await _prefs.remove(AppConstants.prefOverdueCrossedTaskId);
    await _prefs.remove(AppConstants.prefOverdueCrossedTaskName);
    await _prefs.remove(AppConstants.prefOverduePromptShown);
    await _prefs.remove(AppConstants.prefOverdueContinued);
    await _prefs.remove(AppConstants.prefFocusedTimeCache);
    await _prefs.remove(AppConstants.prefSuppressNextActivation);
    await _prefs.remove(AppConstants.prefCycleOverflowBlocked);
    await _prefs.remove(AppConstants.prefIsPermanentlyOverdue);
    await _prefs.remove(AppConstants.prefBackgroundStartTime);
    await _prefs.remove(AppConstants.prefPausedTimeTotal);
    await _prefs.remove(AppConstants.prefWasInBackground);
    await _prefs.remove(
      AppConstants.prefSessionScheduled,
    ); // Track if a session is scheduled in WM
    await _prefs.remove(AppConstants.prefApiBaseUrl); // Clear API URL
    await _prefs.remove(AppConstants.prefIsDebugMode); // Clear debug mode flag
    debugLog('TimerPersistenceManager', 'TimerState cleared from preferences.');
  }

  Future<void> setSessionScheduled(bool scheduled) async {
    await _prefs.setBool(AppConstants.prefSessionScheduled, scheduled);
  }

  bool isSessionScheduled() {
    return _prefs.getBool(AppConstants.prefSessionScheduled) ?? false;
  }

  // New methods to save/load API config for background
  Future<void> saveApiConfig(String baseUrl, bool isDebug) async {
    await _prefs.setString(AppConstants.prefApiBaseUrl, baseUrl);
    await _prefs.setBool(AppConstants.prefIsDebugMode, isDebug);
  }

  (String, bool)? loadApiConfig() {
    final String? baseUrl = _prefs.getString(AppConstants.prefApiBaseUrl);
    final bool? isDebug = _prefs.getBool(AppConstants.prefIsDebugMode);
    if (baseUrl != null && isDebug != null) {
      return (baseUrl, isDebug);
    }
    return null;
  }
}

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
        Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
        _persistenceManager.setSessionScheduled(false);
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
          // If it was running and scheduled, restart ticker and schedule WM for the remaining time
          if (state.isRunning && _persistenceManager.isSessionScheduled()) {
            startTicker();
            _scheduleWorkmanagerTask(
              state.activeTaskId!,
              state.activeTaskName!,
              restoredTimeRemaining,
            );
          }
        }
      } else {
        // Not running in background or no background time to adjust
        state = savedState.copyWith(
          wasInBackground: false,
          backgroundStartTime: null,
        );
        // If it was running, ensure ticker is started.
        if (state.isRunning) {
          startTicker();
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
    await _cancelWorkmanagerTask(); // This also sets `prefSessionScheduled` to false

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
      inputData: {'apiBaseUrl': _apiBaseUrl, 'isDebugMode': _isDebugMode},
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
    }
  }

  void markOverduePromptShown(int taskId) {
    final newPromptShown = Set<int>.from(state.overduePromptShown)..add(taskId);
    update(overduePromptShown: newPromptShown); // Use update to save to prefs
  }

  void markOverdueContinued(int taskId) {
    final newOverdueContinued = Set<int>.from(state.overdueContinued)
      ..add(taskId);
    update(
      overdueContinued: newOverdueContinued,
    ); // Use update to save to prefs
  }

  void updateFocusedTime(int taskId, int seconds) {
    final newFocusedTimeCache = Map<int, int>.from(state.focusedTimeCache);
    newFocusedTimeCache[taskId] = seconds;
    update(
      focusedTimeCache: newFocusedTimeCache,
    ); // Use update to save to prefs
  }

  int getFocusedTime(int taskId) {
    return state.focusedTimeCache[taskId] ?? 0;
  }

  void startTicker() {
    _ticker?.cancel();
    _startAutoSaveTimer(); // Auto-save timer still runs for foreground
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;

      if (state.currentMode == 'focus' && state.activeTaskId != null) {
        final taskId = state.activeTaskId!;
        final currentFocused = state.focusedTimeCache[taskId] ?? 0;
        final newCache = Map<int, int>.from(state.focusedTimeCache);
        newCache[taskId] = currentFocused + 1;
        update(focusedTimeCache: newCache); // Use update to save
      }

      if (state.timeRemaining > 0) {
        update(timeRemaining: state.timeRemaining - 1); // Use update to save
      } else {
        // TIMER PHASE COMPLETED
        if (state.currentMode == 'focus') {
          final completed = state.completedSessions + 1;

          // Check if all planned cycles are now complete
          if (completed >= state.totalCycles) {
            // If permanently overdue, handle special completion
            if (state.isPermanentlyOverdue && !state.overdueSessionsComplete) {
              debugLog(
                'TimerNotifier',
                'Overdue task session complete. Firing event.',
              );
              ref
                  .read(notificationServiceProvider)
                  .playSound('progress_bar_full.wav');
              update(
                overdueSessionsComplete: true,
                isRunning: false,
                completedSessions: completed,
              );
              stopTicker();
            } else if (!state.allSessionsComplete) {
              // Use allSessionsComplete to prevent multiple triggers
              debugLog(
                'TimerNotifier',
                'All focus sessions complete. Firing event.',
              );
              update(
                allSessionsComplete: true,
                isRunning: false,
                completedSessions: completed,
              );
              stopTicker();
            }
            // If already complete, just stop ticker and return
            if (!state.isRunning && state.timeRemaining == 0) {
              stopTicker();
              return;
            }
          } else {
            // Move to break session
            final notificationService = ref.read(notificationServiceProvider);
            notificationService.playSound('break_timer_start.wav');
            notificationService.showNotification(
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
        } else if (state.currentMode == 'break' &&
            state.focusDurationSeconds != null) {
          // Move to focus session
          final notificationService = ref.read(notificationServiceProvider);
          notificationService.playSound('focus_timer_start.wav');
          notificationService.showNotification(
            title: 'Break Complete!',
            body: 'Time to focus on "${state.activeTaskName}" again!',
          );
          update(
            currentMode: 'focus',
            timeRemaining: state.focusDurationSeconds,
          );
        } else {
          stop();
        }
        // After phase completion or transition, reschedule Workmanager if timer is still running
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

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _cancelWorkmanagerTask(); // Cancel background task if ticker stopped manually
    _saveTimerStateToPrefs(); // Save final state on stop
  }

  void _markOverdueAndFreeze(int taskId) {
    _sessionController?.handleEvent(TimerSessionEvent.overdueReached);

    try {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.playSound('progress_bar_full.wav');
      final todos = ref.read(todosProvider).value ?? [];
      try {
        final task = todos.firstWhere((t) => t.id == taskId);
        notificationService.showNotification(
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
      // Use update to trigger state saving
      isRunning: false,
      timeRemaining: 0,
      isProgressBarFull: true,
      overdueCrossedTaskId: taskId,
      plannedDurationSeconds: null, // Reset these for prompt
      focusDurationSeconds: null,
      breakDurationSeconds: null,
      currentCycle: 1, // Reset cycles for prompt
      totalCycles: 1,
    );
    _cancelWorkmanagerTask(); // Cancel background task here too
  }

  void stop() {
    update(isRunning: false);
    stopTicker();
    _saveTimerStateToPrefs(); // Ensure state is saved when explicitly stopped
  }

  void clear() {
    stopTicker();
    _sessionController?.forceReset();
    _persistenceManager.clearTimerState(); // Clear all state from prefs
    state = const TimerState(); // Reset to initial state
    _cancelWorkmanagerTask(); // Ensure WM task is cancelled
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

    update(
      // Use update to trigger state saving
      timeRemaining: currentPhaseDuration,
      isRunning: false,
    );
    stopTicker();
    _cancelWorkmanagerTask(); // Ensure WM task is cancelled
  }

  void clearPreserveProgress() {
    stopTicker();
    _sessionController?.handleEvent(TimerSessionEvent.abort);
    // Clear only temporary state, keep focusedTimeCache
    state = TimerState(focusedTimeCache: state.focusedTimeCache);
    _persistenceManager
        .clearTimerState(); // Clear all, then re-save cache if needed
    _persistenceManager.saveTimerState(
      state.copyWith(
        focusedTimeCache:
            state.focusedTimeCache, // Only save the preserved cache
      ),
    );
    _cancelWorkmanagerTask(); // Ensure WM task is cancelled
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
    update(isRunning: nextRunning); // Use update to save
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
      _cancelWorkmanagerTask(); // Cancel Workmanager task if paused manually
      _saveTimerStateToPrefs(); // Save state on pause
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
      notificationService.playSound('focus_timer_start.wav');
      notificationService.showNotification(
        title: 'Focus Session Started!',
        body: 'Focus time for "$taskName". You\'ve got this!',
      );
    } catch (e) {
      debugLog('TimerNotifier', 'SOUND/NOTIFICATION ERROR: $e');
    }

    update(
      // Use update to trigger state saving
      activeTaskId: taskId,
      activeTaskName: taskName,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      plannedDurationSeconds: plannedDuration,
      totalCycles: totalCycles,
      currentCycle: 1,
      timeRemaining: focusDuration,
      currentMode: 'focus',
      isTimerActive: false,
      isRunning: true,
      isPermanentlyOverdue: isPermanentlyOverdue,
      wasInBackground: false, // Reset this flag when starting fresh
      backgroundStartTime: null, // Clear background start time
      pausedTimeTotal: 0,
    );
    startTicker();
    _scheduleWorkmanagerTask(
      taskId,
      taskName,
      focusDuration,
    ); // Schedule WM task immediately
    return true;
  }

  void pauseTask() {
    update(
      isRunning: false,
      pausedTimeTotal:
          state.pausedTimeTotal +
          (state.focusDurationSeconds! - state.timeRemaining),
    ); // Increment paused time based on elapsed time in current phase
    stopTicker();
    _triggerDeferredAutoSave();
    _cancelWorkmanagerTask(); // Cancel background task when paused
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
    }
  }

  void updateDurations({
    int? focusDuration,
    int? breakDuration,
    int? totalCycles,
  }) {
    update(
      // Use update to trigger state saving
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
    required String
    taskName, // Added taskName for consistency with other methods
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
    required int plannedDuration,
    required bool isPermanentlyOverdue,
  }) {
    stopTicker(); // This also cancels WM task
    final cache = state.focusedTimeCache;
    update(
      // Use update to trigger state saving
      activeTaskId: taskId,
      activeTaskName: taskName, // Pass taskName
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
    _cancelWorkmanagerTask(); // Ensure WM task is cancelled
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
      _saveTimerStateToPrefs(); // Save state after auto-save to DB
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
        update(cycleOverflowBlocked: true); // Use update to save
        return;
      }
      notificationService.playSound('break_timer_start.wav');
      final completed = state.completedSessions + 1;
      final nextCycle = state.currentCycle + 1;
      update(
        // Use update to trigger state saving
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds ?? state.timeRemaining,
        completedSessions: completed,
        currentCycle: nextCycle,
      );
    } else if (state.currentMode == 'break') {
      notificationService.playSound('focus_timer_start.wav');
      update(
        // Use update to trigger state saving
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
  }

  void clearAllSessionsCompleteFlag() {
    update(allSessionsComplete: false); // Use update to save
    _prefs.setBool(
      AppConstants.prefAllSessionsComplete,
      false,
    ); // Clear from prefs too
  }

  void clearOverdueSessionsCompleteFlag() {
    if (state.overdueSessionsComplete) {
      update(overdueSessionsComplete: false); // Use update to save
      _prefs.setBool(
        AppConstants.prefOverdueSessionsComplete,
        false,
      ); // Clear from prefs too
    }
  }

  void clearCycleOverflowBlockedFlag() {
    if (state.cycleOverflowBlocked) {
      update(cycleOverflowBlocked: false); // Use update to save
    }
  }

  /// Schedule a Workmanager one-off task to persist timer state while app is backgrounded.
  Future<void> scheduleBackgroundPersistence() async {
    if (state.activeTaskId == null || !state.isRunning) return;
    // Save current API config for background isolate usage
    await _persistenceManager.saveApiConfig(_apiBaseUrl, _isDebugMode);
    await _persistenceManager.setSessionScheduled(true);
    await Workmanager().registerOneOffTask(
      AppConstants.pomodoroTimerTask,
      AppConstants.pomodoroTimerTask,
      initialDelay: Duration(seconds: state.timeRemaining + 5),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    debugLog(
      'TimerNotifier',
      'Background persistence scheduled via Workmanager.',
    );
  }

  /// Cancel any background persistence Workmanager tasks.
  Future<void> cancelBackgroundPersistence() async {
    await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
    await _persistenceManager.setSessionScheduled(false);
    debugLog('TimerNotifier', 'Background persistence cancelled.');
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);
