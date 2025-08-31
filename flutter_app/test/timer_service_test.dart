import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/features/pomodoro/providers/timer_provider.dart';

// Migrated tests: basic sanity checks for Riverpod timerProvider replacing legacy TimerService.
void main() {
  test('timerProvider initial state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(timerProvider);
    expect(state.activeTaskId, isNull);
    expect(state.timeRemaining, 0);
    expect(state.isRunning, isFalse);
    expect(state.currentMode, 'focus');
  });

  test('update and focused time cache via notifier', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(timerProvider.notifier);
    notifier.update(
      taskId: 1,
      remaining: 120,
      running: true,
      active: true,
      mode: 'focus',
    );
    notifier.updateFocusedTime(1, 30);
    final state = container.read(timerProvider);
    expect(state.activeTaskId, 1);
    expect(state.timeRemaining, 120);
    expect(state.isRunning, isTrue);
    expect(notifier.getFocusedTime(1), 30);
  });
}
