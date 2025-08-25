import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/timer_service.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../models/todo.dart';
import '../screens/pomodoro_screen.dart';

class MiniTimerBar extends StatefulWidget {
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

  @override
  State<MiniTimerBar> createState() => _MiniTimerBarState();
}

class _MiniTimerBarState extends State<MiniTimerBar> {
  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TimerService.instance,
      builder: (context, _) {
        final svc = TimerService.instance;
        if (!svc.isTimerActive || svc.activeTaskName == null) {
          return const SizedBox.shrink();
        }
        // Hide the mini-timer when the keyboard is visible so it doesn't
        // float on top of the keyboard and obstruct typing.
        final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        if (keyboardVisible) {
          if (kDebugMode) {
            debugPrint('MINI BAR: hiding because keyboard is visible');
          }
          return const SizedBox.shrink();
        }
        final mode = svc.currentMode;
        final borderColor = mode == 'focus'
            ? Colors.redAccent
            : Colors.greenAccent;

        if (kDebugMode) {
          debugPrint(
            'MINI BAR[build]: task=${svc.activeTaskName} remaining=${svc.timeRemaining} running=${svc.isRunning} active=${svc.isTimerActive} mode=${svc.currentMode}',
          );
        }

        // Schedule a post-frame prompt if the central service indicates the planned duration
        // was crossed while running in the mini-bar. This ensures the dialog appears even
        // when the full Pomodoro sheet is not open.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final svcAfter = TimerService.instance;
          if (svcAfter.overdueCrossedTaskName != null &&
              svcAfter.overdueCrossedTaskName ==
                  (svcAfter.activeTaskName ?? '') &&
              !svcAfter.hasOverduePromptBeenShown(
                svcAfter.overdueCrossedTaskName!,
              )) {
            if (context.mounted) {
              _showOverduePromptFromMiniBar(
                context,
                widget.activeTodo ??
                    Todo(
                      id: 0,
                      userId: '',
                      text: svcAfter.activeTaskName ?? '',
                      completed: false,
                      durationHours: 0,
                      durationMinutes: 0,
                      focusedTime: 0,
                      wasOverdue: 0,
                      overdueTime: 0,
                    ),
                widget.onComplete,
                widget.notificationService,
              );
            }
          }
        });

        // (No-op) post-frame work already scheduled earlier in this builder.

        return GestureDetector(
          onTap: () async {
            if (kDebugMode) {
              debugPrint(
                'MINI BAR: opening full Pomodoro sheet; deactivating mini-bar internal ticker first',
              );
            }
            TimerService.instance.update(active: false);
            await PomodoroScreen.showAsBottomSheet(
              context,
              widget.api,
              widget.activeTodo ??
                  Todo(
                    id: 0,
                    userId: '',
                    text: svc.activeTaskName ?? '',
                    completed: false,
                    durationHours: 0,
                    durationMinutes: 0,
                    focusedTime: 0,
                    wasOverdue: 0,
                    overdueTime: 0,
                  ),
              widget.notificationService,
              () async {
                if (widget.activeTodo != null) {
                  await widget.onComplete(widget.activeTodo!.id);
                }
              },
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              // Revert from pill shape to a standard rounded rectangle
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor, width: 3),
            ),
            // Keep padding consistent but slightly reduced vertical padding
            // so the bar sits comfortably when visible.
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _format(svc.timeRemaining),
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
                        svc.activeTaskName ?? '',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F), // yellow
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
                      debugPrint(
                        'MINI BAR: play/pause pressed, delegating to TimerService.toggleRunning()',
                      );
                    }
                    TimerService.instance.toggleRunning();
                  },
                  icon: Icon(
                    TimerService.instance.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppColors.brightYellow,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (kDebugMode) {
                      debugPrint('MINI BAR: expand pressed');
                    }
                    await PomodoroScreen.showAsBottomSheet(
                      context,
                      widget.api,
                      widget.activeTodo ??
                          Todo(
                            id: 0,
                            userId: '',
                            text: svc.activeTaskName ?? '',
                            completed: false,
                            durationHours: 0,
                            durationMinutes: 0,
                            focusedTime: 0,
                            wasOverdue: 0,
                            overdueTime: 0,
                          ),
                      widget.notificationService,
                      () async {
                        if (widget.activeTodo != null) {
                          await widget.onComplete(widget.activeTodo!.id);
                        }
                      },
                    );
                    TimerService.instance.update(active: false);
                  },
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper to show overdue prompt when mini-bar detects a crossed planned duration
Future<void> _showOverduePromptFromMiniBar(
  BuildContext context,
  Todo todo,
  Future<void> Function(int) onComplete,
  NotificationService notificationService,
) async {
  final svc = TimerService.instance;
  final taskName = svc.overdueCrossedTaskName;
  if (taskName == null || taskName != (svc.activeTaskName ?? '')) return;
  if (svc.hasOverduePromptBeenShown(taskName)) return;

  // mark as shown so it won't repeat
  svc.markOverduePromptShown(taskName);

  notificationService.showNotification(
    title: 'Task Overdue',
    body: 'Planned time for "${todo.text}" is complete.',
  );
  try {
    notificationService.playSound('assets/sounds/progress_bar_full.wav');
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
    TimerService.instance.clear();
  } else {
    // keep running; record that the user chose to continue so UI can reflect it
    try {
      TimerService.instance.markUserContinuedOverdue(taskName);
    } catch (_) {}
  }
}
