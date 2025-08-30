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
    final list = await api.fetchTodos();
    final raw = list
        .map<Todo>((e) => Todo.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Sort by creation time (assuming higher ID is newer)
    raw.sort((a, b) => b.id.compareTo(a.id));
    return raw;
  }

  Future<void> addTodo(String text, int hours, int minutes) async {
    // Use a negative, temporary ID for the optimistic update.
    final optimisticId = -DateTime.now().millisecondsSinceEpoch;
    final optimisticTodo = Todo(
      id: optimisticId,
      userId: 'local', // Placeholder
      text: text,
      completed: false,
      durationHours: hours,
      durationMinutes: minutes,
      focusedTime: 0,
      wasOverdue: 0,
      overdueTime: 0,
    );

    // Optimistically add to the list
    final previousState = state.value ?? [];
    state = AsyncValue.data([optimisticTodo, ...previousState]);

    try {
      final api = ref.read(apiServiceProvider);
      final newTodoData = await api.addTodo(text, hours, minutes);
      final newTodoFromServer = Todo.fromJson(
        newTodoData as Map<String, dynamic>,
      );

      // Replace the optimistic todo with the real one from the server
      final currentTodos = state.value ?? [];
      final updatedList = currentTodos.map((todo) {
        return todo.id == optimisticId ? newTodoFromServer : todo;
      }).toList();

      // Sort again to ensure correct order if multiple adds happened
      updatedList.sort((a, b) => b.id.compareTo(a.id));
      state = AsyncValue.data(updatedList);
    } catch (e) {
      // On failure, revert the optimistic update.
      state = AsyncValue.data(previousState);
      rethrow;
    }
  }

  Future<void> deleteTodo(int id) async {
    final previousState = state.value ?? [];
    // Optimistically remove the todo
    state = AsyncValue.data(
      previousState.where((todo) => todo.id != id).toList(),
    );

    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteTodo(id);
      // No refresh needed, optimistic update is sufficient
    } catch (e) {
      // On failure, revert state
      state = AsyncValue.data(previousState);
    }
  }

  Future<void> updateTodo(
    int id, {
    String? text,
    int? hours,
    int? minutes,
  }) async {
    // This action is less frequent, so a refresh is acceptable if needed,
    // but we can also do it optimistically.
    final previousState = state.value ?? [];
    final updatedTodos = previousState.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(
          text: text ?? todo.text,
          durationHours: hours ?? todo.durationHours,
          durationMinutes: minutes ?? todo.durationMinutes,
        );
      }
      return todo;
    }).toList();
    state = AsyncValue.data(updatedTodos);

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateTodo(id, text: text, hours: hours, minutes: minutes);
    } catch (e) {
      state = AsyncValue.data(previousState);
      rethrow;
    }
  }

  Future<void> toggleTodo(int id, {int? liveFocusedTime}) async {
    final previousState = state.value ?? [];
    Todo? toggledTodo;

    final updatedTodos = previousState.map((todo) {
      if (todo.id != id) return todo;

      final focusedTime = liveFocusedTime ?? todo.focusedTime;
      final plannedSeconds =
          (todo.durationHours * 3600) + (todo.durationMinutes * 60);

      // Case 1: Reviving a completed task
      if (todo.completed) {
        if (todo.wasOverdue == 1) {
          toggledTodo = todo.copyWith(completed: false);
          return toggledTodo!;
        }

        final bool wasUnderdue =
            plannedSeconds > 0 && todo.focusedTime < plannedSeconds;
        if (wasUnderdue) {
          toggledTodo = todo.copyWith(completed: false);
        } else {
          toggledTodo = todo.copyWith(
            completed: false,
            wasOverdue: 1,
            overdueTime: todo.overdueTime,
          );
        }
        return toggledTodo!;
      }
      // Case 2: Completing an incomplete task
      else {
        int finalOverdueTime = todo.overdueTime;
        if (todo.wasOverdue == 1) {
          finalOverdueTime = (focusedTime - plannedSeconds)
              .clamp(0, double.infinity)
              .toInt();
        }
        toggledTodo = todo.copyWith(
          completed: true,
          focusedTime: focusedTime,
          overdueTime: finalOverdueTime,
        );
        return toggledTodo!;
      }
    }).toList();

    state = AsyncValue.data(updatedTodos);

    if (toggledTodo == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.toggleTodoWithOverdue(
        id,
        wasOverdue: toggledTodo!.wasOverdue == 1,
        overdueTime: toggledTodo!.overdueTime,
      );
    } catch (e) {
      state = AsyncValue.data(previousState);
    }
  }

  Future<void> toggleTodoWithOverdue(
    int id, {
    bool wasOverdue = false,
    int overdueTime = 0,
  }) async {
    final previousState = state.value ?? [];
    final updatedTodos = previousState.map((todo) {
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
    } catch (e) {
      state = AsyncValue.data(previousState);
    }
  }

  void markTaskPermanentlyOverdue(int id, {required int overdueTime}) {
    final List<Todo> current = state.value ?? <Todo>[];
    bool changed = false;
    final List<Todo> updated = current.map((Todo t) {
      if (t.id == id) {
        changed = true;
        return t.copyWith(wasOverdue: 1, overdueTime: overdueTime);
      }
      return t;
    }).toList();
    if (changed) {
      state = AsyncValue.data(updated);
    }
  }

  Future<void> clearCompleted() async {
    final previousState = state.value ?? [];
    final completedTodos = previousState
        .where((todo) => todo.completed)
        .toList();
    if (completedTodos.isEmpty) return;

    state = AsyncValue.data(
      previousState.where((todo) => !todo.completed).toList(),
    );

    try {
      final api = ref.read(apiServiceProvider);
      await Future.wait(completedTodos.map((todo) => api.deleteTodo(todo.id)));
    } catch (e) {
      state = AsyncValue.data(previousState);
    }
  }

  Future<void> refresh() async {
    final api = ref.read(apiServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTodos(api));
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  throw UnimplementedError('apiServiceProvider must be overridden');
});

final todosProvider = AsyncNotifierProvider<TodosNotifier, List<Todo>>(
  TodosNotifier.new,
);
