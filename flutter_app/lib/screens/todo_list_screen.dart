import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/todo.dart';
import '../theme/app_colors.dart';
import '../utils/debug_logger.dart';
import '../widgets/task_card.dart';
import 'pomodoro_screen.dart';
import '../services/timer_service.dart';
import '../widgets/mini_timer_bar.dart';

import '../services/notification_service.dart';

class TodoListScreen extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  final NotificationService notificationService;
  const TodoListScreen({
    required this.api,
    required this.auth,
    required this.notificationService,
    super.key,
  });

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _newText = TextEditingController();
  final TextEditingController _hours = TextEditingController(text: '0');
  final TextEditingController _mins = TextEditingController(text: '25');
  List<Todo> _todos = [];
  bool _loading = true;
  bool _completedExpanded = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _reload();
    TimerService.instance.addListener(_onTimerServiceUpdate);
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_onTimerServiceUpdate);
    _newText.dispose();
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _onTimerServiceUpdate() {
    // Rebuild to find the active todo and pass it to the mini-bar
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    try {
      final list = await widget.api.fetchTodos();
      final raw = list
          .map<Todo>((e) => Todo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Deduplicate by id (first-seen kept)
      final seen = <int>{};
      final unique = <Todo>[];
      for (final t in raw) {
        if (!seen.contains(t.id)) {
          unique.add(t);
          seen.add(t.id);
        }
      }
      _todos = unique;
    } catch (_) {
      _todos = [];
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addTodo() async {
    if (_adding) return;
    final text = _newText.text.trim();
    final h = int.tryParse(_hours.text) ?? 0;
    final m = int.tryParse(_mins.text) ?? 0;
    if (text.isEmpty) return;
    _adding = true;
    try {
      debugLog('TODO', 'Adding: "$text" (${h}h ${m}m)');
      await widget.api.addTodo(text, h, m);
      _newText.clear();
      _hours.text = '0';
      _mins.text = '25';
      await _reload();
    } catch (err, st) {
      debugLog('TODO', 'Add failed: $err\n$st');
      // optimistic local insert to keep UX responsive
      final localId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final todo = Todo(
        id: localId,
        userId: '',
        text: text,
        completed: false,
        durationHours: h,
        durationMinutes: m,
        focusedTime: 0,
        wasOverdue: 0,
        overdueTime: 0,
      );
      setState(() {
        if (!_todos.any((t) => t.id == todo.id)) _todos = [todo, ..._todos];
        _newText.clear();
        _hours.text = '0';
        _mins.text = '25';
      });
    } finally {
      _adding = false;
    }
  }

  // _pickNumber removed - hours/minutes are edited inline now.

  Future<void> _deleteTodo(int id) async {
    debugLog('TODO', 'Deleting todo $id');
    try {
      await widget.api.deleteTodo(id);
      await _reload();
    } catch (err, st) {
      debugLog('TODO', 'Delete failed: $err\n$st');
    }
  }

  Future<void> _toggleTodo(int id) async {
    debugLog('TODO', 'Toggling todo $id');
    try {
      await widget.api.toggleTodo(id);
      await _reload();
    } catch (err, st) {
      debugLog('TODO', 'Toggle failed: $err\n$st');
    }
  }

  Future<void> _clearCompleted() async {
    final completed = _todos.where((t) => t.completed).toList();
    for (final t in completed) {
      await widget.api.deleteTodo(t.id);
    }
    await _reload();
  }

  Widget _buildTaskCard(Todo t) {
    final svc = TimerService.instance;
    final isActive = svc.activeTaskName == t.text && svc.isRunning;
    return TaskCard(
      todo: t,
      isActive: isActive,
      onPlay: (todo) async {
        await PomodoroScreen.showAsBottomSheet(
          context,
          widget.api,
          todo,
          widget.notificationService,
          () => _toggleTodo(todo.id),
        );
        debugPrint("POMODORO SHEET CLOSED: Reloading list.");
        await _reload(); // This reloads the list after the sheet is closed
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
        if (confirm == true) await _deleteTodo(t.id);
      },
      onToggle: () async {
        await _toggleTodo(t.id);
      },
      onUpdateText: (newText) async {
        await widget.api.updateTodo(t.id, text: newText);
        await _reload();
      },
      onUpdateDuration: (h, m) async {
        await widget.api.updateTodo(t.id, hours: h, minutes: m);
        await _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = min(screenWidth * 0.95, 520.0);

    final activeTaskName = TimerService.instance.activeTaskName;
    Todo? activeTodo;
    if (activeTaskName != null) {
      // Use a simple loop to find the todo to avoid exceptions
      for (final todo in _todos) {
        if (todo.text == activeTaskName) {
          activeTodo = todo;
          break;
        }
      }
    }
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Center(
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
                      mainAxisAlignment: _todos.isEmpty
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
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
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 22),

                        // Centered content block: add area + list
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Add area (multiline auto-expanding input)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.midGray,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
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
                                    hintStyle: TextStyle(
                                      color: AppColors.mediumGray,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Time selectors (inline editable) and Add button
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        hintText: '0',
                                        suffixText: 'h',
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.lightGray,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      onSubmitted: (_) => setState(() {}),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        hintText: '25',
                                        suffixText: 'm',
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.lightGray,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      onSubmitted: (_) => setState(() {}),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
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

                              // Scrolling area
                              Expanded(
                                child: _loading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : ListView(
                                        padding: EdgeInsets.zero,
                                        children: [
                                          // Active tasks
                                          ..._todos
                                              .where((t) => !t.completed)
                                              .map((t) => _buildTaskCard(t)),
                                          const SizedBox(height: 18),
                                          Container(
                                            height: 2,
                                            color: AppColors.brightYellow,
                                          ),
                                          const SizedBox(height: 8),
                                          ExpansionTile(
                                            initiallyExpanded:
                                                _completedExpanded,
                                            onExpansionChanged: (v) => setState(
                                              () => _completedExpanded = v,
                                            ),
                                            title: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.check,
                                                      color:
                                                          AppColors.lightGray,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Completed',
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.lightGray,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_completedExpanded)
                                                  ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (dctx) => AlertDialog(
                                                          title: const Text(
                                                            'Clear completed?',
                                                          ),
                                                          content: const Text(
                                                            'This will permanently delete all completed tasks.',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    dctx,
                                                                  ).pop(false),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    dctx,
                                                                  ).pop(true),
                                                              child: const Text(
                                                                'Clear',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm == true) {
                                                        await _clearCompleted();
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color:
                                                          AppColors.lightGray,
                                                    ),
                                                    label: const Text(
                                                      'Clear All',
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.lightGray,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.midGray,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            children: [
                                              ..._todos
                                                  .where((t) => t.completed)
                                                  .map(
                                                    (t) => _buildTaskCard(t),
                                                  ),
                                            ],
                                          ),

                                          const SizedBox(height: 24),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtle logout at bottom-left
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final nav = Navigator.of(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dctx) => AlertDialog(
                                  title: const Text('Logout?'),
                                  content: const Text(
                                    'You will be signed out of the app.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(dctx).pop(true),
                                      child: const Text('Logout'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await widget.auth.signOut();
                                if (!mounted) return;
                                nav.pushReplacementNamed('/login');
                              }
                            },
                            icon: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.lightGray.withAlpha(
                                    31,
                                  ), // ~0.12 opacity
                                ),
                              ),
                              child: const Icon(
                                Icons.logout,
                                color: AppColors.lightGray,
                              ),
                            ),
                            label: Text(
                              'Logout',
                              style: TextStyle(
                                color: AppColors.lightGray.withAlpha(
                                  179,
                                ), // ~0.7 opacity
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                        // main column end
                      ],
                    ),
                    // Positioned mini-timer overlay that covers bottom controls (e.g., logout)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MiniTimerBar(
                        api: widget.api,
                        notificationService: widget.notificationService,
                        activeTodo: activeTodo,
                        onComplete: _toggleTodo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
