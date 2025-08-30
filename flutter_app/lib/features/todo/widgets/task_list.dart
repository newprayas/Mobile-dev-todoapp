// In file: flutter_app/lib/features/todo/widgets/task_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../models/todo.dart';
import './task_card.dart';
import '../providers/todos_provider.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/pomodoro_router.dart';
import '../../../core/widgets/progress_bar.dart';

class TaskList extends ConsumerStatefulWidget {
  final List<Todo> todos;
  final ApiService api;
  final NotificationService notificationService;
  final Function(String id) onPlay;
  final Function(String id) onDelete;
  final Function(String id) onToggle;
  final ValueChanged<bool>? onExpansionChanged; // New callback

  const TaskList({
    required this.todos,
    required this.api,
    required this.notificationService,
    required this.onPlay,
    required this.onDelete,
    required this.onToggle,
    this.onExpansionChanged, // New callback
    super.key,
  });

  @override
  ConsumerState<TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<TaskList> {
  bool _completedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final incompleteTodos = widget.todos.where((t) => !t.completed).toList();
    final completedTodos = widget.todos.where((t) => t.completed).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incompleteTodos.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: incompleteTodos.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 8), // Adjusted spacing
              itemBuilder: (context, index) {
                final todo = incompleteTodos[index];
                // Wrap TaskCard and its status indicator in a Column
                return Column(
                  children: [
                    _buildTaskCard(todo),
                    const SizedBox(height: 8),
                    _TaskStatusIndicator(todo: todo),
                  ],
                );
              },
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Text(
                  'No active tasks.\nAdd one above to get started!',
                  style: TextStyle(color: AppColors.lightGray, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (completedTodos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(
              color: AppColors.brightYellow,
              thickness: 1.5,
              height: 48,
              indent: 20,
              endIndent: 20,
            ),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _completedExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _completedExpanded = expanded;
                  });
                  // Call the callback to notify the parent screen
                  widget.onExpansionChanged?.call(expanded);
                },
                controlAffinity: ListTileControlAffinity.leading,
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Row(
                  children: [
                    const Text(
                      'Completed',
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _handleClearCompleted,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.midGray,
                        foregroundColor: AppColors.lightGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: const SizedBox.shrink(),
                leading: Icon(
                  _completedExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: AppColors.lightGray,
                ),
                children: [
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completedTodos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildTaskCard(completedTodos[index]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(Todo todo) {
    final timer = ref.watch(timerProvider);
    final isActive = timer.activeTaskId == todo.id;

    return TaskCard(
      todo: todo,
      isActive: isActive,
      onPlay: (t) => _handlePlayTask(t),
      onDelete: () => widget.onDelete(todo.id.toString()),
      onToggle: () => widget.onToggle(todo.id.toString()),
    );
  }

  Future<void> _handleClearCompleted() async {
    final shouldClear = await AppDialogs.showClearCompletedDialog(
      context: context,
    );
    if (shouldClear == true && mounted) {
      try {
        await ref.read(todosProvider.notifier).clearCompleted();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to clear completed tasks'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePlayTask(Todo todo) async {
    final timerState = ref.read(timerProvider);
    final isThisTaskActive = timerState.activeTaskId == todo.id;
    final isAnyTimerActive = timerState.isTimerActive;

    if (kDebugMode) {
      debugPrint(
        'PLAY_BUTTON: Task=${todo.text}, isThisTaskActive=$isThisTaskActive, isAnyTimerActive=$isAnyTimerActive',
      );
    }

    if (isThisTaskActive) {
      // If the timer is active for this task, just show the Pomodoro screen
      await PomodoroRouter.showPomodoroSheet(
        context,
        widget.api,
        todo,
        widget.notificationService,
        ({bool wasOverdue = false, int overdueTime = 0}) async {
          if (!mounted) return;
          widget.onPlay(todo.id.toString());
        },
      );
      return;
    }

    if (isAnyTimerActive && timerState.activeTaskId != null) {
      final notifier = ref.read(timerProvider.notifier);
      final wasRunning = timerState.isRunning;
      if (wasRunning) {
        notifier.pauseTask();
      }

      final todosAsync = ref.read(todosProvider);
      String? currentTaskName;
      if (todosAsync.hasValue) {
        for (final t in todosAsync.value!) {
          if (t.id == timerState.activeTaskId) {
            currentTaskName = t.text;
            break;
          }
        }
      }

      final shouldSwitch = await AppDialogs.showSwitchTaskDialog(
        context: context,
        currentTaskName: currentTaskName ?? 'Unknown Task',
        newTaskName: todo.text,
      );

      if (shouldSwitch != true) {
        if (wasRunning) {
          notifier.resumeTask();
        }
        return;
      }
      if (!mounted) return;
      await notifier.stopAndSaveProgress(timerState.activeTaskId!);
    }

    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);
    final defaultFocus = 25 * 60;
    final defaultBreak = 5 * 60;
    final cycles = plannedSeconds > 0
        ? (plannedSeconds / defaultFocus).ceil().clamp(1, 1000)
        : 4;
    final notifier = ref.read(timerProvider.notifier);
    notifier.resetForSetupWithTask(
      taskId: todo.id,
      focusDuration: defaultFocus,
      breakDuration: defaultBreak,
      totalCycles: cycles,
      plannedDuration: plannedSeconds,
      isPermanentlyOverdue: todo.wasOverdue == 1,
    );

    await PomodoroRouter.showPomodoroSheet(
      context,
      widget.api,
      todo,
      widget.notificationService,
      ({bool wasOverdue = false, int overdueTime = 0}) async {
        if (!mounted) return;
        widget.onPlay(todo.id.toString());
      },
    );
  }
}

class _TaskStatusIndicator extends ConsumerWidget {
  final Todo todo;
  const _TaskStatusIndicator({required this.todo});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final focusedSeconds =
        timerState.focusedTimeCache[todo.id] ?? todo.focusedTime;
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);

    // This indicator should only be visible for incomplete tasks that are NOT permanently overdue
    if (todo.completed || todo.wasOverdue == 1) {
      return const SizedBox.shrink();
    }

    final isActivelyOverdue =
        plannedSeconds > 0 && focusedSeconds > plannedSeconds;

    if (isActivelyOverdue) {
      final overdueSeconds = focusedSeconds - plannedSeconds;
      return Container(
        height: 16, // Match the progress bar height
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          'Overdue: ${_formatOverdueDuration(overdueSeconds)}',
          style: const TextStyle(
            color: AppColors.priorityHigh,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return SizedBox(
        height: 16, // Thicker progress bar
        child: ProgressBar(
          focusedSeconds: focusedSeconds,
          plannedSeconds: plannedSeconds,
          barHeight: 16,
        ),
      );
    }
  }
}
