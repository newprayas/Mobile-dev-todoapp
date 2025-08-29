import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pomodoro/providers/timer_provider.dart';

typedef PlayCallback = Future<void> Function(Todo todo);

class TaskCard extends ConsumerStatefulWidget {
  final Todo todo;
  final PlayCallback onPlay;
  final Future<void> Function() onDelete;
  final Future<void> Function() onToggle;
  // UI-only flag; parent can set this when the task is active (timer running)
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
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  String _formatOverdueTime(int overdueSeconds) {
    final hours = overdueSeconds ~/ 3600;
    final minutes = (overdueSeconds % 3600) ~/ 60;
    final seconds = overdueSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Add this helper method inside the state for reusable tag UI
  Widget _buildOverdueTag(Todo todo, int cachedFocused) {
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);
    final overdueSeconds = (cachedFocused - plannedSeconds)
        .clamp(0, double.infinity)
        .toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Overdue: ${_formatOverdueTime(overdueSeconds)}',
        style: TextStyle(
          color: AppColors.priorityHigh,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch timer state for the specific values we need
    final focusedTimeCache = ref.watch(
      timerProvider.select((state) => state.focusedTimeCache),
    );
    final overdueContinued = ref.watch(
      timerProvider.select((state) => state.overdueContinued),
    );
    final timerState = ref.watch(timerProvider);

    final totalMins =
        (widget.todo.durationHours * 60) + widget.todo.durationMinutes;
    final plannedSeconds =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);
    final cachedFocused =
        focusedTimeCache[widget.todo.text] ?? widget.todo.focusedTime;
    final progress = totalMins == 0
        ? 0.0
        : (cachedFocused / (totalMins * 60)).clamp(0.0, 1.0);

    // *** FIX: Only show as overdue if currently active AND crossed planned time in current session ***
    final isCurrentlyActive =
        timerState.activeTaskName == widget.todo.text &&
        timerState.isTimerActive;
    final hasOverdueCrossed =
        timerState.overdueCrossedTaskName == widget.todo.text;
    final bool isOverdue = isCurrentlyActive && hasOverdueCrossed;
    final bool isContinuedOverdue = overdueContinued.contains(widget.todo.text);
    final bool isPermanentlyOverdue = widget.todo.wasOverdue == 1;

    if (kDebugMode) {
      debugPrint(
        'TASK_CARD: id=${widget.todo.id} cachedFocused=$cachedFocused planned=$plannedSeconds isOverdue=$isOverdue isActive=$isCurrentlyActive hasOverdueCrossed=$hasOverdueCrossed',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task card content container
        Container(
          decoration: BoxDecoration(
            color: AppColors.midGray,
            borderRadius: BorderRadius.circular(12),
            border: widget.isActive
                ? Border.all(color: AppColors.brightYellow, width: 1.5)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main task row with text and status
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Red emoji for overdue tasks (completed and revived)
                          if (isPermanentlyOverdue ||
                              isOverdue ||
                              isContinuedOverdue)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text('🔴', style: TextStyle(fontSize: 14)),
                            ),
                          Expanded(
                            child: Text(
                              widget.todo.text,
                              style: TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: widget.todo.completed
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                fontStyle: widget.todo.completed
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // *** REVISED TAG LOGIC ***
                    if (widget.todo.completed) ...[
                      if (widget.todo.wasOverdue == 1)
                        // Case: Completed AND was overdue. Show completed with overdue info.
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Completed',
                                style: TextStyle(
                                  color: AppColors.priorityLow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildOverdueTag(
                              widget.todo,
                              widget.todo.focusedTime,
                            ),
                          ],
                        )
                      else if (plannedSeconds > 0 &&
                          cachedFocused < plannedSeconds)
                        // Case: Completed and Underdue.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Underdue task ${((cachedFocused / plannedSeconds) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        // Case: Completed normally.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              color: AppColors.priorityLow,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ] else if (isOverdue && !isPermanentlyOverdue) ...[
                      // Case: Incomplete and JUST crossed overdue in this session (not yet permanent)
                      _buildOverdueTag(widget.todo, cachedFocused),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Task details row with duration, focused time, and actions
                Row(
                  children: [
                    Text(
                      '${widget.todo.durationHours}h ${widget.todo.durationMinutes}m',
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(cachedFocused / 60).floor()}m',
                      style: TextStyle(
                        color: AppColors.brightYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Complete/Uncomplete button
                        IconButton(
                          onPressed: widget.onToggle,
                          icon: Icon(
                            widget.todo.completed
                                ? Icons.close
                                : Icons.check_circle,
                            color: AppColors.lightGray,
                            size: 20,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        // Delete button
                        IconButton(
                          onPressed: widget.onDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.lightGray,
                            size: 20,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        // Play/Pause button (disabled for completed tasks)
                        Builder(
                          builder: (context) {
                            final timerState = ref.watch(timerProvider);
                            final isThisActive =
                                timerState.activeTaskName == widget.todo.text &&
                                timerState.isTimerActive;
                            final isRunning =
                                isThisActive && timerState.isRunning;
                            return IconButton(
                              onPressed: widget.todo.completed
                                  ? null
                                  : () => widget.onPlay(widget.todo),
                              icon: Icon(
                                isThisActive
                                    ? (isRunning
                                          ? Icons.pause
                                          : Icons.play_arrow)
                                    : Icons.play_arrow,
                                color: widget.todo.completed
                                    ? AppColors.mediumGray
                                    : AppColors.lightGray,
                                size: 20,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Progress bar (for non-completed tasks that aren't currently overdue)
        if (!widget.todo.completed &&
            !isPermanentlyOverdue &&
            !isOverdue &&
            !isContinuedOverdue &&
            totalMins > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.brightYellow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Overdue time display (only for currently overdue or continued overdue tasks)
        if (!widget.todo.completed &&
            (isPermanentlyOverdue || isContinuedOverdue || isOverdue) &&
            totalMins > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'OVERDUE TIME: ${_formatOverdueTime((cachedFocused - plannedSeconds).clamp(0, double.infinity).toInt())}',
              style: TextStyle(
                color: AppColors.priorityHigh,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
