import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../models/todo.dart';
import './task_card.dart';
import '../providers/todos_provider.dart';
import '../../pomodoro/providers/timer_provider.dart';
import '../../pomodoro/models/timer_state.dart';
import '../../pomodoro/pomodoro_router.dart';
import '../../../core/widgets/progress_bar.dart';

// Enum to represent the available filter states for completed tasks.
enum CompletedFilter { none, onTime, overdue, underdue }

class TaskList extends ConsumerStatefulWidget {
  final List<Todo> todos;
  final dynamic api;
  final NotificationService notificationService;
  final Function(String id) onPlay;
  final Function(String id) onDelete;
  final Function(String id) onToggle;
  final ValueChanged<bool>? onExpansionChanged;

  const TaskList({
    required this.todos,
    required this.api,
    required this.notificationService,
    required this.onPlay,
    required this.onDelete,
    required this.onToggle,
    this.onExpansionChanged,
    super.key,
  });

  @override
  ConsumerState<TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<TaskList> {
  bool _completedExpanded = false;
  // Local state to manage the active filter for the completed tasks list.
  CompletedFilter _activeFilter = CompletedFilter.none;

  // Principle 3: Use local state to declaratively trigger UI events
  bool _shouldShowOverdueCompletionDialog = false;
  Todo? _overdueTodoForDialog;

  // Helper method to get the display name for a filter.
  String _getFilterName(CompletedFilter filter) {
    switch (filter) {
      case CompletedFilter.onTime:
        return 'Completed'; // CHANGED: "On Time" is now "Completed"
      case CompletedFilter.overdue:
        return 'Overdue';
      case CompletedFilter.underdue:
        return 'Underdue';
      case CompletedFilter.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Principle 3: Listen to provider state changes to trigger UI events
    ref.listen<TimerState>(timerProvider, (previous, next) {
      final wasComplete = previous?.overdueSessionsComplete ?? false;
      final isComplete = next.overdueSessionsComplete;

      // When the specific flag becomes true, prepare to show the dialog
      if (isComplete && !wasComplete && next.activeTaskId != null) {
        debugPrint(
          "TASK_LIST LISTENER: Detected overdueSessionsComplete for task ID ${next.activeTaskId}",
        );
        Todo? foundTodo;
        try {
          foundTodo = widget.todos.firstWhere((t) => t.id == next.activeTaskId);
        } catch (e) {
          debugPrint(
            "TASK_LIST LISTENER: Todo with ID ${next.activeTaskId} not found in current list",
          );
          return;
        }
        if (mounted) {
          setState(() {
            _overdueTodoForDialog = foundTodo;
            _shouldShowOverdueCompletionDialog = true;
          });
        }
      }
    });

    // If the flag is set, schedule the dialog to show after the build is complete.
    if (_shouldShowOverdueCompletionDialog && _overdueTodoForDialog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check flag and mounted status before showing
        if (mounted && _shouldShowOverdueCompletionDialog) {
          _showOverdueSessionCompletionPrompt(_overdueTodoForDialog!);
          // Reset the flag immediately after scheduling
          setState(() {
            _shouldShowOverdueCompletionDialog = false;
            _overdueTodoForDialog = null;
          });
        }
      });
    }
    final incompleteTodos = widget.todos.where((t) => !t.completed).toList();
    final completedTodos = widget.todos.where((t) => t.completed).toList();

    // Apply the active filter to the list of completed todos.
    final filteredCompletedTodos = completedTodos.where((todo) {
      if (_activeFilter == CompletedFilter.none) {
        return true;
      }

      final plannedSeconds =
          (todo.durationHours * 3600) + (todo.durationMinutes * 60);
      final isOverdue = todo.wasOverdue == 1;
      final isUnderdue =
          plannedSeconds > 0 && todo.focusedTime < plannedSeconds;

      switch (_activeFilter) {
        case CompletedFilter.overdue:
          return isOverdue;
        case CompletedFilter.underdue:
          return isUnderdue;
        case CompletedFilter.onTime: // Logic for "Completed" only
          return !isOverdue && !isUnderdue;
        case CompletedFilter.none:
          return true;
      }
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incompleteTodos.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: incompleteTodos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final todo = incompleteTodos[index];
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
                  widget.onExpansionChanged?.call(expanded);
                },
                controlAffinity: ListTileControlAffinity.leading,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Row(
                  children: [
                    Text(
                      'Completed',
                      style: const TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_activeFilter != CompletedFilter.none)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          '(${_getFilterName(_activeFilter)})',
                          style: const TextStyle(
                            color: AppColors.brightYellow,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
                  // NEW: Row for filter/clear buttons, placed below the header.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment
                          .start, // CHANGED: Aligned to the left
                      children: [
                        const Text(
                          'Filter:',
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 12,
                          ),
                        ),
                        PopupMenuButton<CompletedFilter>(
                          onSelected: (CompletedFilter result) {
                            setState(() {
                              _activeFilter = result;
                            });
                          },
                          icon: Icon(
                            Icons.filter_list,
                            color: _activeFilter == CompletedFilter.none
                                ? AppColors.mediumGray
                                : AppColors.brightYellow,
                          ),
                          tooltip: 'Filter completed tasks',
                          color: AppColors.cardBg,
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<CompletedFilter>>[
                                const PopupMenuItem<CompletedFilter>(
                                  value: CompletedFilter.onTime,
                                  child: Text(
                                    'Completed', // CHANGED
                                    style: TextStyle(
                                      color: AppColors.lightGray,
                                    ),
                                  ),
                                ),
                                const PopupMenuItem<CompletedFilter>(
                                  value: CompletedFilter.overdue,
                                  child: Text(
                                    'Overdue',
                                    style: TextStyle(
                                      color: AppColors.lightGray,
                                    ),
                                  ),
                                ),
                                const PopupMenuItem<CompletedFilter>(
                                  value: CompletedFilter.underdue,
                                  child: Text(
                                    'Underdue',
                                    style: TextStyle(
                                      color: AppColors.lightGray,
                                    ),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem<CompletedFilter>(
                                  value: CompletedFilter.none,
                                  child: Text(
                                    'Clear Filter',
                                    style: TextStyle(
                                      color: AppColors.lightGray,
                                    ),
                                  ),
                                ),
                              ],
                        ),
                        const SizedBox(width: 8),
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
                  ),
                  if (filteredCompletedTodos.isEmpty &&
                      _activeFilter != CompletedFilter.none)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        'No tasks match the "${_getFilterName(_activeFilter)}" filter.',
                        style: TextStyle(color: AppColors.mediumGray),
                      ),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredCompletedTodos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildTaskCard(filteredCompletedTodos[index]),
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

  Future<void> _showOverdueSessionCompletionPrompt(Todo todo) async {
    debugPrint(
      "SESSION_FLOW: Showing overdue session completion prompt for '${todo.text}'",
    );

    final timerNotifier = ref.read(timerProvider.notifier);
    final timerState = ref.read(timerProvider);
    final totalCycles = timerState.totalCycles;

    final result = await AppDialogs.showOverdueSessionCompleteDialog(
      context: context,
      totalCycles: totalCycles,
    );

    if (!mounted) return;

    timerNotifier.clearOverdueSessionsCompleteFlag();

    final liveFocusedTime = timerNotifier.getFocusedTime(todo.id);
    final plannedSeconds =
        (todo.durationHours * 3600) + (todo.durationMinutes * 60);
    final finalOverdueTime = (liveFocusedTime - plannedSeconds)
        .clamp(0, double.infinity)
        .toInt();

    if (result == true) {
      debugPrint("SESSION_FLOW: User chose 'Mark Complete'.");
      await ref.read(todosProvider.notifier).toggleTodo(todo.id);
      timerNotifier.clear();
    } else {
      debugPrint(
        "SESSION_FLOW: User chose 'Continue Working' or dismissed dialog.",
      );
      await timerNotifier.stopAndSaveProgress(todo.id);
      await ref
          .read(todosProvider.notifier)
          .updateFocusTime(todo.id, finalOverdueTime);
    }
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

    debugPrint(
      'PLAY_BUTTON: Task=${todo.text}, isThisTaskActive=$isThisTaskActive, isAnyTimerActive=$isAnyTimerActive',
    );

    if (isThisTaskActive) {
      await PomodoroRouter.showPomodoroSheet(
        context,
        widget.api,
        todo,
        widget.notificationService,
        ({bool wasOverdue = false, int overdueTime = 0}) async {},
      );
      debugPrint(
        "SESSION_FLOW: PomodoroSheet for '${todo.text}' has been closed.",
      );
      return;
    }

    if (isAnyTimerActive && timerState.activeTaskId != null) {
      final notifier = ref.read(timerProvider.notifier);
      final wasRunning = timerState.isRunning;
      if (wasRunning) notifier.pauseTask();

      final todosAsync = ref.read(todosProvider);
      String? currentTaskName;
      if (todosAsync.hasValue) {
        try {
          currentTaskName = todosAsync.value!
              .firstWhere((t) => t.id == timerState.activeTaskId)
              .text;
        } catch (e) {
          currentTaskName = null;
        }
      }

      final shouldSwitch = await AppDialogs.showSwitchTaskDialog(
        context: context,
        currentTaskName: currentTaskName ?? 'Unknown Task',
        newTaskName: todo.text,
      );

      if (shouldSwitch != true) {
        if (wasRunning) notifier.resumeTask();
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
      taskName: todo.text,
    );

    await PomodoroRouter.showPomodoroSheet(
      context,
      widget.api,
      todo,
      widget.notificationService,
      ({bool wasOverdue = false, int overdueTime = 0}) async {},
    );
    debugPrint(
      "SESSION_FLOW: PomodoroSheet for '${todo.text}' has been closed.",
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
        height: 16,
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
        height: 16,
        child: ProgressBar(
          focusedSeconds: focusedSeconds,
          plannedSeconds: plannedSeconds,
          barHeight: 16,
        ),
      );
    }
  }
}
