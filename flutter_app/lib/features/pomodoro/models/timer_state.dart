import 'package:flutter/foundation.dart';

/// Immutable state container for the Pomodoro timer feature.
///
/// This model purposefully contains only plain data. All behavior / side-effects
/// live inside notifiers or services. Keeping it lean and explicit improves
/// testability and reduces cognitive load when adding new fields.
@immutable
class TimerState {
  final int? activeTaskId;
  final String? activeTaskName;
  final int timeRemaining; // seconds remaining in current phase
  final bool isRunning; // whether ticker counting down
  final bool isTimerActive; // whether any task has been started (drives mini bar)
  final String currentMode; // 'focus' or 'break'
  final int? plannedDurationSeconds; // original planned focused total for task
  final int? focusDurationSeconds; // configured focus phase length
  final int? breakDurationSeconds; // configured break phase length
  final int currentCycle; // 1-based index of current focus cycle
  final int totalCycles; // planned number of focus cycles
  final int completedSessions; // number of completed focus sessions
  final bool isProgressBarFull; // planned time reached once
  final bool allSessionsComplete; // all planned focus sessions complete
  final bool overdueSessionsComplete; // overdue continuation session finished
  final int? overdueCrossedTaskId; // task id when planned time crossed
  final String? overdueCrossedTaskName; // task name when planned time crossed
  final Set<int> overduePromptShown; // tasks for which prompt already displayed
  final Set<int> overdueContinued; // tasks user chose to continue beyond plan
  final Map<int, int> focusedTimeCache; // live focused seconds per task (optimistic)
  final bool suppressNextActivation; // UI suppression flag
  final bool cycleOverflowBlocked; // guard for user attempting invalid cycle skip
  final bool isPermanentlyOverdue; // task previously marked overdue in DB

  // Background / lifecycle tracking
  final int? backgroundStartTime; // timestamp (ms) when app backgrounded
  final int pausedTimeTotal; // cumulative seconds paused in this session
  final bool wasInBackground; // whether state persisted due to backgrounding

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
    this.backgroundStartTime,
    this.pausedTimeTotal = 0,
    this.wasInBackground = false,
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
    Set<int>? overdueContinued,
    Map<int, int>? focusedTimeCache,
    bool? suppressNextActivation,
    bool? cycleOverflowBlocked,
    bool? isPermanentlyOverdue,
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
      plannedDurationSeconds: plannedDurationSeconds ?? this.plannedDurationSeconds,
      focusDurationSeconds: focusDurationSeconds ?? this.focusDurationSeconds,
      breakDurationSeconds: breakDurationSeconds ?? this.breakDurationSeconds,
      currentCycle: currentCycle ?? this.currentCycle,
      totalCycles: totalCycles ?? this.totalCycles,
      completedSessions: completedSessions ?? this.completedSessions,
      isProgressBarFull: isProgressBarFull ?? this.isProgressBarFull,
      allSessionsComplete: allSessionsComplete ?? this.allSessionsComplete,
      overdueSessionsComplete: overdueSessionsComplete ?? this.overdueSessionsComplete,
      overdueCrossedTaskId: overdueCrossedTaskId ?? this.overdueCrossedTaskId,
      overdueCrossedTaskName: overdueCrossedTaskName ?? this.overdueCrossedTaskName,
      overduePromptShown: overduePromptShown ?? this.overduePromptShown,
      overdueContinued: overdueContinued ?? this.overdueContinued,
      focusedTimeCache: focusedTimeCache ?? this.focusedTimeCache,
      suppressNextActivation: suppressNextActivation ?? this.suppressNextActivation,
      cycleOverflowBlocked: cycleOverflowBlocked ?? this.cycleOverflowBlocked,
      isPermanentlyOverdue: isPermanentlyOverdue ?? this.isPermanentlyOverdue,
      backgroundStartTime: backgroundStartTime ?? this.backgroundStartTime,
      pausedTimeTotal: pausedTimeTotal ?? this.pausedTimeTotal,
      wasInBackground: wasInBackground ?? this.wasInBackground,
    );
  }

  @override
  String toString() => 'TimerState(taskId: ' 
      '$activeTaskId, mode: $currentMode, running: $isRunning, cycle: $currentCycle/$totalCycles, timeRemaining: $timeRemaining)';
}
