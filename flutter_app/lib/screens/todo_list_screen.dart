import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/todo.dart';
import '../theme/app_colors.dart';
import 'pomodoro_screen.dart';

class TodoListScreen extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  const TodoListScreen({required this.api, required this.auth, super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _newText = TextEditingController();
  final TextEditingController _hours = TextEditingController(text: '0');
  final TextEditingController _mins = TextEditingController(text: '25');
  List<Todo> _todos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    try {
      final list = await widget.api.fetchTodos();
      _todos = list
          .map<Todo>((e) => Todo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      _todos = [];
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addTodo() async {
    final text = _newText.text.trim();
    final h = int.tryParse(_hours.text) ?? 0;
    final m = int.tryParse(_mins.text) ?? 0;
    if (text.isEmpty) return;
    await widget.api.addTodo(text, h, m);
    _newText.clear();
    _hours.text = '0';
    _mins.text = '25';
    await _reload();
  }

  Future<void> _pickNumber(
    BuildContext ctx,
    TextEditingController controller,
    String title,
  ) async {
    final tmp = TextEditingController(text: controller.text);
    final res = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text('Set $title'),
        content: TextField(
          controller: tmp,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (res == true) {
      controller.text = tmp.text;
      setState(() {});
    }
  }

  Future<void> _deleteTodo(int id) async {
    await widget.api.deleteTodo(id);
    await _reload();
  }

  Future<void> _toggleTodo(int id) async {
    await widget.api.toggleTodo(id);
    await _reload();
  }

  Future<void> _clearCompleted() async {
    final completed = _todos.where((t) => t.completed).toList();
    for (final t in completed) {
      await widget.api.deleteTodo(t.id);
    }
    await _reload();
  }

  Widget _buildTaskCard(Todo t) {
    final totalMins = (t.durationHours * 60) + t.durationMinutes;
    final progress = totalMins == 0
        ? 0.0
        : (t.focusedTime / totalMins).clamp(0.0, 1.0);
    final editController = TextEditingController(text: t.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.midGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.brightYellow.withAlpha(8),
              width: 0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  child: Builder(
                    builder: (ctx) {
                      final hasFocus = Focus.of(ctx).hasFocus;
                      return TextField(
                        controller: editController,
                        style: const TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          filled: true,
                          fillColor: hasFocus
                              ? AppColors.inputFill
                              : AppColors.midGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: hasFocus
                                  ? AppColors.focusBorder
                                  : Colors.transparent,
                              width: hasFocus ? 2 : 0,
                            ),
                          ),
                        ),
                        onSubmitted: (v) async {
                          final newText = v.trim();
                          if (newText.isEmpty) return;
                          await widget.api.updateTodo(t.id, text: newText);
                          await _reload();
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // duration summary with edit affordance
              GestureDetector(
                onTap: () async {
                  final tmpHours = TextEditingController(
                    text: '${t.durationHours}',
                  );
                  final tmpMins = TextEditingController(
                    text: '${t.durationMinutes}',
                  );
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('Edit duration'),
                      content: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tmpHours,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Hours',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: tmpMins,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minutes',
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(dctx).pop(true),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    final h = int.tryParse(tmpHours.text) ?? 0;
                    final m = int.tryParse(tmpMins.text) ?? 0;
                    await widget.api.updateTodo(t.id, hours: h, minutes: m);
                    await _reload();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.midGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 18,
                        color: AppColors.lightGray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${t.durationHours}h ${t.durationMinutes}m',
                        style: const TextStyle(
                          color: AppColors.lightGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                color: AppColors.lightGray,
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PomodoroScreen(api: widget.api, todo: t),
                    ),
                  );
                  await _reload();
                },
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: AppColors.lightGray,
                onPressed: () => _toggleTodo(t.id),
                tooltip: 'Mark completed',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppColors.lightGray,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('Delete task?'),
                      content: const Text(
                        'This will remove the task permanently.',
                      ),
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
                    await _deleteTodo(t.id);
                  }
                },
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: AppColors.midGray,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.brightYellow,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = min(screenWidth * 0.95, 520.0);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(22),
              ),
              // Use Column with Expanded ListView so the inner list scrolls on phones
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brightYellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Made with ❤️ by Prayas',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'To-Do App',
                    style: TextStyle(
                      color: AppColors.brightYellow,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Welcome, prayas new!',
                    style: TextStyle(color: AppColors.lightGray, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  // Add row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.midGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _newText,
                            style: const TextStyle(
                              color: AppColors.lightGray,
                              fontSize: 16,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Add a new to-do...',
                              hintStyle: TextStyle(color: AppColors.mediumGray),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.midGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              _pickNumber(context, _hours, 'Hours'),
                          child: Text(
                            '${_hours.text}h',
                            style: const TextStyle(
                              color: AppColors.lightGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.midGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              _pickNumber(context, _mins, 'Minutes'),
                          child: Text(
                            '${_mins.text}m',
                            style: const TextStyle(
                              color: AppColors.lightGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brightYellow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _addTodo,
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // The scrolling area
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              // Active tasks
                              ..._todos
                                  .where((t) => !t.completed)
                                  .map((t) => _buildTaskCard(t)),
                              const SizedBox(height: 18),
                              // Separator + completed header
                              Container(
                                height: 2,
                                color: AppColors.brightYellow,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons
                                            .check, // clearer icon for completed
                                        color: AppColors.lightGray,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          color: AppColors.lightGray,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
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
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(true),
                                              child: const Text('Clear'),
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
                                      color: AppColors.lightGray,
                                    ),
                                    label: const Text(
                                      'Clear All',
                                      style: TextStyle(
                                        color: AppColors.lightGray,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.midGray,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_todos.where((t) => t.completed).isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    children: const [
                                      Icon(
                                        Icons.outbox,
                                        size: 48,
                                        color: AppColors.mediumGray,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No completed tasks yet',
                                        style: TextStyle(
                                          color: AppColors.mediumGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._todos
                                    .where((t) => t.completed)
                                    .map((t) => _buildTaskCard(t)),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: 170,
                    height: 52,
                    child: ElevatedButton.icon(
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
                                onPressed: () => Navigator.of(dctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dctx).pop(true),
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
                      icon: const Icon(Icons.logout, color: Colors.black),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.actionSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
