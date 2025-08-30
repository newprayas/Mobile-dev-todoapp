import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../todo/models/todo.dart';
import 'pomodoro_screen.dart'; // Import the new screen
import 'providers/timer_provider.dart';

typedef TaskCompletedCallback =
    Future<void> Function({bool wasOverdue, int overdueTime});

class PomodoroRouter {
  static Future<void> showPomodoroSheet(
    BuildContext context,
    ApiService api,
    Todo todo,
    NotificationService notificationService,
    TaskCompletedCallback onTaskCompleted,
  ) async {
    void updateMinibarOnDismiss() {
      final container = ProviderScope.containerOf(context, listen: false);
      final timerState = container.read(timerProvider);
      final timerNotifier = container.read(timerProvider.notifier);

      final bool isSetupMode =
          !timerState.isRunning && timerState.currentCycle == 0;

      if (timerState.activeTaskId != null) {
        if (isSetupMode) {
          // User closed the sheet from the setup screen without starting.
          // We should reset the timer state to avoid side effects, but preserve progress.
          timerNotifier.clearPreserveProgress();
        } else {
          // Timer has been started, so activate the mini-bar.
          timerNotifier.update(active: true);
        }
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85, // Increased from 0.8
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PomodoroScreen(
            api: api,
            todo: todo,
            notificationService: notificationService,
            asSheet: true,
            onTaskCompleted: onTaskCompleted,
          ),
        ),
      ),
    );

    updateMinibarOnDismiss();
  }
}
