import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/side_effect_runner.dart';
import 'package:focus_timer_app/features/pomodoro/state_machine/timer_side_effects.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';
import 'package:focus_timer_app/core/services/notification_service.dart';
import 'package:focus_timer_app/features/pomodoro/services/timer_persistence_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  final List<String> log = [];
  @override
  Future<void> showOrUpdatePersistent({
    required String title,
    required String body,
    required List<String> actionIds,
  }) async {
    log.add('persistent:$title:$body:${actionIds.join(',')}');
  }

  @override
  Future<void> cancelPersistentTimerNotification() async {
    log.add('cancel');
  }

  @override
  Future<void> playSound(String soundFileName) async {
    log.add('sound:$soundFileName');
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? soundFileName,
  }) async {
    log.add('notify:$title:$body');
  }
}

class _MemoryPrefs implements SharedPreferences {
  final Map<String, Object> _store = {};
  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _store[key] as String?;
  // Stub other members minimally
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('SideEffectRunner executes ShowNotificationEffect', () async {
    final container = ProviderContainer();
    final fakeService = _FakeNotificationService();
    final prefs = _MemoryPrefs();
    final persistence = TimerPersistenceManager(prefs);
    final runner = SideEffectRunner(
      container.read,
      notificationService: fakeService,
      persistenceManager: persistence,
    );
    final state = const TimerState(
      isTimerActive: true,
      isRunning: true,
      timeRemaining: 1500,
      activeTaskName: 'Task',
    );
    await runner.run(const [ShowNotificationEffect()], state);
    expect(fakeService.log.first.startsWith('persistent:'), true);
  });

  test(
    'SideEffectRunner executes PlaySoundEffect with transient notification',
    () async {
      final container = ProviderContainer();
      final fakeService = _FakeNotificationService();
      final prefs = _MemoryPrefs();
      final persistence = TimerPersistenceManager(prefs);
      final runner = SideEffectRunner(
        container.read,
        notificationService: fakeService,
        persistenceManager: persistence,
      );
      final state = const TimerState(
        isTimerActive: true,
        isRunning: true,
        timeRemaining: 10,
        activeTaskName: 'Task',
      );
      await runner.run(const [
        PlaySoundEffect(
          'focus_timer_start.wav',
          title: 'Focus Session Started!',
          body: 'Go!',
        ),
      ], state);
      expect(
        fakeService.log.any((e) => e.startsWith('sound:focus_timer_start.wav')),
        true,
      );
      expect(
        fakeService.log.any(
          (e) => e.startsWith('notify:Focus Session Started!'),
        ),
        true,
      );
    },
  );
}
