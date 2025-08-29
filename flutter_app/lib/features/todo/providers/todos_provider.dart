import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../../../core/services/api_service.dart';

/// Todo list state management provider with optimistic updates.
///
/// Manages the complete todo lifecycle including creation, updates, deletion,
/// and completion. Implements optimistic UI updates for immediate feedback
/// with automatic rollback on API errors.
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

  /// Adds a new todo with optimistic updates.
  ///
  /// Creates a temporary todo with a local ID for immediate UI feedback,
  /// then replaces it with the server-generated todo on successful creation.
  /// Automatically reverts on API errors.
  ///
  /// Parameters:
  /// - [text]: Todo description text
  /// - [hours]: Planned duration hours (0-23)
  /// - [minutes]: Planned duration minutes (0-59)
  ///
  /// Throws: API exceptions if the server request fails
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

  /// Deletes a todo with optimistic updates.
  ///
  /// Immediately removes the todo from the UI, then calls the API.
  /// Automatically reverts the list if the API call fails.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to delete
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

  /// Updates todo properties via API.
  ///
  /// Modifies text content and/or planned duration for an existing todo.
  /// Refreshes the full list after successful update.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to update
  /// - [text]: New description text (optional)
  /// - [hours]: New planned duration hours (optional)
  /// - [minutes]: New planned duration minutes (optional)
  ///
  /// Throws: API exceptions if the server request fails
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

  /// Toggles todo completion status with optimistic updates.
  ///
  /// Immediately flips the completed status in the UI, then syncs with API.
  /// Automatically reverts on API errors.
  ///
  /// **IMPORTANT UX BEHAVIOR:** When a completed task is revived (toggled back to incomplete),
  /// this method preserves its `wasOverdue` status AND adds the overdue time to the task's
  /// planned duration. This ensures that a task that previously required extra time will
  /// have that time built into its duration for future sessions, aligning with the UX flowchart
  /// requirement that revived overdue tasks start with their original duration plus overdue time.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to toggle
  Future<void> toggleTodo(int id) async {
    // Optimistic update
    final currentTodos = state.value ?? [];
    final updatedTodos = currentTodos.map((todo) {
      if (todo.id == id) {
        // PERMANENT OVERDUE UX (Updated):
        // If a completed task is revived and it WAS overdue, we DO NOT
        // fold the overdue time into the planned duration anymore.
        // The task remains permanently in overdue mode – planned duration
        // acts as its original baseline for historical context.
        // So revival simply toggles completion off while preserving
        // wasOverdue + overdueTime fields.
        if (todo.completed) {
          return todo.copyWith(completed: false);
        }
        // Completing a task (normal path without overdue dialog)
        return todo.copyWith(completed: true);
      }
      return todo;
    }).toList();
    state = AsyncValue.data(updatedTodos);

    try {
      final api = ref.read(apiServiceProvider);
      // Plain toggle; permanent overdue attributes remain untouched locally.
      await api.toggleTodo(id);
      // No full refresh needed, optimistic update is usually enough
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentTodos);
    }
  }

  /// Marks a todo as completed with overdue information.
  ///
  /// Unlike toggleTodoWithOverdue, this method specifically marks the task as completed
  /// and is used when completing tasks from the overdue dialog.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to complete
  /// - [overdueTime]: Additional time spent beyond planned duration in seconds
  Future<void> completeTodoWithOverdue(int id, {int overdueTime = 0}) async {
    // Optimistic update - mark as completed with overdue information
    final currentTodos = state.value ?? [];
    final updatedTodos = currentTodos.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(
          completed: true,
          wasOverdue: 1,
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
        wasOverdue: true,
        overdueTime: overdueTime,
      );
      // No full refresh needed, optimistic update is usually enough
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentTodos);
    }
  }

  /// Toggles todo completion with overdue tracking information.
  ///
  /// Enhanced version of toggleTodo that also tracks overdue completion.
  /// Used when a task is completed after exceeding its planned duration.
  ///
  /// Parameters:
  /// - [id]: Database ID of the todo to toggle
  /// - [wasOverdue]: Whether the task was completed past its planned time
  /// - [overdueTime]: Additional time spent beyond planned duration in seconds
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

  /// Marks a task as permanently overdue locally (optimistic state only).
  ///
  /// Used when the user chooses to CONTINUE after the overdue dialog.
  /// We have already updated the focused time on the backend (which sets
  /// was_overdue + overdue_time there). This method immediately mirrors
  /// that change in local state so the UI reflects permanent overdue mode
  /// without waiting for a full refresh.
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

  /// Removes all completed todos with optimistic updates.
  ///
  /// Immediately hides completed todos from the UI, then batch-deletes them
  /// via the API. Automatically reverts the full list on API errors.
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
