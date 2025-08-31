import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/features/pomodoro/providers/timer_provider.dart';

void main() {
  test('focused time accumulates while running in focus mode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(timerProvider.notifier);

    notifier.update(
      taskId: 1,
      active: true,
      running: true,
      mode: 'focus',
      remaining: 3, // small countdown
      focusDuration: 3,
      breakDuration: 2,
      plannedDuration: 3, // plan equals focus duration
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
        taskId: 2,
        active: true,
        running: true,
        mode: 'focus',
        remaining: 1,
        focusDuration: 1,
        breakDuration: 1,
        plannedDuration: 1,
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
