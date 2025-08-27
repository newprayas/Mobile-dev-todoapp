import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../models/todo.dart';
import '../theme/app_colors.dart';
import 'progress_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';

typedef PlayCallback = Future<void> Function(Todo todo);

class TaskCard extends ConsumerStatefulWidget {
  final Todo todo;
  final PlayCallback onPlay;
  final Future<void> Function() onDelete;
  final Future<void> Function() onToggle;
  final Future<void> Function(String) onUpdateText;
  final Future<void> Function(int hours, int minutes) onUpdateDuration;
  // UI-only flag; parent can set this when the task is active (timer running)
  final bool isActive;

  const TaskCard({
    required this.todo,
    required this.onPlay,
    required this.onDelete,
    required this.onToggle,
    required this.onUpdateText,
    required this.onUpdateDuration,
    this.isActive = false,
    super.key,
  });

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.todo.text);
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todo.text != oldWidget.todo.text) {
      _editController.text = widget.todo.text;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final totalMins =
        (widget.todo.durationHours * 60) + widget.todo.durationMinutes;
    final progress = totalMins == 0
        ? 0.0
        : (widget.todo.focusedTime / totalMins).clamp(0.0, 1.0);
    final plannedSeconds =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);
    final cachedFocused =
        timerState.focusedTimeCache[widget.todo.text] ??
        widget.todo.focusedTime;
    final isOverdue = plannedSeconds > 0 && cachedFocused >= plannedSeconds;
    final isContinuedOverdue = timerState.overdueContinued.contains(
      widget.todo.text,
    );

    if (kDebugMode) {
      debugPrint(
        'TASK_CARD: id=${widget.todo.id} cachedFocused=$cachedFocused planned=$plannedSeconds isOverdue=$isOverdue',
      );
    }

    return Opacity(
      opacity: widget.todo.completed ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardWidth = constraints.maxWidth;
              final fillWidth =
                  (cardWidth *
                  (isOverdue
                      ? (cachedFocused / math.max(1, totalMins))
                      : progress));
              const fillColor = Colors.transparent;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.midGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.midGray,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: fillWidth.clamp(0.0, cardWidth * 2),
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: widget.isActive
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.brightYellow,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                )
                              : null,
                          child: Focus(
                            child: Builder(
                              builder: (ctx) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editController,
                                        style: TextStyle(
                                          color: AppColors.lightGray,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          fontStyle: widget.todo.completed
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          filled: false,
                                          border: InputBorder.none,
                                        ),
                                        onSubmitted: (v) async {
                                          final newText = v.trim();
                                          if (newText.isEmpty) return;
                                          await widget.onUpdateText(newText);
                                        },
                                      ),
                                    ),
                                    if (!widget.todo.completed &&
                                        isContinuedOverdue)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
                                        child: Text('🔴'),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (ctx) {
                            final isActiveOverdue =
                                (plannedSeconds > 0 &&
                                cachedFocused >= plannedSeconds);
                            final showTag =
                                isActiveOverdue ||
                                isContinuedOverdue ||
                                (widget.todo.overdueTime > 0) ||
                                (widget.todo.completed &&
                                    plannedSeconds > 0 &&
                                    ((cachedFocused / plannedSeconds) * 100)
                                            .round() <
                                        100);
                            if (!showTag) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 6.0,
                                bottom: 4.0,
                              ),
                              child: _buildStatusDisplay(
                                widget.todo,
                                cachedFocused,
                                plannedSeconds,
                                isContinuedOverdue,
                              ),
                            );
                          },
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () async {
                                  final tmpHours = TextEditingController(
                                    text: '${widget.todo.durationHours}',
                                  );
                                  final tmpMins = TextEditingController(
                                    text: '${widget.todo.durationMinutes}',
                                  );
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      title: const Text('Edit duration'),
                                      content: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: tmpHours,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Hours',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: tmpMins,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Minutes',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(dctx).pop(true),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    final h2 = int.tryParse(tmpHours.text) ?? 0;
                                    final m2 = int.tryParse(tmpMins.text) ?? 0;
                                    await widget.onUpdateDuration(h2, m2);
                                  }
                                },
                                child: Text(
                                  '${widget.todo.durationHours}h ${widget.todo.durationMinutes}m',
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${cachedFocused ~/ 60}m',
                              style: TextStyle(
                                color: AppColors.brightYellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                widget.todo.completed
                                    ? Icons.undo
                                    : Icons.check_circle_outline,
                              ),
                              color: AppColors.lightGray,
                              onPressed: () async {
                                await widget.onToggle();
                              },
                              tooltip: widget.todo.completed
                                  ? 'Mark incomplete'
                                  : 'Mark completed',
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.lightGray,
                              onPressed: () async {
                                await widget.onDelete();
                              },
                              tooltip: 'Delete',
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              color: AppColors.lightGray,
                              onPressed: () async {
                                await widget.onPlay(widget.todo);
                              },
                              tooltip: 'Play',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          if (!widget.todo.completed && !isContinuedOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: SizedBox(
                height: 14,
                child: ProgressBar(
                  focusedSeconds: cachedFocused,
                  plannedSeconds: plannedSeconds,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusDisplay(
    Todo todo,
    int cachedFocused,
    int plannedSeconds,
    bool isContinuedOverdue,
  ) {
    // For continued overdue tasks, show overdue time
    final isActiveOverdue =
        plannedSeconds > 0 && cachedFocused >= plannedSeconds;
    if (isContinuedOverdue || (todo.overdueTime > 0) || isActiveOverdue) {
      // Calculate overdue seconds - prefer real-time calculation for active tasks
      int overdueSeconds = 0;
      if ((isContinuedOverdue || isActiveOverdue) && plannedSeconds > 0) {
        overdueSeconds = math.max(0, cachedFocused - plannedSeconds);
      } else if (todo.overdueTime > 0) {
        overdueSeconds = todo.overdueTime * 60; // convert minutes to seconds
      }

      if (overdueSeconds > 0) {
        final formattedTime = _formatOverdueTime(overdueSeconds);
        return Text(
          'Overdue: $formattedTime',
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }

    // For completed tasks that are underdue, show percentage
    if (todo.completed && plannedSeconds > 0) {
      final percentage = ((cachedFocused / plannedSeconds) * 100).round();
      if (percentage < 100) {
        return Text(
          'Underdue task $percentage%',
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }
    // If task is completed and has neither overdue nor underdue label (percentage >=100 means already handled as overdue earlier), show green Completed
    if (todo.completed) {
      return const Text(
        'Completed',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatOverdueTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }
}
