import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/todo.dart';

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
        : _buildIncompleteTask(context);
  }

  Widget _buildIncompleteTask(BuildContext context) {
    final isPermanentlyOverdue = todo.wasOverdue == 1;

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
                      'Overdue: ${_formatOverdueDuration(todo.overdueTime)}',
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
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCompletedTask(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withOpacity(0.5),
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
                        color: AppColors.mediumGray.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onToggle,
                    icon: const Icon(
                      Icons.replay,
                      color: AppColors.mediumGray,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.mediumGray,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
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

    if (todo.wasOverdue == 1) {
      final formattedDuration = _formatOverdueDuration(todo.overdueTime);
      return Text(
        'Overdue: $formattedDuration',
        style: const TextStyle(
          color: AppColors.priorityHigh,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (plannedSeconds > 0 && todo.focusedTime < plannedSeconds) {
      final percent = ((todo.focusedTime / plannedSeconds) * 100)
          .toStringAsFixed(0);
      return Text(
        'Underdue task ($percent%)',
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return const Text(
      'Completed task',
      style: TextStyle(
        color: AppColors.priorityLow,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onPlay(todo),
          icon: Icon(
            Icons.play_arrow,
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
