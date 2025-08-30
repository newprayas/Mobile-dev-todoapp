import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/widgets/mini_timer_bar.dart';
import '../models/todo.dart';
import '../providers/todos_provider.dart';
import '../widgets/inline_task_input.dart';
import '../widgets/task_list.dart';

class TodoListScreen extends ConsumerStatefulWidget {
  const TodoListScreen({super.key});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  // Logic from the old _TodoListContent is now here
  Future<void> _addTodo(String taskName, int hours, int minutes) async {
    if (!mounted) return;

    try {
      await ref.read(todosProvider.notifier).addTodo(taskName, hours, minutes);
    } catch (e) {
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

  void _showOverduePrompt(BuildContext context, Todo todo) async {
    final timerNotifier = ref.read(timerProvider.notifier);
    timerNotifier.markOverduePromptShown(todo.id);

    final wasRunning = ref.read(timerProvider).isRunning;
    if (wasRunning) timerNotifier.pauseTask();

    final result = await AppDialogs.showOverdueDialog(
      context: context,
      taskName: todo.text,
    );

    if (!mounted) return;

    final liveFocusedTime = timerNotifier.getFocusedTime(todo.id);

    if (result == true) {
      await ref
          .read(todosProvider.notifier)
          .toggleTodo(todo.id, liveFocusedTime: liveFocusedTime);
      timerNotifier.clear();
    } else if (result == false) {
      await timerNotifier.stopAndSaveProgress(todo.id);
      final plannedTime =
          (todo.durationHours * 3600) + (todo.durationMinutes * 60);
      final overdueTime = (liveFocusedTime - plannedTime)
          .clamp(0, double.infinity)
          .toInt();
      ref
          .read(todosProvider.notifier)
          .markTaskPermanentlyOverdue(todo.id, overdueTime: overdueTime);
    } else {
      if (wasRunning) timerNotifier.resumeTask();
    }
  }

  Future<void> _handleTaskCompletion(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    if (!mounted) return;
    final timerState = ref.read(timerProvider);
    final currentTodo = ref
        .read(todosProvider)
        .value
        ?.firstWhere((t) => t.id == id);

    if (currentTodo != null &&
        timerState.activeTaskId == currentTodo.id &&
        timerState.isTimerActive) {
      await ref.read(timerProvider.notifier).stopAndSaveProgress(id);
    }
    try {
      if (wasOverdue) {
        await ref
            .read(todosProvider.notifier)
            .toggleTodoWithOverdue(
              id,
              wasOverdue: true,
              overdueTime: overdueTime,
            );
      } else {
        await ref.read(todosProvider.notifier).toggleTodo(id);
      }
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
  }

  Future<void> _handleTaskDeletion(int id) async {
    if (!mounted) return;
    final timerState = ref.read(timerProvider);
    final currentTodo = ref
        .read(todosProvider)
        .value
        ?.firstWhere((t) => t.id == id);

    if (currentTodo == null) return;
    final shouldDelete = await AppDialogs.showDeleteTaskDialog(
      context: context,
      taskName: currentTodo.text,
    );
    if (shouldDelete != true) return;
    if (timerState.activeTaskId == currentTodo.id && timerState.isTimerActive) {
      ref.read(timerProvider.notifier).clear();
    }
    try {
      await ref.read(todosProvider.notifier).deleteTodo(id);
    } catch (e) {
      if (mounted) {
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
    final timerState = ref.read(timerProvider);
    final currentTodo = ref
        .read(todosProvider)
        .value
        ?.firstWhere((t) => t.id == id);

    if (currentTodo == null) return;
    if (timerState.activeTaskId == currentTodo.id &&
        timerState.isTimerActive &&
        !currentTodo.completed) {
      await ref.read(timerProvider.notifier).stopAndSaveProgress(id);
    }
    final liveFocusedTime =
        timerState.focusedTimeCache[id] ?? currentTodo.focusedTime;
    try {
      await ref
          .read(todosProvider.notifier)
          .toggleTodo(id, liveFocusedTime: liveFocusedTime);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to toggle task. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final shouldLogout = await AppDialogs.showSignOutDialog(context: context);
    if (shouldLogout == true && mounted) {
      try {
        await ref.read(authProvider.notifier).signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sign out. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = min(screenWidth * 0.95, 520.0);

    final api = ref.watch(apiServiceProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    final todosAsync = ref.watch(todosProvider);
    final authState = ref.watch(authProvider);
    final userName = authState.hasValue && authState.value!.isAuthenticated
        ? authState.value!.userName
        : 'User';
    final activeTaskId = ref.watch(timerProvider).activeTaskId;
    Todo? activeTodo;
    if (activeTaskId != null && todosAsync.hasValue) {
      activeTodo = todosAsync.value?.firstWhere(
        (todo) => todo.id == activeTaskId,
        orElse: () => null as dynamic,
      );
    }

    ref.listen<TimerState>(timerProvider, (previous, next) {
      final overdueTaskId = next.overdueCrossedTaskId;
      if (overdueTaskId != null &&
          !next.overduePromptShown.contains(overdueTaskId)) {
        final overdueTodo = todosAsync.value?.firstWhere(
          (todo) => todo.id == overdueTaskId,
          orElse: () => null as dynamic,
        );
        if (overdueTodo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showOverduePrompt(context, overdueTodo);
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxCardWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Stack(
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
                              style: const TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),
                            InlineTaskInput(onAddTask: _addTodo),
                            const SizedBox(height: 18),
                            Expanded(
                              child: todosAsync.when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (err, stack) => Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Error: $err'),
                                      ElevatedButton(
                                        onPressed: () =>
                                            ref.invalidate(todosProvider),
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                                data: (todos) => TaskList(
                                  todos: todos,
                                  api: api,
                                  notificationService: notificationService,
                                  onPlay: (id) => _handleTaskCompletion(
                                    int.parse(id),
                                    wasOverdue: false,
                                  ),
                                  onDelete: (id) =>
                                      _handleTaskDeletion(int.parse(id)),
                                  onToggle: (id) =>
                                      _handleTaskToggle(int.parse(id)),
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
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 24,
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                  color: AppColors.mediumGray,
                  size: 28,
                ),
                tooltip: 'Sign Out',
                onPressed: _handleSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
