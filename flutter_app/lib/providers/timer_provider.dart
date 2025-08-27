import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  TimerState build() {
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
    state = const TimerState();
  }

  void clear() {
    stopTicker();
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

  void startTask({
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int plannedDuration,
    required int totalCycles,
  }) {
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
