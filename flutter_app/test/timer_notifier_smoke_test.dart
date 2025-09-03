import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/features/pomodoro/providers/timer_provider.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TimerNotifier startTask sets initial running state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(timerProvider.notifier);
    final started = notifier.startTask(
      taskId: 1,
      taskName: 'Demo',
      focusDuration: 5, // short for test
      breakDuration: 3,
      plannedDuration: 5,
      totalCycles: 1,
    );
    expect(started, true);
    final state = container.read(timerProvider);
    expect(state.isRunning, true);
    expect(state.activeTaskId, 1);
  });
}
