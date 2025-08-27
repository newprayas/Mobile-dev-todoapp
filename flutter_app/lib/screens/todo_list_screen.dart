import 'package:flutter/material.dart';
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
                          color: AppColors.lightGray.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.brightYellow.withOpacity(0.2),
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
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.cardBg,
                            title: Text(
                              'Sign Out',
                              style: TextStyle(color: AppColors.lightGray),
                            ),
                            content: Text(
                              'Are you sure you want to sign out?',
                              style: TextStyle(
                                color: AppColors.lightGray.withOpacity(0.8),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.lightGray.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: AppColors.brightYellow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (shouldLogout == true) {
                          await ref.read(authProvider.notifier).signOut();
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
  late final TextEditingController _newText;
  late final TextEditingController _hours;
  late final TextEditingController _mins;

  @override
  void initState() {
    super.initState();
    _newText = TextEditingController();
    _hours = TextEditingController(text: '0');
    _mins = TextEditingController(text: '25');
  }

  @override
  void dispose() {
    _newText.dispose();
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  Future<void> _addTodo() async {
    final text = _newText.text.trim();
    final h = int.tryParse(_hours.text) ?? 0;
    final m = int.tryParse(_mins.text) ?? 0;
    if (text.isEmpty) return;

    await ref.read(todosProvider.notifier).addTodo(text, h, m);

    if (!mounted) return;

    _newText.clear();
    _hours.text = '0';
    _mins.text = '25';
    // Hide keyboard after adding
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiServiceProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    final todosAsync = ref.watch(todosProvider);

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
            const Text(
              'Welcome, prayas new!',
              style: TextStyle(color: AppColors.lightGray, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: AppColors.midGray,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _newText,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: null,
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  hintText: 'What do you need to do?',
                  hintStyle: TextStyle(color: AppColors.mediumGray),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _hours,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.midGray,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '0',
                      suffixText: 'h',
                    ),
                    style: const TextStyle(
                      color: AppColors.lightGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _mins,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.midGray,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '25',
                      suffixText: 'm',
                    ),
                    style: const TextStyle(
                      color: AppColors.lightGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _addTodo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brightYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                await ref.read(todosProvider.notifier).toggleTodo(id);
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
        await PomodoroScreen.showAsBottomSheet(
          context,
          widget.api,
          todo,
          widget.notificationService,
          () => ref.read(todosProvider.notifier).toggleTodo(todo.id),
        );
      },
      onDelete: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('Delete task?'),
            content: const Text('This will remove the task permanently.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await ref.read(todosProvider.notifier).deleteTodo(t.id);
        }
      },
      onToggle: () async {
        await ref.read(todosProvider.notifier).toggleTodo(t.id);
      },
      onUpdateText: (newText) async {
        await ref.read(todosProvider.notifier).updateTodo(t.id, text: newText);
      },
      onUpdateDuration: (h, m) async {
        await ref
            .read(todosProvider.notifier)
            .updateTodo(t.id, hours: h, minutes: m);
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
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Clear completed?'),
                            content: const Text(
                              'This will permanently delete all completed tasks.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dctx).pop(true),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
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
        const SizedBox(height: 60), // Space for the MiniTimerBar
      ],
    );
  }
}
