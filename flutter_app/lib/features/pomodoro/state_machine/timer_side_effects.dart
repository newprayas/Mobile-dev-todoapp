/// Describes side effects the controller must perform after a state transition.
abstract class TimerSideEffect {
  const TimerSideEffect();
}

class PersistStateEffect extends TimerSideEffect {
  const PersistStateEffect();
}

// Explicit persistence intent for key lifecycle events.
class PersistStateSideEffect extends TimerSideEffect {
  const PersistStateSideEffect();
}

class ShowNotificationEffect extends TimerSideEffect {
  const ShowNotificationEffect();
}

class CancelNotificationEffect extends TimerSideEffect {
  const CancelNotificationEffect();
}

class CancelAllNotificationsSideEffect extends TimerSideEffect {
  const CancelAllNotificationsSideEffect();
}

class ScheduleWorkmanagerEffect extends TimerSideEffect {
  final int taskId;
  final String taskName;
  final int remainingSeconds;
  const ScheduleWorkmanagerEffect(
    this.taskId,
    this.taskName,
    this.remainingSeconds,
  );
}

class CancelWorkmanagerEffect extends TimerSideEffect {
  const CancelWorkmanagerEffect();
}

class PlaySoundEffect extends TimerSideEffect {
  final String asset;
  final String? title;
  final String? body;
  const PlaySoundEffect(this.asset, {this.title, this.body});
}

class SaveFocusToRepoEffect extends TimerSideEffect {
  final int taskId;
  final int seconds;
  const SaveFocusToRepoEffect(this.taskId, this.seconds);
}

/// Emitted when a phase (focus or break) completes and a transition occurred.
class PhaseCompleteSideEffect extends TimerSideEffect {
  final String completedPhase; // 'focus' or 'break'
  final int cycleNumber; // cycle just completed (for focus phase)
  final bool sessionFinished; // true if all cycles done
  const PhaseCompleteSideEffect({
    required this.completedPhase,
    required this.cycleNumber,
    required this.sessionFinished,
  });
}

/// Emitted when planned focus duration threshold is crossed first time.
class OverdueReachedSideEffect extends TimerSideEffect {
  final int taskId;
  final String? taskName;
  const OverdueReachedSideEffect({required this.taskId, this.taskName});
}
