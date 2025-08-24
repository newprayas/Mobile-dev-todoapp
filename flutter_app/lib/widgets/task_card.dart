import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../models/todo.dart';
import '../theme/app_colors.dart';

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
    final isOverdue = plannedSeconds > 0 && todo.focusedTime >= plannedSeconds;
    final editController = TextEditingController(text: todo.text);

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
              final fillColor = isOverdue ? Colors.red : AppColors.brightYellow;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.midGray,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive
                      ? Border.all(
                          color: AppColors.brightYellow.withOpacity(0.9),
                          width: 2,
                        )
                      : (isOverdue
                            ? Border.all(
                                color: AppColors.priorityHigh,
                                width: 2,
                              )
                            : null),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.brightYellow.withOpacity(0.14),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : (isOverdue
                            ? [
                                BoxShadow(
                                  color: AppColors.priorityHigh.withOpacity(
                                    0.12,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
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
                        Focus(
                          child: Builder(
                            builder: (ctx) {
                              final hasFocus = Focus.of(ctx).hasFocus;
                              return TextField(
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  filled: true,
                                  fillColor: hasFocus
                                      ? AppColors.inputFill
                                      : Colors.transparent,
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (v) async {
                                  final newText = v.trim();
                                  if (newText.isEmpty) return;
                                  await onUpdateText(newText);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                    if (isOverdue && todo.overdueTime > 0) ...[
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
                            Hero(
                              tag: 'play_${todo.id}',
                              child: Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  color: AppColors.lightGray,
                                  onPressed: () async {
                                    if (kDebugMode) {
                                      debugPrint('Play tapped for ${todo.id}');
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
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
