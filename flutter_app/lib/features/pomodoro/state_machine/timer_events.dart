import '../models/timer_state.dart';

/// Timer domain events (pure intent, no side effects).
abstract class TimerEvent {
  const TimerEvent();
}

class StartSessionEvent extends TimerEvent {
  final int taskId;
  final String taskName;
  final int focusDuration;
  final int breakDuration;
  final int plannedDuration;
  final int totalCycles;
  final bool isPermanentlyOverdue;
  const StartSessionEvent({
    required this.taskId,
    required this.taskName,
    required this.focusDuration,
    required this.breakDuration,
    required this.plannedDuration,
    required this.totalCycles,
    required this.isPermanentlyOverdue,
  });
}

class TickEvent extends TimerEvent {
  const TickEvent();
}

class PauseEvent extends TimerEvent {
  const PauseEvent();
}

class ResumeEvent extends TimerEvent {
  const ResumeEvent();
}

class SkipPhaseEvent extends TimerEvent {
  const SkipPhaseEvent();
}

class PhaseCompleteEvent extends TimerEvent {
  const PhaseCompleteEvent();
}

class StopAndSaveEvent extends TimerEvent {
  final int taskId;
  const StopAndSaveEvent(this.taskId);
}

// Notification action events (explicit user intent from system notification)
class NotificationPauseTappedEvent extends TimerEvent {
  const NotificationPauseTappedEvent();
}

class NotificationResumeTappedEvent extends TimerEvent {
  const NotificationResumeTappedEvent();
}

class NotificationStopTappedEvent extends TimerEvent {
  final int? taskId;
  const NotificationStopTappedEvent(this.taskId);
}

class OverdueReachedEvent extends TimerEvent {
  final int taskId;
  const OverdueReachedEvent(this.taskId);
}

class RestoreStateEvent extends TimerEvent {
  final TimerState restored;
  const RestoreStateEvent(this.restored);
}
