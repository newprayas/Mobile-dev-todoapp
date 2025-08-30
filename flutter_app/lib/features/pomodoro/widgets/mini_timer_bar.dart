import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../todo/models/todo.dart';
import '../pomodoro_router.dart';
import '../../../core/utils/app_dialogs.dart';

class MiniTimerBar extends ConsumerWidget {
  final ApiService api;
  final NotificationService notificationService;
  final Todo? activeTodo;
  final Future<void> Function(int) onComplete;

  const MiniTimerBar({
    required this.api,
    required this.notificationService,
    this.activeTodo,
    required this.onComplete,
    super.key,
  });

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);

    if (!timer.isTimerActive || timer.activeTaskId == null) {
      return const SizedBox.shrink();
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) {
      return const SizedBox.shrink();
    }

    final borderColor = timer.currentMode == 'focus'
        ? Colors.redAccent
        : Colors.greenAccent;

    return GestureDetector(
      onTap: () async {
        await PomodoroRouter.showPomodoroSheet(
          context,
          api,
          activeTodo ??
              Todo(
                id: timer.activeTaskId ?? 0,
                userId: '',
                text: 'Unknown Task',
                completed: false,
                durationHours: 0,
                durationMinutes: 0,
                focusedTime: 0,
                wasOverdue: 0,
                overdueTime: 0,
              ),
          notificationService,
          ({bool wasOverdue = false, int overdueTime = 0}) async {
            if (activeTodo != null) {
              await onComplete(activeTodo!.id);
            }
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: borderColor, width: 3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _format(timer.timeRemaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeTodo?.text ?? 'Unknown Task',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: notifier.toggleRunning,
                  icon: Icon(
                    timer.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppColors.brightYellow,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (activeTodo == null) {
                      notifier.clear();
                      return;
                    }

                    final wasRunning = timer.isRunning;
                    if (wasRunning) notifier.pauseTask();

                    final totalFocusDuration =
                        timer.focusDurationSeconds ?? 1500;
                    final timeRemaining = timer.timeRemaining;
                    final minutesWorked =
                        ((totalFocusDuration - timeRemaining) / 60).round();

                    final shouldStop = await AppDialogs.showStopSessionDialog(
                      context: context,
                      taskName: activeTodo!.text,
                      minutesWorked: minutesWorked,
                    );

                    if (shouldStop != true) {
                      if (wasRunning) notifier.resumeTask();
                      return;
                    }

                    await notifier.stopAndSaveProgress(activeTodo!.id);
                    /*
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Session Stopped'),
                          content: const Text('Your progress has been saved.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                    */
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
