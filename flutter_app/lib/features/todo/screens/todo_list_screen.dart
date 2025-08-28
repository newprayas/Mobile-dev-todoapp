import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../models/todo.dart';
import '../providers/todos_provider.dart';
import '../widgets/todo_list_app_bar.dart';
import '../widgets/task_list.dart';
import '../widgets/inline_task_input.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/widgets/mini_timer_bar.dart';
import '../../auth/providers/auth_provider.dart';

/// The new, slim TodoListScreen that acts as a controller.
/// It builds the main page layout and composes the TodoListAppBar and content.
class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = min(screenWidth * 0.95, 520.0);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: TodoListAppBar(),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: _TodoListContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The main content widget that orchestrates fetching data and composing child widgets.
class _TodoListContent extends ConsumerStatefulWidget {
  const _TodoListContent();

  @override
  ConsumerState<_TodoListContent> createState() => _TodoListContentState();
}

class _TodoListContentState extends ConsumerState<_TodoListContent> {
  Future<void> _addTodo(String taskName, int hours, int minutes) async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint(
        'DEBUG: _addTodo attempting to add task: "$taskName" with duration $hours:$minutes',
      );
    }

    try {
      await ref.read(todosProvider.notifier).addTodo(taskName, hours, minutes);
      if (!mounted) return;

      if (kDebugMode) {
        debugPrint('DEBUG: _addTodo success');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG: _addTodo failed with error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add task. Please check your connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiServiceProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    final todosAsync = ref.watch(todosProvider);
    final authState = ref.watch(authProvider);

    // Get the dynamic user name
    final userName = authState.hasValue && authState.value!.isAuthenticated
        ? authState.value!.userName
        : 'User';

    final activeTaskName = ref.watch(timerProvider).activeTaskName;
    Todo? activeTodo;
    if (activeTaskName != null && todosAsync.hasValue) {
      for (final todo in todosAsync.value!) {
        if (todo.text == activeTaskName) {
          activeTodo = todo;
          break;
        }
      }
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              'TO-DO APP',
              style: TextStyle(
                color: AppColors.brightYellow,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              'Welcome, $userName!',
              style: const TextStyle(color: AppColors.lightGray, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            // Inline task input form
            InlineTaskInput(onAddTask: _addTodo),
            const SizedBox(height: 18),
            Expanded(
              child: todosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $err'),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(todosProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (todos) => TaskList(
                  todos: todos,
                  api: api,
                  notificationService: notificationService,
                  onPlay: (id) =>
                      _handleTaskCompletion(int.parse(id), wasOverdue: false),
                  onDelete: (id) => _handleTaskDeletion(int.parse(id)),
                  onToggle: (id) => _handleTaskToggle(int.parse(id)),
                ),
              ),
            ),
          ],
        ),
        if (MediaQuery.of(context).viewInsets.bottom == 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniTimerBar(
              api: api,
              notificationService: notificationService,
              activeTodo: activeTodo,
              onComplete: (id) => _handleTaskCompletion(id),
            ),
          ),
      ],
    );
  }

  Future<void> _handleTaskCompletion(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    if (!mounted) return;
    try {
      if (wasOverdue) {
        await ref
            .read(todosProvider.notifier)
            .toggleTodoWithOverdue(
              id,
              wasOverdue: wasOverdue,
              overdueTime: overdueTime,
            );
      } else {
        await ref.read(todosProvider.notifier).toggleTodo(id);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete task. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleTaskDeletion(int id) async {
    if (!mounted) return;
    try {
      await ref.read(todosProvider.notifier).deleteTodo(id);
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete task. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleTaskToggle(int id) async {
    if (!mounted) return;
    try {
      await ref.read(todosProvider.notifier).toggleTodo(id);
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to toggle task. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
