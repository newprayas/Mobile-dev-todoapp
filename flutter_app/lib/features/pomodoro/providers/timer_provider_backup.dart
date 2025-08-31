import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/timer_session_controller.dart';
import '../../../core/providers/notification_provider.dart';
import '../../todo/providers/todos_provider.dart';
import '../../todo/models/todo.dart';

class TimerState {
  final int? activeTaskId;
  final String? activeTaskName; // Keep for backward compatibility
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
  final bool overdueSessionsComplete; // New flag for this workflow
  final int? overdueCrossedTaskId;
  final String? overdueCrossedTaskName; // Keep for backward compatibility
  final Set<int> overduePromptShown;
  final Set<String> overduePromptShownNames; // Keep for backward compatibility
  final Set<int> overdueContinued;
  final Set<String> overdueContinuedNames; // Keep for backward compatibility
  final Map<int, int> focusedTimeCache;
  final Map<String, int>
  focusedTimeCacheNames; // Keep for backward compatibility
  final bool suppressNextActivation;
  final bool cycleOverflowBlocked;
  final bool isPermanentlyOverdue;

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
    this.overduePromptShownNames = const {},
    this.overdueContinued = const {},
    this.overdueContinuedNames = const {},
    this.focusedTimeCache = const {},
    this.focusedTimeCacheNames = const {},
    this.suppressNextActivation = false,
    this.cycleOverflowBlocked = false,
    this.isPermanentlyOverdue = false,
  });

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
    Set<String>? overduePromptShownNames,
    Set<int>? overdueContinued,
    Set<String>? overdueContinuedNames,
    Map<int, int>? focusedTimeCache,
    Map<String, int>? focusedTimeCacheNames,
    bool? suppressNextActivation,
    bool? cycleOverflowBlocked,
    bool? isPermanentlyOverdue,
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
      overduePromptShownNames:
          overduePromptShownNames ?? this.overduePromptShownNames,
      overdueContinued: overdueContinued ?? this.overdueContinued,
      overdueContinuedNames:
          overdueContinuedNames ?? this.overdueContinuedNames,
      focusedTimeCache: focusedTimeCache ?? this.focusedTimeCache,
      focusedTimeCacheNames:
          focusedTimeCacheNames ?? this.focusedTimeCacheNames,
      suppressNextActivation:
          suppressNextActivation ?? this.suppressNextActivation,
      cycleOverflowBlocked: cycleOverflowBlocked ?? this.cycleOverflowBlocked,
      isPermanentlyOverdue: isPermanentlyOverdue ?? this.isPermanentlyOverdue,
    );
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

  @override
  TimerState build() {
    _sessionController ??= TimerSessionController();

    // CRITICAL FIX: This listener now correctly merges the live timer cache
    // with the persisted data from the todos list, preventing progress resets.
    ref.listen<AsyncValue<List<Todo>>>(todosProvider, (_, next) {
      next.whenData((todos) {
        final currentCache = state.focusedTimeCache;
        final newCacheFromDB = {
          for (var todo in todos) todo.id: todo.focusedTime,
        };
        final mergedCache = Map<int, int>.from(newCacheFromDB);

        // Preserve any live values from the current cache that are more recent
        // than what's in the database. This is essential for the active timer.
        currentCache.forEach((taskId, liveSeconds) {
          if (liveSeconds > (newCacheFromDB[taskId] ?? -1)) {
            mergedCache[taskId] = liveSeconds;
          }
        });

        if (!mapEquals(state.focusedTimeCache, mergedCache)) {
          Future.microtask(() {
            state = state.copyWith(focusedTimeCache: mergedCache);
          });
        }
      });
    });

    ref.onDispose(() {
      _ticker?.cancel();
      _autoSaveTimer?.cancel();
    });

    return const TimerState();
  }

  void update({
    int? taskId,
    int? remaining,
    bool? running,
    bool? active,
    int? plannedDuration,
    String? mode,
    int? focusDuration,
    int? breakDuration,
    int? setTotalCycles,
    int? setCurrentCycle,
  }) {
    var changed = false;
    var newState = state;

    if (taskId != null && taskId != state.activeTaskId) {
      newState = newState.copyWith(activeTaskId: taskId);
      changed = true;
    }
    // ... rest of the update method ...
    if (remaining != null && remaining != state.timeRemaining) {
      newState = newState.copyWith(timeRemaining: remaining);
      changed = true;
    }
    if (running != null && running != state.isRunning) {
      newState = newState.copyWith(isRunning: running);
      changed = true;
    }
    if (active != null && active != state.isTimerActive) {
      newState = newState.copyWith(isTimerActive: active);
      changed = true;
    }
    if (mode != null && mode != state.currentMode) {
      newState = newState.copyWith(currentMode: mode);
      changed = true;
    }
    if (plannedDuration != null &&
        plannedDuration != state.plannedDurationSeconds) {
      newState = newState.copyWith(plannedDurationSeconds: plannedDuration);
      changed = true;
    }
    if (focusDuration != null && focusDuration != state.focusDurationSeconds) {
      newState = newState.copyWith(focusDurationSeconds: focusDuration);
      changed = true;
    }
    if (breakDuration != null && breakDuration != state.breakDurationSeconds) {
      newState = newState.copyWith(breakDurationSeconds: breakDuration);
      changed = true;
    }
    if (setTotalCycles != null && setTotalCycles != state.totalCycles) {
      newState = newState.copyWith(totalCycles: setTotalCycles);
      changed = true;
    }
    if (setCurrentCycle != null && setCurrentCycle != state.currentCycle) {
      newState = newState.copyWith(currentCycle: setCurrentCycle);
      changed = true;
    }

    if (changed) {
      state = newState;
    }
  }

  void markOverduePromptShown(int taskId) {
    final newPromptShown = Set<int>.from(state.overduePromptShown)..add(taskId);
    state = state.copyWith(overduePromptShown: newPromptShown);
  }

  void markOverdueContinued(int taskId) {
    final newOverdueContinued = Set<int>.from(state.overdueContinued)
      ..add(taskId);
    state = state.copyWith(overdueContinued: newOverdueContinued);
  }

  void updateFocusedTime(int taskId, int seconds) {
    final newFocusedTimeCache = Map<int, int>.from(state.focusedTimeCache);
    newFocusedTimeCache[taskId] = seconds;
    state = state.copyWith(focusedTimeCache: newFocusedTimeCache);
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
        state = state.copyWith(focusedTimeCache: newCache);
      }

      if (state.timeRemaining > 0) {
        state = state.copyWith(timeRemaining: state.timeRemaining - 1);
      } else {
        // TIMER PHASE COMPLETED
        if (state.currentMode == 'focus') {
          final completed = state.completedSessions + 1;

          // Check if all planned cycles are now complete
          if (completed >= state.totalCycles) {
            if (state.isPermanentlyOverdue) {
              // Overdue task workflow trigger
              debugPrint(
                "TIMER_NOTIFIER: Overdue task session complete. Firing event.",
              );
              ref
                  .read(notificationServiceProvider)
                  .playSound('progress_bar_full.wav');
              state = state.copyWith(
                overdueSessionsComplete: true,
                isRunning: false,
                completedSessions: completed,
              );
              stopTicker();
              return; // Stop processing this tick
            } else if (!state.isProgressBarFull) {
              // Normal task completion
              state = state.copyWith(allSessionsComplete: true);
            }
          }

          // Transition to break (for both normal and overdue tasks if not yet complete)
          final notificationService = ref.read(notificationServiceProvider);
          notificationService.playSound('break_timer_start.wav');
          notificationService.showNotification(
            title: 'Focus Session Complete!',
            body: 'Time for a break. Great work!',
          );
          final nextCycle = (state.currentCycle + 1) <= state.totalCycles
              ? state.currentCycle + 1
              : state.totalCycles;
          state = state.copyWith(
            currentMode: 'break',
            timeRemaining: state.breakDurationSeconds,
            currentCycle: nextCycle,
            completedSessions: completed,
          );
        } else if (state.currentMode == 'break' &&
            state.focusDurationSeconds != null) {
          final notificationService = ref.read(notificationServiceProvider);
          notificationService.playSound('focus_timer_start.wav');
          notificationService.showNotification(
            title: 'Break Complete!',
            body: 'Time to focus. Let\'s get back to work!',
          );
          state = state.copyWith(
            currentMode: 'focus',
            timeRemaining: state.focusDurationSeconds,
          );
        } else {
          stop();
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
      if (kDebugMode) debugPrint('SOUND/NOTIFICATION ERROR: $e');
    }

    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
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
  }

  void stop() {
    update(running: false);
    stopTicker();
  }

  void clear() {
    stopTicker();
    _sessionController?.forceReset();
    state = const TimerState();
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

    state = state.copyWith(
      timeRemaining: currentPhaseDuration,
      isRunning: false,
    );
    stopTicker();
  }

  void clearPreserveProgress() {
    stopTicker();
    _sessionController?.handleEvent(TimerSessionEvent.abort);
    final preservedCache = state.focusedTimeCache;
    state = TimerState(focusedTimeCache: preservedCache);
  }

  Future<bool> stopAndSaveProgress(int todoId) async {
    if (state.activeTaskId == null) {
      clear();
      return true;
    }

    try {
      final currentFocusedTime = state.focusedTimeCache[todoId] ?? 0;
      final api = ref.read(apiServiceProvider);
      await api.updateFocusTime(todoId, currentFocusedTime);
      clearPreserveProgress();
      return true;
    } catch (e) {
      clearPreserveProgress();
      return false;
    }
  }

  void toggleRunning() {
    final nextRunning = !state.isRunning;
    state = state.copyWith(isRunning: nextRunning);
    if (nextRunning) {
      startTicker();
    } else {
      stopTicker();
    }
  }

  bool startTask({
    required int taskId,
    required String taskName, // Keep name for FSM and notifications
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
      if (kDebugMode) debugPrint('SOUND/NOTIFICATION ERROR: $e');
    }

    state = state.copyWith(
      activeTaskId: taskId,
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
    );
    startTicker();
    return true;
  }

  void pauseTask() {
    state = state.copyWith(isRunning: false);
    stopTicker();
    _triggerDeferredAutoSave();
  }

  void resumeTask() {
    if (!state.isRunning) {
      state = state.copyWith(isRunning: true);
      startTicker();
      _startAutoSaveTimer();
    }
  }

  void updateDurations({
    int? focusDuration,
    int? breakDuration,
    int? totalCycles,
  }) {
    state = state.copyWith(
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
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
    required int plannedDuration,
    required bool isPermanentlyOverdue,
  }) {
    stopTicker();
    final cache = state.focusedTimeCache;
    state = state.copyWith(
      activeTaskId: taskId,
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
      overdueSessionsComplete: false, // Reset this flag on setup
      focusedTimeCache: cache,
      overdueCrossedTaskId: null,
      isTimerActive: false,
      isPermanentlyOverdue: isPermanentlyOverdue,
    );
    _lastAutoSavedSeconds = state.focusedTimeCache[taskId] ?? 0;
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
      final api = ref.read(apiServiceProvider);
      await api.updateFocusTime(todoId, currentFocused);
      _lastAutoSavedSeconds = currentFocused;
    } catch (e) {
      // Handle error
    } finally {
      _isAutoSaving = false;
    }
  }

  void skipPhase() {
    final notificationService = ref.read(notificationServiceProvider);
    if (state.currentMode == 'focus') {
      if (state.currentCycle >= state.totalCycles) {
        state = state.copyWith(cycleOverflowBlocked: true);
        return;
      }
      notificationService.playSound('break_timer_start.wav');
      final completed = state.completedSessions + 1;
      final nextCycle = state.currentCycle + 1;
      state = state.copyWith(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds ?? state.timeRemaining,
        completedSessions: completed,
        currentCycle: nextCycle,
      );
    } else if (state.currentMode == 'break') {
      notificationService.playSound('focus_timer_start.wav');
      state = state.copyWith(
        currentMode: 'focus',
        timeRemaining: state.focusDurationSeconds ?? state.timeRemaining,
      );
    }
  }

  void clearAllSessionsCompleteFlag() {
    state = state.copyWith(allSessionsComplete: false);
  }

  void clearOverdueSessionsCompleteFlag() {
    if (state.overdueSessionsComplete) {
      state = state.copyWith(overdueSessionsComplete: false);
    }
  }

  void clearCycleOverflowBlockedFlag() {
    if (state.cycleOverflowBlocked) {
      state = state.copyWith(cycleOverflowBlocked: false);
    }
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);
