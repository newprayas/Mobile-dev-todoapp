// Replace entire file: lib/features/todo/widgets/task_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../pomodoro/pomodoro_router.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../models/todo.dart';
import '../providers/todos_provider.dart';
import 'task_card.dart';

class TaskList extends ConsumerStatefulWidget {
  final List<Todo> todos;
  final ApiService api;
  final NotificationService notificationService;
  final void Function(String) onPlay;
  final void Function(String) onDelete;
  final void Function(String) onToggle;
  final void Function(bool) onExpansionChanged;

  const TaskList({
    super.key,
    required this.todos,
    required this.api,
    required this.notificationService,
    required this.onPlay,
    required this.onDelete,
    required this.onToggle,
    required this.onExpansionChanged,
  });

  @override
  ConsumerState<TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<TaskList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.todos.length,
      itemBuilder: (context, index) {
        final todo = widget.todos[index];

        return TaskCard(
          todo: todo,
          onPlay: _handlePlayTask,
          onDelete: () async => widget.onDelete(todo.id.toString()),
          onToggle: () async => widget.onToggle(todo.id.toString()),
          isActive: _isTaskActive(todo),
        );
      },
    );
  }

  bool _isTaskActive(Todo todo) {
    final timerState = ref.read(timerProvider);
    return timerState.activeTaskId == todo.id && timerState.isRunning;
  }

  Future<void> _handlePlayTask(Todo todo) async {
    final timerState = ref.read(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    // Check if this task is already being timed
    if (timerState.activeTaskId == todo.id && timerState.isRunning) {
      // Task is already running, do nothing
      return;
    }

    // If another task is running, stop it first
    if (timerState.activeTaskId != null && timerState.isRunning) {
      await timerNotifier.stopAndSaveProgress(timerState.activeTaskId!);
    }

    // Show Pomodoro screen and wait for result
    final result = await PomodoroRouter.showPomodoroSheet(
      context,
      widget.api,
      todo,
      widget.notificationService,
      ({bool wasOverdue = false, int overdueTime = 0}) async {
        // This callback will be called when task is completed
        await _handleTaskCompletion(todo, wasOverdue: wasOverdue, overdueTime: overdueTime);
      },
    );

    // Handle the result from Pomodoro screen
    if (result == 'overdue_sessions_complete') {
      // Show the overdue completion dialog
      await _showOverdueSessionCompletionPrompt(todo);
    }
  }

  Future<void> _handleTaskCompletion(Todo todo, {bool wasOverdue = false, int overdueTime = 0}) async {
    try {
      // Update the focused time first
      final currentFocusedTime = ref.read(timerProvider).focusedTimeCache[todo.id] ?? 0;
      await widget.api.updateFocusTime(todo.id, currentFocusedTime);

      // Mark task as completed with overdue info
      await widget.api.toggleTodoWithOverdue(
        todo.id,
        wasOverdue: wasOverdue,
        overdueTime: overdueTime,
      );

      // Refresh the todos list
      ref.invalidate(todosProvider);

      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "${todo.text}" completed!'),
            backgroundColor: AppColors.priorityLow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete task. Please try again.'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    }
  }

  Future<void> _showOverdueSessionCompletionPrompt(Todo todo) async {
    final choice = await AppDialogs.showOverdueSessionCompleteDialog(context);

    if (choice == null) return; // Dialog was dismissed

    if (choice) {
      // User chose "Mark Complete"
      await _handleTaskCompletion(todo, wasOverdue: true, overdueTime: ref.read(timerProvider).focusedTimeCache[todo.id] ?? 0);
    } else {
      // User chose "Continue Working"
      // The timer will continue running, no action needed here
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Continuing work session...'),
            backgroundColor: AppColors.priorityMedium,
          ),
        );
      }
    }
  }
}
