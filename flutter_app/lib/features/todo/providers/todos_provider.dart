import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../../../core/services/api_service.dart';

class TodosNotifier extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() async {
    final api = ref.watch(apiServiceProvider);
    return await _fetchTodos(api);
  }

  Future<List<Todo>> _fetchTodos(ApiService api) async {
    try {
      final list = await api.fetchTodos();
      final raw = list
          .map<Todo>((e) => Todo.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // Deduplicate by id (first-seen kept) then sort newest-first by id
      final seen = <int>{};
      final unique = <Todo>[];
      for (final t in raw) {
        if (!seen.contains(t.id)) {
          unique.add(t);
          seen.add(t.id);
        }
      }
      unique.sort((a, b) => b.id.compareTo(a.id));
      return unique;
    } catch (e) {
      // Return current state on error to maintain optimistic updates
      return state.value ?? [];
    }
  }

  Future<void> addTodo(String text, int hours, int minutes) async {
    // Optimistic update
    final localId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final optimisticTodo = Todo(
      id: localId,
      userId: '',
      text: text,
      completed: false,
      durationHours: hours,
      durationMinutes: minutes,
      focusedTime: 0,
      wasOverdue: 0,
      overdueTime: 0,
    );

    // Add optimistically to current state
    final currentTodos = state.value ?? [];
    if (!currentTodos.any((t) => t.id == optimisticTodo.id)) {
      state = AsyncValue.data([optimisticTodo, ...currentTodos]);
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.addTodo(text, hours, minutes);
      // Refresh to get the real todo from server
      await refresh();
    } catch (e) {
      state = AsyncValue.data(currentTodos); // Revert state
      rethrow; // Rethrow to notify the UI
    }
  }

  Future<void> deleteTodo(int id) async {
    // Optimistic update
    final currentTodos = state.value ?? [];
    state = AsyncValue.data(
      currentTodos.where((todo) => todo.id != id).toList(),
    );

    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteTodo(id);
    } catch (e) {
      // Revert on error
      await refresh();
    }
  }

  Future<void> updateTodo(
    int id, {
    String? text,
    int? hours,
    int? minutes,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateTodo(id, text: text, hours: hours, minutes: minutes);
      await refresh();
    } catch (e) {
      // Could implement optimistic update here too
      rethrow;
    }
  }

  Future<void> toggleTodo(int id) async {
    // Optimistic update
    final currentTodos = state.value ?? [];
    final updatedTodos = currentTodos.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(completed: !todo.completed);
      }
      return todo;
    }).toList();
    state = AsyncValue.data(updatedTodos);

    try {
      final api = ref.read(apiServiceProvider);
      await api.toggleTodo(id);
      // No full refresh needed, optimistic update is usually enough
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentTodos);
    }
  }

  Future<void> toggleTodoWithOverdue(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    // Optimistic update with overdue information
    final currentTodos = state.value ?? [];
    final updatedTodos = currentTodos.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(
          completed: !todo.completed,
          wasOverdue: wasOverdue ? 1 : 0,
          overdueTime: overdueTime,
        );
      }
      return todo;
    }).toList();
    state = AsyncValue.data(updatedTodos);

    try {
      final api = ref.read(apiServiceProvider);
      await api.toggleTodoWithOverdue(
        id,
        wasOverdue: wasOverdue,
        overdueTime: overdueTime,
      );
      // No full refresh needed, optimistic update is usually enough
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentTodos);
    }
  }

  Future<void> clearCompleted() async {
    final currentTodos = state.value ?? [];
    final completedTodos = currentTodos
        .where((todo) => todo.completed)
        .toList();
    if (completedTodos.isEmpty) return;

    // Optimistic update
    state = AsyncValue.data(
      currentTodos.where((todo) => !todo.completed).toList(),
    );

    try {
      final api = ref.read(apiServiceProvider);
      // Call delete for each completed todo
      await Future.wait(completedTodos.map((todo) => api.deleteTodo(todo.id)));
    } catch (e) {
      // Revert on error
      await refresh();
    }
  }

  Future<void> refresh() async {
    final api = ref.read(apiServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTodos(api));
  }
}

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  throw UnimplementedError('apiServiceProvider must be overridden');
});

// Todos Provider
final todosProvider = AsyncNotifierProvider<TodosNotifier, List<Todo>>(
  TodosNotifier.new,
);
