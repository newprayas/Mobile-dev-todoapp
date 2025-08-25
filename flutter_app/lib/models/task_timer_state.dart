class TaskTimerState {
  final String? taskId;
  final String timerState; // 'paused'|'running'
  final String currentMode; // 'focus'|'break'
  final int? timeRemaining;
  final int? totalCycles;
  final int currentCycle;
  final int lastFocusedTime;
  final int? focusDuration;
  final int? breakDuration;
  // New session tracking fields
  final int completedSessions;
  final bool isProgressBarFull;
  final bool allSessionsComplete;

  TaskTimerState({
    this.taskId,
    this.timerState = 'paused',
    this.currentMode = 'focus',
    this.timeRemaining,
    this.totalCycles,
    this.currentCycle = 0,
    this.lastFocusedTime = 0,
    this.focusDuration,
    this.breakDuration,
    this.completedSessions = 0,
    this.isProgressBarFull = false,
    this.allSessionsComplete = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'timerState': timerState,
      'currentMode': currentMode,
      'timeRemaining': timeRemaining,
      'totalCycles': totalCycles,
      'currentCycle': currentCycle,
      'lastFocusedTime': lastFocusedTime,
      'focusDuration': focusDuration,
      'breakDuration': breakDuration,
      'completedSessions': completedSessions,
      'isProgressBarFull': isProgressBarFull,
      'allSessionsComplete': allSessionsComplete,
    };
  }

  factory TaskTimerState.fromJson(Map<String, dynamic> j) {
    return TaskTimerState(
      taskId: j['taskId'],
      timerState: j['timerState'] ?? 'paused',
      currentMode: j['currentMode'] ?? 'focus',
      timeRemaining: j['timeRemaining'],
      totalCycles: j['totalCycles'],
      currentCycle: j['currentCycle'] ?? 0,
      lastFocusedTime: j['lastFocusedTime'] ?? 0,
      focusDuration: j['focusDuration'],
      breakDuration: j['breakDuration'],
      completedSessions: j['completedSessions'] ?? 0,
      isProgressBarFull: j['isProgressBarFull'] ?? false,
      allSessionsComplete: j['allSessionsComplete'] ?? false,
    );
  }
}
