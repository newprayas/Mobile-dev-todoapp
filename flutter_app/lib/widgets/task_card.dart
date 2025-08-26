import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../models/todo.dart';
import '../theme/app_colors.dart';
import 'progress_bar.dart';
import '../services/timer_service.dart';

typedef PlayCallback = Future<void> Function(Todo todo);

class TaskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final totalMins = (todo.durationHours * 60) + todo.durationMinutes;
    final progress = totalMins == 0
        ? 0.0
        : (todo.focusedTime / totalMins).clamp(0.0, 1.0);
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);
    // Use TimerService cache when a live focused value exists for immediate UI sync
    final cachedFocused =
        TimerService.instance.getFocusedTime(todo.text) ?? todo.focusedTime;
    final isOverdue = plannedSeconds > 0 && todo.focusedTime >= plannedSeconds;
    final editController = TextEditingController(text: todo.text);

    if (kDebugMode) {
      debugPrint(
        'TASK_CARD: id=${todo.id} cachedFocused=$cachedFocused planned=$plannedSeconds isOverdue=$isOverdue',
      );
    }
    return AnimatedBuilder(
      animation: TimerService.instance,
      builder: (context, _) {
        final isContinuedOverdue = TimerService.instance
            .hasUserContinuedOverdue(todo.text);
        return Opacity(
          opacity: todo.completed ? 0.5 : 1.0,
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
                          ? (todo.focusedTime / math.max(1, totalMins))
                          : progress));
                  const fillColor = Colors.transparent; // Remove yellow hue
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.midGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Base background - allow height to expand to fit content (status label)
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
                                // stretch to parent height so overlay covers the whole card
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
                            // Title row with editable text and optional red-dot
                            Container(
                              decoration: isActive
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
                                            controller: editController,
                                            style: TextStyle(
                                              color: AppColors.lightGray,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              fontStyle: todo.completed
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              filled: false,
                                              border: InputBorder.none,
                                            ),
                                            onSubmitted: (v) async {
                                              final newText = v.trim();
                                              if (newText.isEmpty) return;
                                              await onUpdateText(newText);
                                            },
                                          ),
                                        ),
                                        if (!todo.completed &&
                                            TimerService.instance
                                                .hasUserContinuedOverdue(
                                                  todo.text,
                                                ))
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
                            // Small gap then status label directly under the title (global rule)
                            const SizedBox(height: 4),
                            // Show overdue/underdue tag below the task name for any task that has one
                            Builder(
                              builder: (ctx) {
                                final isActiveOverdue =
                                    (plannedSeconds > 0 &&
                                    cachedFocused >= plannedSeconds);
                                final showTag =
                                    isActiveOverdue ||
                                    isContinuedOverdue ||
                                    (todo.overdueTime > 0) ||
                                    (todo.completed &&
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
                                    todo,
                                    cachedFocused,
                                    plannedSeconds,
                                    isContinuedOverdue,
                                  ),
                                );
                              },
                            ),
                            // Row with duration (wrapped in Flexible to prevent overflow) and controls
                            Row(
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final tmpHours = TextEditingController(
                                        text: '${todo.durationHours}',
                                      );
                                      final tmpMins = TextEditingController(
                                        text: '${todo.durationMinutes}',
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
                                                  decoration:
                                                      const InputDecoration(
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
                                                  decoration:
                                                      const InputDecoration(
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
                                        final h =
                                            int.tryParse(tmpHours.text) ?? 0;
                                        final m =
                                            int.tryParse(tmpMins.text) ?? 0;
                                        await onUpdateDuration(h, m);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.timer,
                                            size: 16,
                                            color: AppColors.lightGray,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${todo.durationHours}h ${todo.durationMinutes}m',
                                            style: const TextStyle(
                                              color: AppColors.lightGray,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Controls: show dynamic Play/Pause when this task is the active one
                                if (!todo.completed)
                                  Builder(
                                    builder: (ctx) {
                                      final svc = TimerService.instance;
                                      final isSvcActive =
                                          svc.activeTaskName == todo.text;
                                      // If service has this task active, show pause/play that toggles running
                                      if (isSvcActive) {
                                        final isRunning = svc.isRunning;
                                        return Hero(
                                          tag: 'play_${todo.id}',
                                          child: Material(
                                            color: Colors.transparent,
                                            child: IconButton(
                                              icon: Icon(
                                                isRunning
                                                    ? Icons.pause
                                                    : Icons.play_arrow,
                                              ),
                                              color: AppColors.lightGray,
                                              onPressed: () {
                                                if (kDebugMode) {
                                                  debugPrint(
                                                    'TASK_CARD: toggle running for ${todo.id} (svcActive=$isSvcActive isRunning=$isRunning)',
                                                  );
                                                }
                                                // Toggle running on the central TimerService so UI stays in sync
                                                try {
                                                  svc.toggleRunning();
                                                } catch (_) {}
                                              },
                                            ),
                                          ),
                                        );
                                      }

                                      // Otherwise, this task isn't active in the service -> open Pomodoro sheet
                                      return Hero(
                                        tag: 'play_${todo.id}',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: IconButton(
                                            icon: const Icon(Icons.play_arrow),
                                            color: AppColors.lightGray,
                                            onPressed: () async {
                                              if (kDebugMode) {
                                                debugPrint(
                                                  'Play tapped for ${todo.id} (open sheet)',
                                                );
                                              }
                                              await onPlay(todo);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: Icon(
                                    todo.completed
                                        ? Icons.undo
                                        : Icons.check_circle_outline,
                                  ),
                                  color: AppColors.lightGray,
                                  onPressed: () async {
                                    if (kDebugMode) {
                                      debugPrint(
                                        'Toggle tapped for ${todo.id}',
                                      );
                                    }
                                    // When marking completed, also clear the minibar if this task was active
                                    try {
                                      if (todo.completed == false &&
                                          TimerService
                                                  .instance
                                                  .activeTaskName ==
                                              todo.text) {
                                        TimerService.instance.clear();
                                      }
                                    } catch (_) {}
                                    await onToggle();
                                  },
                                  tooltip: todo.completed
                                      ? 'Mark incomplete'
                                      : 'Mark completed',
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: AppColors.lightGray,
                                  onPressed: () async {
                                    if (kDebugMode) {
                                      debugPrint(
                                        'Delete tapped for ${todo.id}',
                                      );
                                    }
                                    await onDelete();
                                  },
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                            // Live progress bar was moved below the card for full visibility
                            const SizedBox(height: 4),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Progress bar below the task card (full-width and easy to see)
              // Do not show progress bars for completed tasks or tasks the user continued while overdue
              if (!todo.completed && !isContinuedOverdue)
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
      },
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
