import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../todo/models/todo.dart';
import 'pomodoro_screen.dart'; // Import the new screen
import 'providers/timer_provider.dart';

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

      if (timerState.activeTaskName != null) {
        timerNotifier.update(active: true);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
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
