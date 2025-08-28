import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timer_session_controller.dart';

class TimerState {
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
  // Session tracking
  final int completedSessions;
  final bool isProgressBarFull;
  final bool allSessionsComplete;
  final String? overdueCrossedTaskName;
  final Set<String> overduePromptShown;
  final Set<String> overdueContinued;
  final Map<String, int> focusedTimeCache;
  final bool suppressNextActivation;

  const TimerState({
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
    this.overdueCrossedTaskName,
    this.overduePromptShown = const {},
    this.overdueContinued = const {},
    this.focusedTimeCache = const {},
    this.suppressNextActivation = false,
  });

  TimerState copyWith({
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
    String? overdueCrossedTaskName,
    Set<String>? overduePromptShown,
    Set<String>? overdueContinued,
    Map<String, int>? focusedTimeCache,
    bool? suppressNextActivation,
  }) {
    return TimerState(
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
      overdueCrossedTaskName:
          overdueCrossedTaskName ?? this.overdueCrossedTaskName,
      overduePromptShown: overduePromptShown ?? this.overduePromptShown,
      overdueContinued: overdueContinued ?? this.overdueContinued,
      focusedTimeCache: focusedTimeCache ?? this.focusedTimeCache,
      suppressNextActivation:
          suppressNextActivation ?? this.suppressNextActivation,
    );
  }
}

class TimerNotifier extends Notifier<TimerState> {
  Timer? _ticker;
  bool _processingOverdue = false;
  TimerSessionController? _sessionController;
  DateTime? _lastStartAttempt;

  @override
  TimerState build() {
    // Only create session controller once
    _sessionController ??= TimerSessionController();
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const TimerState();
  }

  void update({
    String? taskName,
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
    if (kDebugMode) {
      debugPrint(
        'TIMER PROVIDER: update() called with -> taskName:$taskName remaining:$remaining running:$running active:$active mode:$mode planned:$plannedDuration',
      );
      debugPrint(
        'TIMER PROVIDER: before -> activeTaskName:${state.activeTaskName} timeRemaining:${state.timeRemaining} isRunning:${state.isRunning} isTimerActive:${state.isTimerActive} currentMode:${state.currentMode}',
      );
    }
    var changed = false;
    var newState = state;

    if (taskName != null && taskName != state.activeTaskName) {
      newState = newState.copyWith(activeTaskName: taskName);
      changed = true;
    }
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
      if (kDebugMode) {
        debugPrint(
          'TIMER PROVIDER: after -> activeTaskName:${state.activeTaskName} timeRemaining:${state.timeRemaining} isRunning:${state.isRunning} isTimerActive:${state.isTimerActive} currentMode:${state.currentMode}',
        );
      }
    }
  }

  void markOverduePromptShown(String taskName) {
    final newPromptShown = Set<String>.from(state.overduePromptShown)
      ..add(taskName);
    state = state.copyWith(overduePromptShown: newPromptShown);
  }

  void markOverdueContinued(String taskName) {
    final newOverdueContinued = Set<String>.from(state.overdueContinued)
      ..add(taskName);
    state = state.copyWith(overdueContinued: newOverdueContinued);
  }

  void updateFocusedTime(String taskName, int seconds) {
    final newFocusedTimeCache = Map<String, int>.from(state.focusedTimeCache);
    newFocusedTimeCache[taskName] = seconds;
    state = state.copyWith(focusedTimeCache: newFocusedTimeCache);
  }

  int getFocusedTime(String taskName) {
    return state.focusedTimeCache[taskName] ?? 0;
  }

  void setOverdueCrossed(String? taskName) {
    state = state.copyWith(overdueCrossedTaskName: taskName);
  }

  void setSuppressNextActivation(bool suppress) {
    state = state.copyWith(suppressNextActivation: suppress);
  }

  void startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;
      if (state.timeRemaining > 0) {
        // Decrement and increment focused time cache if in focus mode.
        var newFocusedTimeCache = state.focusedTimeCache;
        if (state.currentMode == 'focus' && state.activeTaskName != null) {
          final task = state.activeTaskName!;
          final current = newFocusedTimeCache[task] ?? 0;
          newFocusedTimeCache = Map<String, int>.from(newFocusedTimeCache)
            ..[task] = current + 1;
        }
        state = state.copyWith(
          timeRemaining: state.timeRemaining - 1,
          focusedTimeCache: newFocusedTimeCache,
        );
      } else {
        // Handle transitions similar to legacy service (simplified for bridge).
        if (state.currentMode == 'focus' &&
            state.breakDurationSeconds != null) {
          // Mark completion of a focus session
          final completed = state.completedSessions + 1;
          state = state.copyWith(completedSessions: completed);
          // If all sessions complete trigger freeze (UI can observe)
          if (completed >= state.totalCycles && !state.isProgressBarFull) {
            state = state.copyWith(allSessionsComplete: true);
          }
          state = state.copyWith(
            currentMode: 'break',
            timeRemaining: state.breakDurationSeconds,
            currentCycle: state.currentCycle + 1,
          );
        } else if (state.currentMode == 'break' &&
            state.focusDurationSeconds != null) {
          state = state.copyWith(
            currentMode: 'focus',
            timeRemaining: state.focusDurationSeconds,
          );
        } else {
          // No transition data -> stop
          stop();
        }
      }

      // Overdue detection when focus time meets or exceeds planned.
      if (!_processingOverdue &&
          state.currentMode == 'focus' &&
          state.activeTaskName != null &&
          state.plannedDurationSeconds != null) {
        final focused = state.focusedTimeCache[state.activeTaskName!] ?? 0;
        if (focused >= state.plannedDurationSeconds! &&
            state.overdueCrossedTaskName != state.activeTaskName) {
          _processingOverdue = true;
          _markOverdueAndFreeze(state.activeTaskName!);
          _processingOverdue = false;
        }
      }
    });
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _markOverdueAndFreeze(String task) {
    // Use FSM to handle overdue transition
    final success =
        _sessionController?.handleEvent(TimerSessionEvent.overdueReached) ??
        false;
    if (success && kDebugMode) {
      debugPrint('TIMER_FSM: Task $task reached overdue state');
    }

    // Freeze timer but keep mini-bar visible for one frame so UI can prompt.
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
      isRunning: false,
      timeRemaining: 0,
      overdueCrossedTaskName: task,
      // Preserve activeTaskName & isTimerActive
      // Clear adjustable durations
      plannedDurationSeconds: null,
      focusDurationSeconds: null,
      breakDurationSeconds: null,
      currentCycle: 1,
      totalCycles: 1,
    );
  }

  /// Trigger overdue dialog from UI
  Future<String?> triggerOverdueDialog() async {
    final taskName = state.overdueCrossedTaskName;
    if (taskName == null) return null;

    final focusedTime = getFocusedTime(taskName);
    final plannedTime = state.plannedDurationSeconds ?? 0;

    if (kDebugMode) {
      debugPrint('TIMER_FSM: Triggering overdue dialog for $taskName');
      debugPrint(
        'TIMER_FSM: Focused: ${focusedTime}s, Planned: ${plannedTime}s',
      );
    }

    return taskName; // Return task name to trigger dialog in UI
  }

  /// Handle overdue dialog response
  void handleOverdueResponse(String response, String taskName) {
    if (kDebugMode) {
      debugPrint(
        'TIMER_FSM: Handling overdue response: $response for $taskName',
      );
    }

    if (response == 'continue') {
      markOverdueContinued(taskName);
      // Resume timer in overdue mode
      state = state.copyWith(
        isRunning: true,
        overdueCrossedTaskName: null, // Clear the trigger
      );
      startTicker();
    } else if (response == 'stop') {
      // Stop and clear everything
      clear();
    }
  }

  void logStateSnapshot(String prefix) {
    if (kDebugMode) {
      debugPrint('$prefix: TimerState(');
      debugPrint('  activeTaskName: ${state.activeTaskName}');
      debugPrint('  timeRemaining: ${state.timeRemaining}');
      debugPrint('  isRunning: ${state.isRunning}');
      debugPrint('  isTimerActive: ${state.isTimerActive}');
      debugPrint('  currentMode: ${state.currentMode}');
      debugPrint('  plannedDurationSeconds: ${state.plannedDurationSeconds}');
      debugPrint('  currentCycle: ${state.currentCycle}');
      debugPrint('  totalCycles: ${state.totalCycles}');
      debugPrint(')');
    }
  }

  void deactivate() {
    update(active: false);
  }

  void stop() {
    update(running: false);
    stopTicker();
  }

  void reset() {
    stopTicker();
    // Force reset the session controller instead of just sending abort event
    _sessionController?.forceReset();
    state = const TimerState();
  }

  // UX Flow: Reset current phase only and subtract elapsed time from focused time cache
  void resetCurrentPhase() {
    if (state.activeTaskName == null) return;

    if (kDebugMode) {
      debugPrint('RESET: Resetting current phase for ${state.activeTaskName}');
    }

    // Calculate elapsed time in current phase
    final currentPhaseDuration = state.currentMode == 'focus'
        ? (state.focusDurationSeconds ?? 25 * 60)
        : (state.breakDurationSeconds ?? 5 * 60);
    final elapsedTime = currentPhaseDuration - state.timeRemaining;

    // Only subtract time if we're in focus mode and time has elapsed
    if (state.currentMode == 'focus' && elapsedTime > 0) {
      final taskName = state.activeTaskName!;
      final currentFocusedTime = getFocusedTime(taskName);
      final newFocusedTime = (currentFocusedTime - elapsedTime)
          .clamp(0, double.infinity)
          .toInt();

      if (kDebugMode) {
        debugPrint('RESET: Subtracting $elapsedTime seconds from focused time');
        debugPrint(
          'RESET: Previous focused time: $currentFocusedTime, New: $newFocusedTime',
        );
      }

      updateFocusedTime(taskName, newFocusedTime);
    }

    // Reset the current phase timer to full duration
    state = state.copyWith(
      timeRemaining: currentPhaseDuration,
      isRunning: false,
    );

    stopTicker();
  }

  void clear() {
    stopTicker();
    // Force reset the session controller instead of just sending abort event
    _sessionController?.forceReset();
    state = const TimerState();
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
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int plannedDuration,
    required int totalCycles,
  }) {
    // Debounce rapid start attempts (prevent multiple calls within 500ms)
    final now = DateTime.now();
    if (_lastStartAttempt != null &&
        now.difference(_lastStartAttempt!).inMilliseconds < 500) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Debouncing rapid start attempt for $taskName');
      }
      return false;
    }
    _lastStartAttempt = now;

    // Force reset if session controller is stuck
    if (_sessionController?.currentState != TimerSessionState.idle) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Force resetting stuck session controller');
      }
      _sessionController?.forceReset();
    }

    // Start FSM session
    final success =
        _sessionController?.startSession(
          taskName: taskName,
          focusDurationSeconds: focusDuration,
          breakDurationSeconds: breakDuration,
          totalCycles: totalCycles,
        ) ??
        false;

    if (!success) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Failed to start session for $taskName');
      }
      return false;
    }

    state = state.copyWith(
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
    );
    startTicker();
    return true;
  }

  void pauseTask() {
    state = state.copyWith(isRunning: false);
    stopTicker();
  }

  void resumeTask() {
    if (!state.isRunning) {
      state = state.copyWith(isRunning: true);
      startTicker();
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
      // Keep timeRemaining aligned with focus duration if currently in setup (not running)
      timeRemaining:
          (!state.isRunning &&
              state.currentMode == 'focus' &&
              focusDuration != null)
          ? focusDuration
          : state.timeRemaining,
    );
  }

  void markProgressBarFull() {
    state = state.copyWith(isProgressBarFull: true);
  }

  void resetForSetup({
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
  }) {
    stopTicker();
    state = state.copyWith(
      isRunning: false,
      currentMode: 'focus',
      timeRemaining: focusDuration,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      totalCycles: totalCycles,
      currentCycle: 0,
      completedSessions: 0,
      isProgressBarFull: false,
      allSessionsComplete: false,
    );
  }

  void resetForSetupWithTask({
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
    required int plannedDuration,
  }) {
    stopTicker();
    state = state.copyWith(
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
    );
  }

  void skipPhase() {
    if (state.currentMode == 'focus') {
      final completed = state.completedSessions + 1;
      state = state.copyWith(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds ?? state.timeRemaining,
        completedSessions: completed,
        currentCycle: state.currentCycle + 1,
      );
    } else if (state.currentMode == 'break') {
      state = state.copyWith(
        currentMode: 'focus',
        timeRemaining: state.focusDurationSeconds ?? state.timeRemaining,
      );
    }
  }

  bool hasOverduePromptBeenShown(String task) =>
      state.overduePromptShown.contains(task);
  bool hasUserContinuedOverdue(String task) =>
      state.overdueContinued.contains(task);
  void markUserContinuedOverdue(String task) => markOverdueContinued(task);
}

// The main timer provider
final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);

// Legacy bridge removed; TimerNotifier is now sole source of truth.
