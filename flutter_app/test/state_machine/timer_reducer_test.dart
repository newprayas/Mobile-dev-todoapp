import 'package:flutter_test/flutter_test.dart';

import 'package:focus_timer_app/features/pomodoro/state_machine/timer_reducer.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/timer_events.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/timer_side_effects.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';

void main() {
  group('TimerReducer', () {
    final reducer = const TimerReducer();

    TimerReducerResult apply(TimerState state, TimerEvent event) =>
        reducer.reduce(state, event);

    test('StartSessionEvent initializes state correctly', () {
      final initial = const TimerState();
      final result = apply(
        initial,
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

      expect(result.state.isTimerActive, true);
      expect(result.state.isRunning, true);
      expect(result.state.timeRemaining, 1500);
      expect(result.state.currentMode, 'focus');
      expect(result.state.activeTaskId, 1);
      expect(result.effects.any((e) => e is ShowNotificationEffect), true);
      expect(result.effects.any((e) => e is PersistStateSideEffect), true);
    });

    test(
      'TickEvent decrements timeRemaining & increments focusedTime (focus mode)',
      () {
        final start = apply(
          const TimerState(),
          const StartSessionEvent(
            taskId: 10,
            taskName: 'Deep Work',
            focusDuration: 3,
            breakDuration: 0,
            plannedDuration: 3,
            totalCycles: 1,
            isPermanentlyOverdue: false,
          ),
        ).state;

        final afterFirst = apply(start, const TickEvent());
        expect(afterFirst.state.timeRemaining, 2);
        expect(afterFirst.state.focusedTimeCache[10], 1);
        expect(
          afterFirst.effects.isEmpty,
          true,
          reason: 'No side effects on normal tick',
        );
      },
    );

    test('Phase completion produces PhaseCompleteSideEffect', () {
      // Create state one second before completion of a 1-cycle session.
      final state = TimerState(
        activeTaskId: 5,
        activeTaskName: 'Session',
        isTimerActive: true,
        isRunning: true,
        currentMode: 'focus',
        timeRemaining: 1,
        focusDurationSeconds: 1,
        breakDurationSeconds: 0,
        totalCycles: 1,
        currentCycle: 1,
        plannedDurationSeconds: 1,
        focusedTimeCache: const {5: 0},
      );
      final result = apply(state, const TickEvent());
      expect(
        result.state.isTimerActive,
        false,
        reason: 'Session should finish',
      );
      expect(result.state.isRunning, false);
      expect(result.effects.any((e) => e is PhaseCompleteSideEffect), true);
      expect(result.effects.any((e) => e is PersistStateSideEffect), true);
    });

    test(
      'PauseEvent sets isRunning=false and emits PersistStateSideEffect',
      () {
        final started = apply(
          const TimerState(),
          const StartSessionEvent(
            taskId: 2,
            taskName: 'Task',
            focusDuration: 60,
            breakDuration: 0,
            plannedDuration: 60,
            totalCycles: 1,
            isPermanentlyOverdue: false,
          ),
        ).state;
        final paused = apply(started, const PauseEvent());
        expect(paused.state.isRunning, false);
        expect(paused.effects.any((e) => e is PersistStateSideEffect), true);
      },
    );

    test('ResumeEvent after PauseEvent sets isRunning=true and persists', () {
      final started = apply(
        const TimerState(),
        const StartSessionEvent(
          taskId: 3,
          taskName: 'Resume Test',
          focusDuration: 60,
          breakDuration: 0,
          plannedDuration: 60,
          totalCycles: 1,
          isPermanentlyOverdue: false,
        ),
      ).state;
      final paused = apply(started, const PauseEvent()).state;
      final resumed = apply(paused, const ResumeEvent());
      expect(resumed.state.isRunning, true);
      expect(resumed.effects.any((e) => e is PersistStateSideEffect), true);
    });

    test(
      'StopAndSaveEvent resets timer state & emits persistence + cancellation side effects',
      () {
        final started = apply(
          const TimerState(),
          const StartSessionEvent(
            taskId: 4,
            taskName: 'Stop Test',
            focusDuration: 120,
            breakDuration: 0,
            plannedDuration: 120,
            totalCycles: 1,
            isPermanentlyOverdue: false,
          ),
        ).state;
        final stopped = apply(started, const StopAndSaveEvent(4));
        expect(stopped.state.isTimerActive, false);
        expect(stopped.state.activeTaskId, null);
        expect(stopped.effects.any((e) => e is PersistStateSideEffect), true);
        expect(
          stopped.effects.any((e) => e is CancelAllNotificationsSideEffect),
          true,
        );
      },
    );
  });
}
