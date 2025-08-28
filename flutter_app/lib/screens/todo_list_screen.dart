import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../providers/todos_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/task_card.dart';
import '../widgets/mini_timer_bar.dart';
import '../widgets/inline_task_input.dart';
import '../utils/app_dialogs.dart';
import 'pomodoro_screen.dart';
import 'dart:math';

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = min(screenWidth * 0.95, 520.0);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        title: Text(
          'Todo List',
          style: TextStyle(
            color: AppColors.lightGray,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (authState.hasValue && authState.value!.isAuthenticated) ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        authState.value!.userName,
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        authState.value!.email,
                        style: TextStyle(
                          color: AppColors.lightGray.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.brightYellow.withValues(
                        alpha: 0.2,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: AppColors.brightYellow,
                      ),
                    ),
                    color: AppColors.cardBg,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout,
                              color: AppColors.lightGray,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(color: AppColors.lightGray),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'logout') {
                        final shouldLogout = await AppDialogs.showSignOutDialog(
                          context: context,
                        );

                        if (shouldLogout == true && context.mounted) {
                          try {
                            await ref.read(authProvider.notifier).signOut();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to sign out. Please try again.',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
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
                data: (todos) => _TodoList(
                  todos: todos,
                  api: api,
                  notificationService: notificationService,
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
              onComplete: (id) async {
                if (!mounted) return;
                try {
                  await ref.read(todosProvider.notifier).toggleTodo(id);
                } catch (e) {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to complete task. Please try again.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
            ),
          ),
      ],
    );
  }
}

class _TodoList extends ConsumerStatefulWidget {
  final List<Todo> todos;
  final ApiService api;
  final NotificationService notificationService;

  const _TodoList({
    required this.todos,
    required this.api,
    required this.notificationService,
  });

  @override
  ConsumerState<_TodoList> createState() => _TodoListState();
}

class _TodoListState extends ConsumerState<_TodoList> {
  bool _completedExpanded = false;

  Widget _buildTaskCard(Todo t) {
    final timer = ref.watch(timerProvider);
    final isActive = timer.activeTaskName == t.text;
    return TaskCard(
      todo: t,
      isActive: isActive,
      onPlay: (todo) async {
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

          // Stop current session and switch
          ref.read(timerProvider.notifier).stop();
        }

        // Start new session for this task
        await PomodoroScreen.showAsBottomSheet(
          context,
          widget.api,
          todo,
          widget.notificationService,
          () async {
            if (!mounted) return;
            try {
              await ref.read(todosProvider.notifier).toggleTodo(todo.id);
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
          },
        );
      },
      onDelete: () async {
        final confirm = await AppDialogs.showDeleteTaskDialog(
          context: context,
          taskName: t.text,
        );
        if (confirm == true && mounted) {
          if (kDebugMode) {
            debugPrint('DEBUG: Attempting to delete task with id: ${t.id}');
          }
          try {
            await ref.read(todosProvider.notifier).deleteTodo(t.id);
            if (kDebugMode) {
              debugPrint('DEBUG: Successfully deleted task with id: ${t.id}');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'DEBUG: Failed to delete task with id: ${t.id}, error: $e',
              );
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Failed to delete task. Please check your connection.',
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        }
      },
      onToggle: () async {
        if (!mounted) return;
        try {
          await ref.read(todosProvider.notifier).toggleTodo(t.id);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Failed to toggle task. Please check your connection.',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.todos.isEmpty) {
      return const Center(
        child: Text(
          'No tasks yet. Add one to get started!',
          style: TextStyle(color: AppColors.mediumGray, fontSize: 16),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ...widget.todos
            .where((t) => !t.completed)
            .map((t) => _buildTaskCard(t)),
        if (widget.todos.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(height: 2, color: AppColors.brightYellow),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: _completedExpanded,
              onExpansionChanged: (v) {
                if (mounted) {
                  setState(() => _completedExpanded = v);
                }
              },
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check, color: AppColors.lightGray, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (_completedExpanded)
                    Tooltip(
                      message: 'Clear completed',
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirm =
                              await AppDialogs.showClearCompletedDialog(
                                context: context,
                              );
                          if (confirm == true) {
                            await ref
                                .read(todosProvider.notifier)
                                .clearCompleted();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midGray,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(10),
                          minimumSize: const Size(40, 40),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: AppColors.lightGray,
                        ),
                      ),
                    ),
                ],
              ),
              children: [
                ...widget.todos
                    .where((t) => t.completed)
                    .map((t) => _buildTaskCard(t)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 60), // Space for the MiniTimerBar
      ],
    );
  }
}
