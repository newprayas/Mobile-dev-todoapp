import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/todo.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/state_machine/timer_events.dart';

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
    return todo.completed
        ? _buildCompletedTask(context)
        : _buildIncompleteTask(context, ref);
  }

  Widget _buildIncompleteTask(BuildContext context, WidgetRef ref) {
    final isPermanentlyOverdue = todo.wasOverdue == 1;

    // Watch the timer state to get live updates for focused time.
    final timerState = ref.watch(timerProvider);
    final focusedSeconds =
        timerState.focusedTimeCache[todo.id] ?? todo.focusedTime;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.midGray,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: AppColors.brightYellow, width: 2.0)
            : Border.all(color: Colors.transparent, width: 2.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.text,
                  style: const TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${todo.durationHours}h ${todo.durationMinutes}m',
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isPermanentlyOverdue)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Overdue: ${_formatOverdueDuration((focusedSeconds - ((todo.durationHours * 3600) + (todo.durationMinutes * 60))).clamp(0, 999999).toInt())}',
                      style: const TextStyle(
                        color: AppColors.priorityHigh,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildActionButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildCompletedTask(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        // Replaced deprecated withOpacity with withValues for modern color API.
        color: AppColors.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.text,
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic, // Set to italic
                        decoration: TextDecoration.none, // Remove strikethrough
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${todo.durationHours}h ${todo.durationMinutes}m',
                      style: TextStyle(
                        // Replaced deprecated withOpacity with withValues.
                        color: AppColors.mediumGray.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // This invisible placeholder mimics the space of the 'play' button in active tasks,
                  // ensuring the following two buttons align correctly.
                  Opacity(
                    opacity: 0.0,
                    child: IconButton(
                      icon: const Icon(Icons.play_arrow, size: 24),
                      onPressed: () {},
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggle,
                    icon: const Icon(
                      Icons.replay,
                      color: AppColors.mediumGray,
                      size: 24,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.mediumGray,
                      size: 24,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompletionStatus(),
        ],
      ),
    );
  }

  Widget _buildCompletionStatus() {
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);

    final completedTag = const Text(
      'Completed',
      style: TextStyle(
        color: AppColors.priorityLow,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );

    // Case 1: Task was completed overdue. Show both tags stacked.
    if (todo.wasOverdue == 1) {
      final formattedDuration = _formatOverdueDuration(todo.overdueTime);
      final overdueTag = Text(
        'Overdue: $formattedDuration',
        style: const TextStyle(
          color: AppColors.priorityHigh,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [overdueTag, const SizedBox(height: 4.0), completedTag],
      );
    }

    // Case 2: Task was completed underdue. Show ONLY the underdue tag.
    if (plannedSeconds > 0 && todo.focusedTime < plannedSeconds) {
      final percent = ((todo.focusedTime / plannedSeconds) * 100)
          .toStringAsFixed(0);
      final underdueTag = Text(
        'Underdue ($percent%)',
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      return Wrap(spacing: 8.0, children: [underdueTag]);
    }

    // Case 3 (Default): Task was completed on time or had no duration. Show ONLY the completed tag.
    return Wrap(spacing: 8.0, children: [completedTag]);
  }

  String _formatOverdueDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final isThisTaskActive = timerState.activeTaskId == todo.id;
    final isThisTaskRunning = isThisTaskActive && timerState.isRunning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () async {
            final notifier = ref.read(timerProvider.notifier);
            if (!isThisTaskActive) {
              await onPlay(todo); // starts task (enters setup or running state)
              return;
            }
            // Active task: emit pause/resume events directly (legacy pauseTask/resumeTask removed).
            if (isThisTaskRunning) {
              notifier.emitExternal(const PauseEvent());
            } else {
              notifier.emitExternal(const ResumeEvent());
            }
          },
          icon: Icon(
            isThisTaskRunning ? Icons.pause : Icons.play_arrow,
            color: todo.completed ? AppColors.mediumGray : AppColors.lightGray,
            size: 24,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          onPressed: onToggle,
          icon: const Icon(Icons.check, color: AppColors.lightGray, size: 24),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline,
            color: AppColors.lightGray,
            size: 24,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
