import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/features/pomodoro/models/timer_state.dart';
import 'package:focus_timer_app/features/pomodoro/providers/timer_provider.dart';
import 'package:focus_timer_app/core/providers/notification_action_provider.dart';
import 'package:focus_timer_app/core/providers/notification_provider.dart';
import 'package:focus_timer_app/core/services/notification_service.dart';

// Minimal fake NotificationService (no-op)
class _FakeNotificationService implements NotificationService {
  @override
  Function(String? payload)? onNotificationTap;
  @override
  Future<void> init() async {}
  @override
  Future<void> cancelPersistentTimerNotification() async {}
  @override
  Future<void> playSound(String soundFileName) async {}
  @override
  Future<void> playSoundWithNotification({required String soundFileName, required String title, required String body}) async {}
  @override
  Future<void> showNotification({required String title, required String body, String? payload, String? soundFileName}) async {}
  @override
  Future<void> showOrUpdatePersistent({required String title, required String body, required List<String> actionIds}) async {}
  @override
  Future<void> debugDumpActiveNotifications() async {}
  @override
  Future<void> ensurePermissions() async {}
}

// Fake lightweight TimerNotifier that only reacts to actions; avoids persistence & Workmanager.
class _FakeTimerNotifier extends TimerNotifier {
  String? lastAction;

  @override
  TimerState build() {
    // Provide a simple running state baseline
    return const TimerState(
      isRunning: true,
      isTimerActive: true,
      currentMode: 'focus',
      timeRemaining: 100,
      focusDurationSeconds: 100,
      breakDurationSeconds: 20,
      plannedDurationSeconds: 100,
    );
  }

  @override
  Future<void> handleNotificationAction(String actionId) async {
    lastAction = actionId;
    if (actionId == 'pause_timer') {
      state = state.copyWith(isRunning: false);
    } else if (actionId == 'resume_timer') {
      state = state.copyWith(isRunning: true);
    } else if (actionId == 'stop_timer') {
      state = state.copyWith(isTimerActive: false, activeTaskId: null, activeTaskName: null, isRunning: false);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A small widget that mirrors the listener logic from App and displays timer status.
  Widget _buildHarness() {
    return Consumer(
      builder: (context, ref, _) {
        ref.listen<String?>(notificationActionProvider, (prev, next) {
          if (next != null) {
            ref.read(timerProvider.notifier).handleNotificationAction(next);
            ref.read(notificationActionProvider.notifier).state = null;
          }
        });
        final timerState = ref.watch(timerProvider);
        return Text(timerState.isRunning ? 'running' : 'paused', textDirection: TextDirection.ltr);
      },
    );
  }

  group('notificationActionProvider -> TimerNotifier wiring', () {
    testWidgets('pause then resume updates timer state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
            timerProvider.overrideWith(_FakeTimerNotifier.new),
          ],
          child: _buildHarness(),
        ),
      );

      expect(find.text('running'), findsOneWidget);
      // Trigger pause
      final container = ProviderScope.containerOf(tester.element(find.text('running')));
      container.read(notificationActionProvider.notifier).state = 'pause_timer';
      await tester.pump();
      expect(find.text('paused'), findsOneWidget, reason: 'Should reflect paused after pause action');

      // Trigger resume
      container.read(notificationActionProvider.notifier).state = 'resume_timer';
      await tester.pump();
      expect(find.text('running'), findsOneWidget, reason: 'Should reflect running after resume action');
    });

    testWidgets('stop_timer clears active timer flag', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
            timerProvider.overrideWith(_FakeTimerNotifier.new),
          ],
          child: _buildHarness(),
        ),
      );

      final container = ProviderScope.containerOf(tester.element(find.text('running')));
      container.read(notificationActionProvider.notifier).state = 'stop_timer';
      await tester.pump();
      final state = container.read(timerProvider);
      expect(state.isTimerActive, isFalse);
      expect(state.activeTaskId, isNull);
    });
  });
}
