import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/features/pomodoro/providers/timer_provider.dart';

void main() {
  test('focused time accumulates while running in focus mode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(timerProvider.notifier);

    notifier.update(
      activeTaskId: 1,
      activeTaskName: 'Test Task',
      isTimerActive: true,
      isRunning: true,
      currentMode: 'focus',
      timeRemaining: 3, // small countdown
      focusDurationSeconds: 3,
      breakDurationSeconds: 2,
      plannedDurationSeconds: 3, // plan equals focus duration
    );
    notifier.startTicker();

    await Future.delayed(const Duration(seconds: 4));

    final focused = notifier.getFocusedTime(1);
    expect(
      focused >= 3,
      isTrue,
      reason: 'Should record at least planned focus seconds',
    );
  });

  test(
    'overdue crossing sets overdueCrossedTaskName and freezes timer',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(timerProvider.notifier);

      notifier.update(
        activeTaskId: 2,
        activeTaskName: 'taskB',
        isTimerActive: true,
        isRunning: true,
        currentMode: 'focus',
        timeRemaining: 1,
        focusDurationSeconds: 1,
        breakDurationSeconds: 1,
        plannedDurationSeconds: 1,
      );
      notifier.startTicker();

      await Future.delayed(const Duration(seconds: 2));

      final state = container.read(timerProvider);
      expect(state.overdueCrossedTaskName, 'taskB');
      expect(state.isRunning, isFalse, reason: 'Timer should freeze');
      expect(state.timeRemaining, 0);
    },
  );
}
