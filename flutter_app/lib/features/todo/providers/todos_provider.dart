// lib/features/todo/providers/todos_provider.dart
import 'dart:async'; // For StreamSubscription
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../../../core/data/todo_repository.dart';
import '../../../core/utils/debug_logger.dart'; // Import for debugLog

/// Manages the state of the todo list, leveraging a [TodoRepository]
/// for local-first data persistence and API synchronization.
class TodosNotifier extends AsyncNotifier<List<Todo>> {
  StreamSubscription<List<Todo>>? _todosSubscription;

  @override
  Future<List<Todo>> build() async {
    debugLog('TodosNotifier', 'Building TodosNotifier...');
    final repository = ref.watch(todoRepositoryProvider);

    // Initial sync with API to populate local DB
    // This makes sure the local database has the latest from the backend
    try {
      await repository.syncTodos();
      debugLog('TodosNotifier', 'Initial sync with API completed.');
    } catch (e, st) {
      debugLog('TodosNotifier', 'Initial API sync failed: $e\n$st');
      // Continue without API data, relying only on local storage
    }

    // Subscribe to changes from the local repository and update state
    _todosSubscription = repository.watchTodos().listen(
      (todos) {
        debugLog(
          'TodosNotifier',
          'Received ${todos.length} todos from local DB stream.',
        );
        state = AsyncValue.data(todos);
      },
      onError: (e, st) {
        debugLog('TodosNotifier', 'Error in local DB stream: $e\n$st');
        state = AsyncValue.error(e, st);
      },
    );

    ref.onDispose(() {
      _todosSubscription?.cancel();
      debugLog(
        'TodosNotifier',
        'TodosNotifier disposed, subscription cancelled.',
      );
    });

    // Return the initial data from the local database
    // This ensures that even if API sync fails, local data is shown immediately.
    // .first is used to get the initial value from the stream immediately.
    final initialTodos = await repository.watchTodos().first;
    debugLog(
      'TodosNotifier',
      'Initial data from local DB: ${initialTodos.length} todos.',
    );
    return initialTodos;
  }

  /// Adds a new todo via the repository.
  /// Handles optimistic updates and API sync.
  Future<void> addTodo(String text, int hours, int minutes) async {
    debugLog('TodosNotifier', 'Attempting to add todo: $text');
    // Set loading state if not already loading due to initial sync.
    // The stream listener will eventually set the data state.
    state = const AsyncValue.loading();
    try {
      await ref.read(todoRepositoryProvider).addTodo(text, hours, minutes);
      debugLog('TodosNotifier', 'Todo "$text" added successfully.');
    } catch (e, st) {
      debugLog('TodosNotifier', 'Failed to add todo "$text": $e\n$st');
      state = AsyncValue.error(
        e,
        st,
      ); // Revert to error state if API sync failed
      rethrow;
    } finally {
      // The stream listener will update the state to data
      // No need to manually set state = AsyncValue.data() here
    }
  }

  /// Deletes a todo by its ID via the repository.
  /// Handles optimistic updates and API sync.
  Future<void> deleteTodo(int id) async {
    debugLog('TodosNotifier', 'Attempting to delete todo ID: $id');
    // No need to manually set loading state here, optimistic update happens on repo side.
    try {
      await ref.read(todoRepositoryProvider).deleteTodo(id);
      debugLog('TodosNotifier', 'Todo ID: $id deleted successfully.');
    } catch (e, st) {
      debugLog('TodosNotifier', 'Failed to delete todo ID: $id: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      // The stream listener handles state update.
    }
  }

  /// Updates an existing todo's details via the repository.
  /// Handles optimistic updates and API sync.
  Future<void> updateTodo(
    int id, {
    String? text,
    int? hours,
    int? minutes,
  }) async {
    debugLog('TodosNotifier', 'Attempting to update todo ID: $id');
    try {
      await ref
          .read(todoRepositoryProvider)
          .updateTodo(id: id, text: text, hours: hours, minutes: minutes);
      debugLog('TodosNotifier', 'Todo ID: $id updated successfully.');
    } catch (e, st) {
      debugLog('TodosNotifier', 'Failed to update todo ID: $id: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      // The stream listener handles state update.
    }
  }

  /// Toggles a todo's completion status via the repository.
  /// Includes logic to pass live focused time.
  Future<void> toggleTodo(int id, {int? liveFocusedTime}) async {
    debugLog('TodosNotifier', 'Attempting to toggle todo ID: $id completion.');
    try {
      await ref
          .read(todoRepositoryProvider)
          .toggleTodo(id, liveFocusedTime: liveFocusedTime);
      debugLog('TodosNotifier', 'Todo ID: $id toggled successfully.');
    } catch (e, st) {
      debugLog('TodosNotifier', 'Failed to toggle todo ID: $id: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      // The stream listener handles state update.
    }
  }

  /// Toggles a todo with explicit overdue parameters.
  Future<void> toggleTodoWithOverdue(
    int id, {
    required bool wasOverdue,
    required int overdueTime,
  }) async {
    debugLog(
      'TodosNotifier',
      'Attempting to toggle todo ID: $id with overdue status.',
    );
    try {
      await ref
          .read(todoRepositoryProvider)
          .toggleTodoWithOverdue(
            id,
            wasOverdue: wasOverdue,
            overdueTime: overdueTime,
          );
      debugLog(
        'TodosNotifier',
        'Todo ID: $id toggled with overdue status successfully.',
      );
    } catch (e, st) {
      debugLog(
        'TodosNotifier',
        'Failed to toggle todo ID: $id with overdue status: $e\n$st',
      );
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      // The stream listener handles state update.
    }
  }

  /// Marks a task as permanently overdue in the local database.
  Future<void> markTaskPermanentlyOverdue(
    int id, {
    required int overdueTime,
  }) async {
    debugLog('TodosNotifier', 'Marking todo ID: $id as permanently overdue.');
    try {
      await ref
          .read(todoRepositoryProvider)
          .markTaskPermanentlyOverdue(id, overdueTime: overdueTime);
      debugLog(
        'TodosNotifier',
        'Todo ID: $id marked as permanently overdue successfully.',
      );
    } catch (e, st) {
      debugLog(
        'TodosNotifier',
        'Failed to mark todo ID: $id as permanently overdue: $e\n$st',
      );
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      // The stream listener handles state update.
    }
  }

  /// Updates the focused time (live) for a given todo.
  /// This is used by the Pomodoro timer to report incremental focused time.
  Future<void> updateFocusTime(int id, int focusedTime) async {
    debugLog(
      'TodosNotifier',
      'Updating focus time for todo ID: $id to $focusedTime seconds.',
    );
    try {
      await ref.read(todoRepositoryProvider).updateFocusTime(id, focusedTime);
      debugLog(
        'TodosNotifier',
        'Focus time for todo ID: $id updated successfully.',
      );
    } catch (e, st) {
      debugLog(
        'TodosNotifier',
        'Failed to update focus time for todo ID: $id: $e\n$st',
      );
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Clears all completed todos via the repository.
  Future<void> clearCompleted() async {
    debugLog('TodosNotifier', 'Attempting to clear completed todos.');
    try {
      await ref.read(todoRepositoryProvider).clearCompleted();
      debugLog('TodosNotifier', 'Completed todos cleared successfully.');
    } catch (e, st) {
      debugLog('TodosNotifier', 'Failed to clear completed todos: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      // The stream listener handles state update.
    }
  }

  /// Manually refreshes the todo list by re-syncing with the API.
  Future<void> refresh() async {
    debugLog(
      'TodosNotifier',
      'Manually refreshing todos (triggering API sync)...',
    );
    state = const AsyncValue.loading();
    try {
      await ref.read(todoRepositoryProvider).syncTodos();
      debugLog('TodosNotifier', 'Manual refresh completed successfully.');
      // The stream listener will update state to data.
    } catch (e, st) {
      debugLog('TodosNotifier', 'Manual refresh failed: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final todosProvider = AsyncNotifierProvider<TodosNotifier, List<Todo>>(
  TodosNotifier.new,
);
