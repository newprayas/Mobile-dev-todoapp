import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../todo/models/todo.dart';
import '../pomodoro_router.dart';

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

    if (!timer.isTimerActive || timer.activeTaskName == null) {
      return const SizedBox.shrink();
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) {
      if (kDebugMode) debugPrint('MINI BAR: hiding because keyboard visible');
      return const SizedBox.shrink();
    }

    if (kDebugMode) {
      debugPrint(
        'MINI BAR[build][provider]: task=${timer.activeTaskName} remaining=${timer.timeRemaining} running=${timer.isRunning} active=${timer.isTimerActive} mode=${timer.currentMode}',
      );
    }

    // Overdue detection via provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final taskName = timer.overdueCrossedTaskName;
      if (taskName != null &&
          taskName == (timer.activeTaskName ?? '') &&
          !timer.overduePromptShown.contains(taskName)) {
        _showOverduePromptFromMiniBar(
          context,
          activeTodo ??
              Todo(
                id: 0,
                userId: '',
                text: timer.activeTaskName ?? '',
                completed: false,
                durationHours: 0,
                durationMinutes: 0,
                focusedTime: 0,
                wasOverdue: 0,
                overdueTime: 0,
              ),
          onComplete,
          notificationService,
          ref,
        );
      }
    });

    final borderColor = timer.currentMode == 'focus'
        ? Colors.redAccent
        : Colors.greenAccent;

    return GestureDetector(
      onTap: () async {
        if (kDebugMode) {
          debugPrint('MINI BAR: opening full sheet (adapter stage)');
        }
        notifier.update(active: false);
        await PomodoroRouter.showPomodoroSheet(
          context,
          api,
          activeTodo ??
              Todo(
                id: 0,
                userId: '',
                text: timer.activeTaskName ?? '',
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
            Column(
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
                SizedBox(
                  width: 200,
                  child: Text(
                    timer.activeTaskName ?? '',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                if (kDebugMode) {
                  debugPrint('MINI BAR: play/pause via legacy service');
                }
                notifier.toggleRunning();
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
                if (kDebugMode) debugPrint('MINI BAR: expand pressed');
                await PomodoroRouter.showPomodoroSheet(
                  context,
                  api,
                  activeTodo ??
                      Todo(
                        id: 0,
                        userId: '',
                        text: timer.activeTaskName ?? '',
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
                notifier.update(active: false);
              },
              icon: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
              ),
            ),
            // *** UX ENHANCEMENT: Quick stop/close button ***
            IconButton(
              onPressed: () async {
                if (kDebugMode) debugPrint('MINI BAR: stop session pressed');

                // Save progress if there's an active todo
                if (activeTodo != null) {
                  final success = await notifier.stopAndSaveProgress(
                    activeTodo!.id,
                  );

                  // Show feedback
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Session stopped and progress saved ✓'
                              : 'Session stopped (save failed)',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: success
                            ? Colors.green[700]
                            : Colors.orange[700],
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  // No active todo, just clear the session
                  notifier.clear();
                }
              },
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper to show overdue prompt when mini-bar detects a crossed planned duration
Future<void> _showOverduePromptFromMiniBar(
  BuildContext context,
  Todo todo,
  Future<void> Function(int) onComplete,
  NotificationService notificationService,
  WidgetRef ref,
) async {
  final timer = ref.read(timerProvider);
  final notifier = ref.read(timerProvider.notifier);
  final taskName = timer.overdueCrossedTaskName;
  if (taskName == null || taskName != (timer.activeTaskName ?? '')) return;
  if (timer.overduePromptShown.contains(taskName)) return;

  notifier.markOverduePromptShown(taskName);

  notificationService.showNotification(
    title: 'Task Overdue',
    body: 'Planned time for "${todo.text}" is complete.',
  );
  try {
    notificationService.playSound('progress_bar_full.wav');
  } catch (_) {}

  final res = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('"${todo.text}" Overdue'),
      content: const Text(
        'Planned time is complete. Mark task as done or continue working?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('continue'),
          child: const Text('Continue'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop('complete'),
          child: const Text('Mark Complete'),
        ),
      ],
    ),
  );

  if (res == 'complete') {
    await onComplete(todo.id);
    notifier.clear();
  } else {
    notifier.markOverdueContinued(taskName);
  }
}
