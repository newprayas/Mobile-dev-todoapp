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
    return Opacity(
      opacity: todo.completed ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.midGray,
                  borderRadius: BorderRadius.circular(12),
                  // Use a consistent single gray appearance; remove colored borders/shadows
                  border: null,
                  boxShadow: null,
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 64,
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
                            height: 64,
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
                                // Place the editable title and a possible red-dot indicator in a row
                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: editController,
                                        style: TextStyle(
                                          color: AppColors.lightGray,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          decoration: todo.completed
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
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
                                    // show red-dot emoji if user chose to continue on an overdue task
                                    if (TimerService.instance
                                        .hasUserContinuedOverdue(todo.text))
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
                        const SizedBox(height: 8),
                        // Completed / Underdue / Overdue status label (shown only for completed tasks)
                        Builder(
                          builder: (sctx) {
                            // Only show when the server provided a planned duration
                            if (!todo.completed) return const SizedBox.shrink();
                            final plannedSecondsLocal = plannedSeconds;
                            if (plannedSecondsLocal <= 0) {
                              return const SizedBox.shrink();
                            }
                            // Decide state: overdue > 0 => overdue; else underdue if focused < planned; else completed
                            final isOverdueNow = todo.overdueTime > 0;
                            final focused = todo.focusedTime;
                            String labelText;
                            Color labelColor;
                            if (isOverdueNow) {
                              labelText = 'Overdue: +${todo.overdueTime}m';
                              labelColor = Colors.redAccent;
                            } else if (focused < plannedSecondsLocal) {
                              labelText = 'Underdue task';
                              labelColor = AppColors.brightYellow;
                            } else {
                              labelText = 'Completed task';
                              labelColor = AppColors.priorityLow; // green-ish
                            }
                            if (kDebugMode) {
                              debugPrint(
                                'TASK_STATUS: id=${todo.id} label=$labelText focused=$focused planned=$plannedSecondsLocal overdue=${todo.overdueTime}',
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                labelText,
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                        Row(
                          children: [
                            GestureDetector(
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
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Hours',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: tmpMins,
                                            keyboardType: TextInputType.number,
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
                                  final h = int.tryParse(tmpHours.text) ?? 0;
                                  final m = int.tryParse(tmpMins.text) ?? 0;
                                  await onUpdateDuration(h, m);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
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
                                    // Inline overdue badge only for active (not completed) tasks
                                    if (!todo.completed &&
                                        isOverdue &&
                                        todo.overdueTime > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(+${todo.overdueTime}m overdue)',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Hide play button for completed tasks
                            if (!todo.completed)
                              Hero(
                                tag: 'play_${todo.id}',
                                child: Material(
                                  color: Colors.transparent,
                                  child: IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    color: AppColors.lightGray,
                                    onPressed: () async {
                                      if (kDebugMode) {
                                        debugPrint(
                                          'Play tapped for ${todo.id}',
                                        );
                                      }
                                      await onPlay(todo);
                                    },
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: Icon(
                                todo.completed
                                    ? Icons.undo
                                    : Icons.check_circle_outline,
                              ),
                              color: AppColors.lightGray,
                              onPressed: () async {
                                if (kDebugMode) {
                                  debugPrint('Toggle tapped for ${todo.id}');
                                }
                                await onToggle();
                              },
                              tooltip: todo.completed
                                  ? 'Mark incomplete'
                                  : 'Mark completed',
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.lightGray,
                              onPressed: () async {
                                if (kDebugMode) {
                                  debugPrint('Delete tapped for ${todo.id}');
                                }
                                await onDelete();
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                        // Live progress bar was moved below the card for full visibility
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Progress bar below the task card (full-width and easy to see)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: SizedBox(
              height: 18,
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
}
