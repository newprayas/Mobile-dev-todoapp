import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/todo.dart';
import 'pomodoro_screen.dart';

class TodoListScreen extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  const TodoListScreen({required this.api, required this.auth, super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late Future<List<Todo>> _futureTodos;

  @override
  void initState() {
    super.initState();
    _futureTodos = _loadTodos();
  }

  Future<List<Todo>> _loadTodos() async {
    final list = await widget.api.fetchTodos();
    return list
        .map<Todo>((e) => Todo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureTodos = _loadTodos();
    });
  }

  Future<void> _addTodoDialog() async {
    final textCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '0');
    final minutesCtrl = TextEditingController(text: '25');
    final res = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('Add Todo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(labelText: 'Task'),
              ),
              Row(
                children: [
                  Flexible(
                    child: TextField(
                      controller: hoursCtrl,
                      decoration: const InputDecoration(labelText: 'Hours'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextField(
                      controller: minutesCtrl,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = textCtrl.text.trim();
                final h = int.tryParse(hoursCtrl.text) ?? 0;
                final m = int.tryParse(minutesCtrl.text) ?? 0;
                if (text.isEmpty) return;
                await widget.api.addTodo(text, h, m);
                if (navigator.mounted) navigator.pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (res == true) await _refresh();
  }

  Widget _buildTile(Todo t) {
    return ListTile(
      title: Text(t.text),
      subtitle: Text(
        '${t.durationHours}h ${t.durationMinutes}m • Focused: ${t.focusedTime}m',
      ),
      leading: Checkbox(
        value: t.completed,
        onChanged: (_) async {
          await widget.api.toggleTodo(t.id);
          await _refresh();
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () async {
              // open Pomodoro and pass the todo
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PomodoroScreen(api: widget.api, todo: t),
                ),
              );
              // refresh after returning in case focused time changed
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await widget.api.deleteTodo(t.id);
              await _refresh();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).pushNamed('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Todo>>(
          future: _futureTodos,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No todos'),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _buildTile(items[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
