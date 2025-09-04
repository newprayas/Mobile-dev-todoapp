import '../models/timer_state.dart';
import 'timer_events.dart';
import 'timer_side_effects.dart';

class TimerReducerResult {
  final TimerState state;
  final List<TimerSideEffect> effects;
  const TimerReducerResult(this.state, this.effects);
}

class TimerReducer {
  const TimerReducer();

  TimerReducerResult reduce(TimerState current, TimerEvent event) {
    if (event is StartSessionEvent) {
      final newState = current.copyWith(
        activeTaskId: event.taskId,
        activeTaskName: event.taskName,
        focusDurationSeconds: event.focusDuration,
        breakDurationSeconds: event.breakDuration,
        plannedDurationSeconds: event.plannedDuration,
        totalCycles: event.totalCycles,
        currentCycle: 1,
        timeRemaining: event.focusDuration,
        currentMode: 'focus',
        isTimerActive: true,
        isRunning: true,
        isPermanentlyOverdue: event.isPermanentlyOverdue,
        wasInBackground: false,
        backgroundStartTime: null,
        pausedTimeTotal: 0,
      );
      return TimerReducerResult(newState, [
        const ShowNotificationEffect(),
        const PersistStateSideEffect(),
        ScheduleWorkmanagerEffect(
          event.taskId,
          event.taskName,
          event.focusDuration,
        ),
        // Transient start notification with sound (moved from provider).
        PlaySoundEffect(
          'focus_timer_start.wav',
          title: 'Focus Session Started!',
          body: 'Focus time for "${event.taskName}". You\'ve got this!',
        ),
      ]);
    }
    if (event is TickEvent) {
      if (!current.isRunning || !current.isTimerActive) {
        return TimerReducerResult(current, const []);
      }
      int nextRemaining = current.timeRemaining > 0
          ? current.timeRemaining - 1
          : 0;

      // Accumulate focused time during focus phase.
      Map<int, int> focused = current.focusedTimeCache;
      if (current.currentMode == 'focus' && current.activeTaskId != null) {
        final int id = current.activeTaskId!;
        final int cur = focused[id] ?? 0;
        focused = Map<int, int>.from(focused)..[id] = cur + 1;
      }

      // Overdue detection before phase completion (focus phase only).
      final bool inFocus =
          current.currentMode == 'focus' && current.activeTaskId != null;
      if (nextRemaining > 0 &&
          inFocus &&
          current.plannedDurationSeconds != null &&
          !current.isPermanentlyOverdue) {
        final int taskId = current.activeTaskId!;
        final int focusedNow = focused[taskId] ?? 0;
        if (focusedNow >= current.plannedDurationSeconds! &&
            current.overdueCrossedTaskId != taskId) {
          final overdueState = current.copyWith(
            focusedTimeCache: focused,
            overdueCrossedTaskId: taskId,
            overdueCrossedTaskName: current.activeTaskName,
          );
          return TimerReducerResult(
            overdueState.copyWith(timeRemaining: nextRemaining),
            const [
              OverdueReachedSideEffect(taskId: -1),
              ShowNotificationEffect(),
            ],
          );
        }
      }

      // If phase not complete yet just update remaining/focus cache.
      if (nextRemaining > 0) {
        return TimerReducerResult(
          current.copyWith(
            timeRemaining: nextRemaining,
            focusedTimeCache: focused,
          ),
          // Update persistent notification every tick so displayed time stays fresh.
          const [ShowNotificationEffect()],
        );
      }

      // Phase complete: determine next phase or session end.
      final bool wasFocus = current.currentMode == 'focus';
      int nextCycle = current.currentCycle;
      String nextMode = current.currentMode;
      int nextDuration = 0;
      bool sessionFinished = false;

      if (wasFocus) {
        // Completed a focus phase.
        if (current.breakDurationSeconds != null &&
            current.breakDurationSeconds! > 0) {
          nextMode = 'break';
          nextDuration = current.breakDurationSeconds!;
        } else {
          // No break configured, go straight to next cycle focus.
          nextCycle += 1;
          if (nextCycle > current.totalCycles) {
            sessionFinished = true;
          } else {
            nextMode = 'focus';
            nextDuration = current.focusDurationSeconds ?? 0;
          }
        }
      } else {
        // Completed a break phase -> advance cycle and start focus or finish.
        nextCycle += 1;
        if (nextCycle > current.totalCycles) {
          sessionFinished = true;
        } else {
          nextMode = 'focus';
          nextDuration = current.focusDurationSeconds ?? 0;
        }
      }

      TimerState nextState;
      final effects = <TimerSideEffect>[
        ShowNotificationEffect(),
        PersistStateSideEffect(),
      ];
      if (sessionFinished) {
        nextState = current.copyWith(
          timeRemaining: 0,
          isRunning: false,
          isTimerActive: false,
          currentMode: wasFocus ? 'focus' : 'break',
        );
        effects.add(const CancelWorkmanagerEffect());
      } else {
        nextState = current.copyWith(
          currentCycle: nextCycle,
          currentMode: nextMode,
          timeRemaining: nextDuration,
        );
        effects.add(
          ScheduleWorkmanagerEffect(
            current.activeTaskId ?? -1,
            current.activeTaskName ?? 'Task',
            nextDuration,
          ),
        );
      }

      effects.add(
        PhaseCompleteSideEffect(
          completedPhase: wasFocus ? 'focus' : 'break',
          cycleNumber: current.currentCycle,
          sessionFinished: sessionFinished,
        ),
      );
      return TimerReducerResult(
        nextState.copyWith(focusedTimeCache: focused),
        effects,
      );
    }
    if (event is PauseEvent) {
      if (!current.isRunning) return TimerReducerResult(current, const []);
      final next = current.copyWith(isRunning: false);
      return TimerReducerResult(next, const [
        ShowNotificationEffect(),
        CancelWorkmanagerEffect(),
        PersistStateSideEffect(),
      ]);
    }
    if (event is ResumeEvent) {
      if (current.isRunning || !current.isTimerActive)
        return TimerReducerResult(current, const []);
      final next = current.copyWith(isRunning: true);
      return TimerReducerResult(next, [
        const ShowNotificationEffect(),
        const PersistStateSideEffect(),
        if (current.activeTaskId != null && current.activeTaskName != null)
          ScheduleWorkmanagerEffect(
            current.activeTaskId!,
            current.activeTaskName!,
            current.timeRemaining,
          ),
      ]);
    }
    if (event is SkipPhaseEvent) {
      // Force immediate phase completion transition using zero-remaining path.
      // Re-enter reducer via synthetic Tick with remaining=0 by copying state.
      final synthetic = current.copyWith(timeRemaining: 0);
      return reduce(synthetic, const TickEvent());
    }
    if (event is StopAndSaveEvent) {
      final next = const TimerState();
      return TimerReducerResult(next, const [
        CancelWorkmanagerEffect(),
        CancelAllNotificationsSideEffect(),
        PersistStateSideEffect(),
      ]);
    }
    if (event is RestoreStateEvent) {
      return TimerReducerResult(event.restored, const [
        ShowNotificationEffect(),
      ]);
    }
    if (event is NotificationPauseTappedEvent) {
      return reduce(current, const PauseEvent());
    }
    if (event is NotificationResumeTappedEvent) {
      return reduce(current, const ResumeEvent());
    }
    if (event is NotificationStopTappedEvent) {
      return reduce(
        current,
        StopAndSaveEvent(event.taskId ?? current.activeTaskId ?? -1),
      );
    }
    return TimerReducerResult(current, const []);
  }
}

/// Placeholder to be expanded when phase transition logic is migrated.
class PhaseCompleteEffectPlaceholder extends TimerSideEffect {
  const PhaseCompleteEffectPlaceholder();
}
