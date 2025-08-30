import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../models/todo.dart';
import '../widgets/task_card.dart';
import '../providers/todos_provider.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/pomodoro_router.dart';

/// Widget responsible for building the scrollable list of tasks.
/// Handles separating completed and incomplete tasks and the "Completed" ExpansionTile.
class TaskList extends ConsumerStatefulWidget {
  final List<Todo> todos;
  final ApiService api;
  final NotificationService notificationService;
  final Function(String id) onPlay;
  final Function(String id) onDelete;
  final Function(String id) onToggle;

  const TaskList({
    required this.todos,
    required this.api,
    required this.notificationService,
    required this.onPlay,
    required this.onDelete,
    required this.onToggle,
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

    // Use a SingleChildScrollView to prevent layout overflows.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incompleteTodos.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: incompleteTodos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildTaskCard(incompleteTodos[index]),
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
            const SizedBox(height: 12),
            Container(
              height: 2,
              color: AppColors.brightYellow,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            const SizedBox(height: 12),
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
                },
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.lightGray,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Completed (${completedTodos.length})',
                      style: const TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  _completedExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.lightGray,
                ),
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completedTodos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildTaskCard(completedTodos[index]),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleClearCompleted,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withAlpha(25),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completed tasks cleared ✓',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
    final timerState = ref.watch(timerProvider);
    final isThisTaskActive = timerState.activeTaskId == todo.id;
    final isAnyTimerActive = timerState.isTimerActive;

    if (kDebugMode) {
      debugPrint(
        'PLAY_BUTTON: Task=${todo.text}, isThisTaskActive=$isThisTaskActive, isAnyTimerActive=$isAnyTimerActive',
      );
    }

    if (isThisTaskActive) {
      ref.read(timerProvider.notifier).toggleRunning();
      return;
    }

    if (isAnyTimerActive && timerState.activeTaskId != null) {
      final notifier = ref.read(timerProvider.notifier);
      final wasRunning = timerState.isRunning;
      if (wasRunning) {
        notifier.pauseTask();
      }

      // Find the current active task name for the dialog
      final todosAsync = ref.watch(todosProvider);
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

      final currentActiveTodo = widget.todos.firstWhere(
        (t) => t.id == timerState.activeTaskId,
        orElse: () => Todo(
          id: timerState.activeTaskId ?? 0,
          userId: '',
          text: 'Unknown Task',
          completed: false,
          durationHours: 0,
          durationMinutes: 0,
          focusedTime: 0,
          wasOverdue: 0,
          overdueTime: 0,
        ),
      );

      if (currentActiveTodo.id > 0) {
        await notifier.stopAndSaveProgress(currentActiveTodo.id);
      } else {
        notifier.clearPreserveProgress();
      }
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
