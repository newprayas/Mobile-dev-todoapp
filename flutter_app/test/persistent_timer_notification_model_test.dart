import 'package:flutter_test/flutter_test.dart';
import 'package:focus_timer_app/features/pomodoro/notifications/persistent_timer_notification_model.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';
import 'package:focus_timer_app/features/pomodoro/providers/timer_provider.dart';
import 'package:focus_timer_app/features/todo/models/todo.dart';

TimerState baseState() => const TimerState(
  timeRemaining: 1500,
  isRunning: true,
  currentMode: 'focus',
  focusDurationSeconds: 1500,
  breakDurationSeconds: 300,
  currentCycle: 1,
  totalCycles: 2,
);

Todo sampleTodo({bool overdue = false}) => Todo(
  id: 1,
  userId: 'u',
  text: 'Design New Logo',
  completed: false,
  durationHours: 0,
  durationMinutes: 25,
  focusedTime: overdue ? 1600 : 0,
  wasOverdue: overdue ? 1 : 0,
  overdueTime: overdue ? 100 : 0,
  createdAt: DateTime.now(),
);

void main() {
  group('PersistentTimerNotificationModel.fromState', () {
    test('standard running focus session', () {
      final model = PersistentTimerNotificationModel.fromState(
        state: baseState(),
        activeTodo: sampleTodo(),
      );
      expect(model.title, '🎯 FOCUS TIME');
  expect(model.actionIds.first, anyOf(['pause_timer','resume_timer']));
      expect(model.actionIds, contains('stop_timer'));
    });

    test('planned time first reached (progress bar full)', () {
      final state = baseState().copyWith(isProgressBarFull: true, isRunning: false);
      final model = PersistentTimerNotificationModel.fromState(
        state: state,
        activeTodo: sampleTodo(),
      );
      expect(model.title, 'TIMER IS COMPLETE');
      expect(model.actionIds, ['mark_complete', 'continue_working']);
    });

    test('permanently overdue active focus count-up', () {
      final state = baseState().copyWith(isPermanentlyOverdue: true, timeRemaining: 1490);
      final model = PersistentTimerNotificationModel.fromState(
        state: state,
        activeTodo: sampleTodo(overdue: true),
      );
      expect(model.title, '🔴 FOCUS TIME');
  expect(model.actionIds.first, anyOf(['pause_timer','resume_timer']));
    });

    test('overdue all planned sessions complete', () {
      final state = baseState().copyWith(
        isPermanentlyOverdue: true,
        overdueSessionsComplete: true,
        isRunning: false,
      );
      final model = PersistentTimerNotificationModel.fromState(
        state: state,
        activeTodo: sampleTodo(overdue: true),
      );
      expect(model.title, '✅ SESSIONS COMPLETE');
      expect(model.actionIds, ['mark_complete', 'continue_working']);
    });

    test('paused session shows resume action', () {
      final state = baseState().copyWith(isRunning: false);
      final model = PersistentTimerNotificationModel.fromState(
        state: state,
        activeTodo: sampleTodo(),
      );
      expect(model.actionIds.first, 'resume_timer');
    });

    test('running session shows pause action then stop', () {
      final state = baseState();
      final model = PersistentTimerNotificationModel.fromState(
        state: state,
        activeTodo: sampleTodo(),
      );
      expect(model.actionIds, isNotEmpty);
      expect(model.actionIds.first, 'pause_timer');
      expect(model.actionIds[1], 'stop_timer');
    });
  });
}
