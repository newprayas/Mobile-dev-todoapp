import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../todo/models/todo.dart';
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
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pomodoro Timer',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 22.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    todo.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: Center(
                    child: Text(
                      'Timer functionality is working\nThis is the Pomodoro screen!',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Start timer logic
                        final container = ProviderScope.containerOf(context);
                        final timerNotifier = container.read(
                          timerProvider.notifier,
                        );
                        timerNotifier.startTask(
                          taskName: todo.text,
                          focusDuration: 25 * 60, // 25 minutes
                          breakDuration: 5 * 60, // 5 minutes
                          plannedDuration:
                              (todo.durationHours * 3600) +
                              (todo.durationMinutes * 60),
                          totalCycles: 4,
                        );
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Start Timer'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );

    updateMinibarOnDismiss();
  }
}
