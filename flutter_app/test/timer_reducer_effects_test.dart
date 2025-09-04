import 'package:flutter_test/flutter_test.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/timer_reducer.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/timer_events.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/timer_side_effects.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';

void main() {
  group('TimerReducer side effects', () {
    test(
      'StartSessionEvent emits scheduling, persistence, notification, sound',
      () {
        final reducer = const TimerReducer();
        final result = reducer.reduce(
          const TimerState(),
          const StartSessionEvent(
            taskId: 1,
            taskName: 'Task',
            focusDuration: 1500,
            breakDuration: 300,
            plannedDuration: 1500,
            totalCycles: 1,
            isPermanentlyOverdue: false,
          ),
        );
        expect(result.effects.whereType<ShowNotificationEffect>().length, 1);
        expect(result.effects.whereType<PersistStateSideEffect>().length, 1);
        expect(result.effects.whereType<ScheduleWorkmanagerEffect>().length, 1);
        expect(result.effects.whereType<PlaySoundEffect>().length, 1);
      },
    );

    test(
      'PauseEvent emits cancel workmanager + persistence + notification',
      () {
        final reducer = const TimerReducer();
        final runningState = const TimerState(
          isRunning: true,
          isTimerActive: true,
        );
        final result = reducer.reduce(runningState, const PauseEvent());
        expect(result.effects.whereType<CancelWorkmanagerEffect>().length, 1);
        expect(result.effects.whereType<PersistStateSideEffect>().length, 1);
        expect(result.effects.whereType<ShowNotificationEffect>().length, 1);
      },
    );

    test('ResumeEvent emits schedule workmanager when active task present', () {
      final reducer = const TimerReducer();
      final paused = const TimerState(
        isRunning: false,
        isTimerActive: true,
        activeTaskId: 7,
        activeTaskName: 'Task',
        timeRemaining: 42,
      );
      final result = reducer.reduce(paused, const ResumeEvent());
      expect(result.effects.whereType<ScheduleWorkmanagerEffect>().length, 1);
    });

    test(
      'TickEvent phase completion emits CancelWorkmanagerEffect at session end',
      () {
        final reducer = const TimerReducer();
        // Build state that will complete focus phase and finish session (single cycle)
        final state = const TimerState(
          isRunning: true,
          isTimerActive: true,
          activeTaskId: 1,
          activeTaskName: 'Task',
          currentMode: 'focus',
          currentCycle: 1,
          totalCycles: 1,
          timeRemaining: 1, // next tick completes
        );
        final result = reducer.reduce(state, const TickEvent());
        // Expect cancel workmanager because session finished
        expect(result.effects.whereType<CancelWorkmanagerEffect>().length, 1);
        expect(result.effects.whereType<PhaseCompleteSideEffect>().length, 1);
      },
    );

    test('StopAndSaveEvent resets state & cancels workmanager', () {
      final reducer = const TimerReducer();
      final active = const TimerState(
        isRunning: true,
        isTimerActive: true,
        activeTaskId: 5,
        activeTaskName: 'Task',
        timeRemaining: 100,
      );
      final result = reducer.reduce(active, const StopAndSaveEvent(5));
      expect(result.state.isTimerActive, false);
      expect(result.effects.whereType<CancelWorkmanagerEffect>().length, 1);
      expect(result.effects.whereType<PersistStateSideEffect>().length, 1);
    });

    test('SkipPhaseEvent routes through TickEvent zero path', () {
      final reducer = const TimerReducer();
      final midFocus = const TimerState(
        isRunning: true,
        isTimerActive: true,
        activeTaskId: 1,
        activeTaskName: 'Task',
        currentMode: 'focus',
        focusDurationSeconds: 1500,
        breakDurationSeconds: 300,
        currentCycle: 1,
        totalCycles: 2,
        timeRemaining: 10,
      );
      final result = reducer.reduce(midFocus, const SkipPhaseEvent());
      // Either schedules next phase or cancels if session finished.
      final scheduled = result.effects
          .whereType<ScheduleWorkmanagerEffect>()
          .isNotEmpty;
      final phaseComplete = result.effects
          .whereType<PhaseCompleteSideEffect>()
          .isNotEmpty;
      expect(phaseComplete, true);
      expect(
        scheduled ||
            result.effects.whereType<CancelWorkmanagerEffect>().isNotEmpty,
        true,
      );
    });
  });
}
