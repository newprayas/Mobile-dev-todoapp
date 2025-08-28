import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../models/todo.dart';
import '../widgets/task_card.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/pomodoro_router.dart';

/// Widget responsible for building the ListView of tasks.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (incompleteTodos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: incompleteTodos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildTaskCard(incompleteTodos[index]),
            ),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Text(
                'No active tasks.\nAdd one above to get started!',
                style: TextStyle(color: AppColors.lightGray, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        if (completedTodos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _completedExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _completedExpanded = expanded;
                });
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                'Completed (${completedTodos.length})',
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskCard(Todo todo) {
    final timer = ref.watch(timerProvider);
    final isActive = timer.activeTaskName == todo.text;

    return TaskCard(
      todo: todo,
      isActive: isActive,
      onPlay: (t) => _handlePlayTask(t),
      onDelete: () => widget.onDelete(todo.id.toString()),
      onToggle: () => widget.onToggle(todo.id.toString()),
    );
  }

  Future<void> _handlePlayTask(Todo todo) async {
    final timerState = ref.watch(timerProvider);
    final isThisTaskActive = timerState.activeTaskName == todo.text;
    final isAnyTimerActive = timerState.isTimerActive;

    if (kDebugMode) {
      debugPrint(
        'PLAY_BUTTON: Task=${todo.text}, isThisTaskActive=$isThisTaskActive, isAnyTimerActive=$isAnyTimerActive',
      );
    }

    if (isThisTaskActive) {
      // This task's timer is active - toggle pause/resume
      ref.read(timerProvider.notifier).toggleRunning();
      return;
    }

    if (isAnyTimerActive && timerState.activeTaskName != null) {
      // Another task's timer is active - show switch confirmation
      final shouldSwitch = await AppDialogs.showSwitchTaskDialog(
        context: context,
        currentTaskName: timerState.activeTaskName!,
        newTaskName: todo.text,
      );

      if (shouldSwitch != true || !mounted) return;

      // *** CRITICAL BUG FIX: Save progress before switching tasks ***
      // Find the current active todo by matching task name
      final currentActiveTodo = widget.todos.firstWhere(
        (t) => t.text == timerState.activeTaskName,
        orElse: () => Todo(
          id: 0,
          userId: '',
          text: timerState.activeTaskName!,
          completed: false,
          durationHours: 0,
          durationMinutes: 0,
          focusedTime: 0,
          wasOverdue: 0,
          overdueTime: 0,
        ),
      );

      // Save progress for the current active task
      final notifier = ref.read(timerProvider.notifier);
      if (currentActiveTodo.id > 0) {
        try {
          final success = await notifier.stopAndSaveProgress(
            currentActiveTodo.id,
          );
          if (kDebugMode) {
            debugPrint(
              'TASK_SWITCH: Progress save ${success ? 'successful' : 'failed'} for ${currentActiveTodo.text}',
            );
          }

          // Show feedback to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Progress saved for "${currentActiveTodo.text}" ✓'
                      : 'Failed to save progress for "${currentActiveTodo.text}"',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: success
                    ? Colors.green[700]
                    : Colors.orange[700],
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('TASK_SWITCH: Error saving progress: $e');
          }
          // Still clear the session even if save fails
          notifier.clearPreserveProgress();
        }
      } else {
        // No valid todo ID, just clear
        notifier.clearPreserveProgress();
      }
    }

    // Pre-initialize provider with this task's planned details for setup UI
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);
    final defaultFocus = 25 * 60;
    final defaultBreak = 5 * 60;
    // Calculate cycles = ceil(planned / focus) if planned > 0
    final cycles = plannedSeconds > 0
        ? (plannedSeconds / defaultFocus).ceil().clamp(1, 1000)
        : 4;
    final notifier = ref.read(timerProvider.notifier);
    notifier.resetForSetupWithTask(
      taskName: todo.text,
      focusDuration: defaultFocus,
      breakDuration: defaultBreak,
      totalCycles: cycles,
      plannedDuration: plannedSeconds,
    );

    // Show Pomodoro timer sheet using the router
    await PomodoroRouter.showPomodoroSheet(
      context,
      widget.api,
      todo,
      widget.notificationService,
      ({bool wasOverdue = false, int overdueTime = 0}) async {
        if (!mounted) return;

        try {
          // Call the appropriate completion handler
          widget.onPlay(
            todo.id.toString(),
          ); // This will trigger completion logic in parent
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to complete task. Please try again.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
    );
  }
}
