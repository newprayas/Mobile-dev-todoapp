import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../pomodoro/widgets/pomodoro_overdue_display.dart';

typedef PlayCallback = Future<void> Function(Todo todo);

class TaskCard extends ConsumerWidget {
  final Todo todo;
  final PlayCallback onPlay;
  final Future<void> Function() onDelete;
  final Future<void> Function() onToggle;
  final bool isActive;

  const TaskCard({
    required this.todo,
    required this.onPlay,
    required this.onDelete,
    required this.onToggle,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final focusedSeconds =
        timerState.focusedTimeCache[todo.id] ?? todo.focusedTime;
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);

    final isPermanentlyOverdue = todo.wasOverdue == 1;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.midGray,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: AppColors.brightYellow, width: 1.5)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (isPermanentlyOverdue && !todo.completed)
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Text('🔴', style: TextStyle(fontSize: 14)),
                            ),
                          Expanded(
                            child: Text(
                              todo.text,
                              style: TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontStyle: todo.completed
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (todo.completed)
                      _buildCompletionTags(focusedSeconds, plannedSeconds),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${todo.durationHours}h ${todo.durationMinutes}m',
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _buildActionButtons(context, ref),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!todo.completed)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              height: 20.0, // Reduced from 28.0 for thinner progress bar
              child: isPermanentlyOverdue
                  ? PomodoroOverdueDisplay(
                      focusedSeconds: focusedSeconds,
                      plannedSeconds: plannedSeconds,
                    )
                  : ProgressBar(
                      focusedSeconds: focusedSeconds,
                      plannedSeconds: plannedSeconds,
                      barHeight: 20.0, // Reduced from 28.0
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompletionTags(int focusedSeconds, int plannedSeconds) {
    // UX Spec: If a permanently overdue task is completed, show its final overdue time.
    if (todo.wasOverdue == 1) {
      final overdueSeconds = todo.overdueTime;
      final minutes = (overdueSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (overdueSeconds % 60).toString().padLeft(2, '0');
      return _buildTag('Overdue: $minutes:$seconds', AppColors.priorityHigh);
    }

    // UX Spec: If a task is completed under its planned time, show the underdue percentage.
    if (plannedSeconds > 0 && focusedSeconds < plannedSeconds) {
      final percent = ((focusedSeconds / plannedSeconds) * 100).toStringAsFixed(
        0,
      );
      return _buildTag('Underdue task $percent%', Colors.orangeAccent);
    }

    // UX Spec: For a normal completion, show the "Completed" tag.
    return _buildTag('Completed', AppColors.priorityLow);
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Row _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onToggle,
          icon: Icon(
            // Use a "replay" or "revert" icon when completed, and a checkmark when incomplete.
            todo.completed ? Icons.replay : Icons.check_circle_outline,
            color: AppColors.lightGray,
            size: 20,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline,
            color: AppColors.lightGray,
            size: 20,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          onPressed: todo.completed ? null : () => onPlay(todo),
          icon: Icon(
            Icons.play_arrow,
            color: todo.completed ? AppColors.mediumGray : AppColors.lightGray,
            size: 20,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
