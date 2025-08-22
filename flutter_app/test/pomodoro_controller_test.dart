import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pomodoro_controller.dart';

void main() {
  test('start, pause and overdue detection', () async {
    final c = PomodoroController();
    int added = 0;
    bool overdueCalled = false;
    c.onFocusSegmentComplete = (taskId, seconds) {
      added += seconds;
    };
    c.onOverdue = (taskId) {
      overdueCalled = true;
    };

    // start with short durations to exercise quickly
    c.start(
      1,
      focusSec: 2,
      breakSec: 1,
      cycles: 1,
      plannedDurationSec: 3,
      initialFocusedSeconds: 1,
    );
    expect(c.activeTaskId, 1);
    expect(c.isRunning, true);

    // wait 3 seconds for focus to end
    await Future.delayed(const Duration(seconds: 3));

    // after auto-transition, the controller should have called onFocusSegmentComplete
    expect(added > 0, true);
    // plannedDurationSec was 3 and initialFocusedSeconds was 1 so after 2 seconds it should be >=3 -> overdue called
    expect(overdueCalled, true);
    c.dispose();
  });
}
