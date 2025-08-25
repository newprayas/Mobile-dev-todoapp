import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/timer_service.dart';

void main() {
  setUp(() {
    // reset service to a known state before each test
    TimerService.instance.clear();
  });

  test('initial state after clear', () {
    final svc = TimerService.instance;
    expect(svc.activeTaskName, isNull);
    expect(svc.timeRemaining, 0);
    expect(svc.isRunning, isFalse);
    expect(svc.isTimerActive, isFalse);
    expect(svc.currentMode, 'focus');
    expect(svc.plannedDurationSeconds, isNull);
  });

  test('update sets fields and notifies listeners', () {
    final svc = TimerService.instance;
    var notifications = 0;
    void listener() => notifications++;
    svc.addListener(listener);

    svc.update(
      taskName: 'task1',
      remaining: 120,
      running: true,
      active: true,
      plannedDuration: 3600,
      mode: 'break',
    );

    expect(svc.activeTaskName, 'task1');
    expect(svc.timeRemaining, 120);
    expect(svc.isRunning, isTrue);
    expect(svc.isTimerActive, isTrue);
    expect(svc.plannedDurationSeconds, 3600);
    expect(svc.currentMode, 'break');
    expect(notifications, greaterThan(0));

    svc.removeListener(listener);
  });

  test('focused time cache helpers', () {
    final svc = TimerService.instance;
    svc.setFocusedTime('t1', 10);
    expect(svc.getFocusedTime('t1'), 10);

    // empty task name should be ignored (no exception)
    svc.setFocusedTime('', 5);
    expect(svc.getFocusedTime(''), isNull);
  });

  test('toggleRunning flips state and notifies', () {
    final svc = TimerService.instance;
    svc.isRunning = false;
    var notifications = 0;
    void listener() => notifications++;
    svc.addListener(listener);

    svc.toggleRunning();
    expect(svc.isRunning, isTrue);
    expect(notifications, greaterThan(0));

    svc.toggleRunning();
    expect(svc.isRunning, isFalse);

    svc.removeListener(listener);
  });

  test('clear resets state', () {
    final svc = TimerService.instance;
    svc.update(
      taskName: 'x',
      remaining: 10,
      running: true,
      active: true,
      plannedDuration: 5,
      mode: 'focus',
    );
    svc.clear();
    expect(svc.activeTaskName, isNull);
    expect(svc.timeRemaining, 0);
    expect(svc.isRunning, isFalse);
    expect(svc.isTimerActive, isFalse);
    expect(svc.currentMode, 'focus');
    expect(svc.plannedDurationSeconds, isNull);
  });
}
