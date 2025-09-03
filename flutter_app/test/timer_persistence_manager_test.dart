import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_timer_app/features/pomodoro/services/timer_persistence_manager.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimerPersistenceManager', () {
    late SharedPreferences prefs;
    late TimerPersistenceManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      manager = TimerPersistenceManager(prefs);
    });

    test('saves and loads timer state roundtrip', () async {
      final state = const TimerState(
        activeTaskId: 1,
        activeTaskName: 'Test',
        timeRemaining: 120,
        isRunning: true,
        currentMode: 'focus',
        totalCycles: 4,
        currentCycle: 2,
        focusedTimeCache: {1: 30},
      );

      await manager.saveTimerState(state);
      final loaded = manager.loadTimerState();

      expect(loaded, isNotNull);
      expect(loaded!.activeTaskId, 1);
      expect(loaded.activeTaskName, 'Test');
      expect(loaded.timeRemaining, 120);
      expect(loaded.isRunning, true);
      expect(loaded.focusedTimeCache[1], 30);
    });

    test('clearTimerState removes persisted keys', () async {
      final state = const TimerState(activeTaskId: 2, activeTaskName: 'Task');
      await manager.saveTimerState(state);
      expect(manager.loadTimerState(), isNotNull);

      await manager.clearTimerState();
      expect(manager.loadTimerState(), isNull);
    });
  });
}
