import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/timer_defaults.dart';
import '../providers/timer_provider.dart';
import '../state_machine/timer_events.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../todo/models/todo.dart';
import '../pomodoro_router.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/services/api_service.dart';

class MiniTimerBar extends ConsumerWidget {
  final ApiService api; // Strongly typed
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
    final String m = (seconds ~/ 60).toString().padLeft(2, '0');
    final String s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);

    if (!timer.isTimerActive || timer.activeTaskId == null) {
      return const SizedBox.shrink();
    }

    final bool keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) {
      return const SizedBox.shrink();
    }

    final Color borderColor = timer.currentMode == 'focus'
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
                createdAt: DateTime.now(),
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
                  onPressed: () {
                    // Dispatch pure events so reducer is sole source of truth.
                    if (timer.isRunning) {
                      notifier.emitExternal(const PauseEvent());
                    } else {
                      notifier.emitExternal(const ResumeEvent());
                    }
                  },
                  icon: Icon(
                    timer.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppColors.brightYellow,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final int? taskId = timer.activeTaskId;
                    if (taskId == null) {
                      // No active task – nothing to stop.
                      return;
                    }

                    // If we have an active todo, confirm stop (legacy dialog); otherwise just stop.
                    if (activeTodo != null) {
                      final int totalFocusDuration =
                          timer.focusDurationSeconds ??
                          TimerDefaults.focusSeconds;
                      final int timeRemaining = timer.timeRemaining;
                      final int minutesWorked =
                          ((totalFocusDuration - timeRemaining) / 60).round();

                      final bool? shouldStop =
                          await AppDialogs.showStopSessionDialog(
                            context: context,
                            taskName: activeTodo!.text,
                            minutesWorked: minutesWorked,
                          );
                      if (shouldStop != true) return;
                    }

                    notifier.emitExternal(StopAndSaveEvent(taskId));
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
