import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../../../core/services/mock_api_service.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/models/timer_state.dart';
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
  bool _isCompletedExpanded = false;

  Future<void> _addTodo(String taskName, int hours, int minutes) async {
    logger.d(
      '[TodoListScreen] Received add task request: "$taskName" (${hours}h ${minutes}m)',
    );
    if (!mounted) {
      logger.w('[TodoListScreen] _addTodo: Widget not mounted, aborting.');
      return;
    }
    try {
      logger.d('[TodoListScreen] Calling todosProvider.notifier.addTodo...');
      await ref.read(todosProvider.notifier).addTodo(taskName, hours, minutes);
      ErrorHandler.showSuccess(context, 'Task added successfully!');
      logger.d(
        '[TodoListScreen] Task added successfully and success message shown.',
      );
    } catch (e, st) {
      logger.e('[TodoListScreen] Error adding task', error: e, stackTrace: st);
      if (mounted) {
        ErrorHandler.showError(context, e);
        logger.d('[TodoListScreen] Error message shown for adding task.');
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
      await ref
          .read(todosProvider.notifier)
          .markTaskPermanentlyOverdue(
            todo.id,
            overdueTime: overdueTime,
          ); // CORRECTED
    } else {
      if (wasRunning) timerNotifier.resumeTask();
    }
  }

  Future<void> _handleTaskCompletion(int id, {bool wasOverdue = false}) async {
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
      await ref.read(todosProvider.notifier).toggleTodo(id);
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
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
      ErrorHandler.showSuccess(context, 'Task deleted successfully!');
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  Future<void> _handleTaskToggle(int id) async {
    if (!mounted) return;

    final todos = ref.read(todosProvider).value ?? [];
    Todo? currentTodo;
    try {
      currentTodo = todos.firstWhere((t) => t.id == id);
    } catch (e) {
      return; // Todo not found
    }

    // --- NEW LOGIC START ---
    // If the task is overdue AND we are about to complete it, show confirmation.
    if (currentTodo.wasOverdue == 1 && !currentTodo.completed) {
      final confirm = await AppDialogs.showConfirmCompleteOverdueTaskDialog(
        context: context,
        taskName: currentTodo.text,
      );
      // If user cancels, abort the operation.
      if (confirm != true) {
        return;
      }
    }
    // --- NEW LOGIC END ---

    final timerState = ref.read(timerProvider);
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
        ErrorHandler.showError(context, e);
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
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      // Guard against build being invoked after dispose (rare but defensive)
      return const SizedBox.shrink();
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = min(screenWidth * 0.95, 520.0);
    final api = ref.watch(apiServiceProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    final todosAsync = ref.watch(todosProvider);
    final authState = ref.watch(authProvider);
    final timerState = ref.watch(timerProvider);
    final userName = authState.hasValue && authState.value!.isAuthenticated
        ? authState.value!.userName
        : 'User';
    final activeTaskId = timerState.activeTaskId;

    Todo? activeTodo;
    if (activeTaskId != null &&
        todosAsync.hasValue &&
        todosAsync.value != null) {
      try {
        activeTodo = todosAsync.value!.firstWhere(
          (todo) => todo.id == activeTaskId,
        );
      } catch (_) {
        activeTodo = null;
      }
    }

    ref.listen<TimerState>(timerProvider, (previous, next) {
      final overdueTaskId = next.overdueCrossedTaskId;
      if (overdueTaskId == null ||
          next.overduePromptShown.contains(overdueTaskId))
        return;
      final todoList = todosAsync.value;
      if (todoList == null) return;
      Todo? overdue;
      try {
        overdue = todoList.firstWhere((t) => t.id == overdueTaskId);
      } catch (_) {
        return;
      }
      // overdue will never be null here because firstWhere either returns or throws
      // Schedule prompt safely after frame with mounted check
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOverduePrompt(context, overdue!);
      });
    });

    final isTimerBarVisible =
        timerState.isTimerActive && timerState.activeTaskId != null;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          'BETAFLOW', // Changed app name
                          style: TextStyle(
                            color: AppColors.brightYellow,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 32,
                        ), // Increased the height for more gap
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
                        const Divider(
                          color: AppColors.brightYellow,
                          thickness: 1.5,
                          height: 48, // Increased from 36
                          indent: 20,
                          endIndent: 20,
                        ),
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
                              onExpansionChanged: (isExpanded) {
                                setState(() {
                                  _isCompletedExpanded = isExpanded;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isTimerBarVisible)
              Positioned(
                left: 20,
                right: 20,
                bottom: 10,
                child: MiniTimerBar(
                  api: api,
                  notificationService: notificationService,
                  activeTodo: activeTodo,
                  onComplete: (id) => _handleTaskCompletion(id),
                ),
              ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final timerState = ref.watch(timerProvider);
    final isTimerBarVisible =
        timerState.isTimerActive && timerState.activeTaskId != null;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    if (isTimerBarVisible || isKeyboardVisible || _isCompletedExpanded) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          bottom: 12,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Made with ',
                    style: TextStyle(
                      color: AppColors.mediumGray.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const TextSpan(
                    text: '❤️',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: ' by Prayas',
                    style: TextStyle(
                      color: AppColors.mediumGray.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
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
    );
  }
}
