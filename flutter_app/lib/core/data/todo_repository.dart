// lib/core/data/todo_repository.dart
import 'package:drift/drift.dart';
// (no direct foundation imports needed here)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart'; // Correctly typed ApiService
import '../services/mock_api_service.dart';
import '../../features/todo/models/todo.dart';
import 'app_database.dart';
import '../utils/debug_logger.dart'; // Import for debugLog

/// Manages data operations for Todo items, acting as an abstraction layer
/// between the UI (via TodosNotifier) and data sources (local database, API).
/// Implements a local-first strategy with optimistic updates and API syncing.
class TodoRepository {
  final AppDatabase _localDb;
  final ApiService
  _apiService; // IMPORTANT: Now correctly expecting the real ApiService type
  TodoRepository(this._localDb, this._apiService);

  /// Provides a stream of all todos from the local database.
  ///
  /// This is the primary source of truth for the UI.
  Stream<List<Todo>> watchTodos() {
    return _localDb.watchAllTodos();
  }

  /// Fetches todos from the API and syncs them with the local database.
  ///
  /// This method is called on app startup or when a refresh is explicitly requested.
  Future<void> syncTodos() async {
    debugLog('TodoRepository', 'Attempting to sync todos with API...');
    try {
      final remoteData = await _apiService.fetchTodos();
      // Map raw dynamic JSON data to our Todo model, including createdAt
      final List<Todo> remoteTodos = remoteData.map((e) {
        final Map<String, dynamic> rawJson = Map<String, dynamic>.from(e);
        return Todo(
          id: rawJson['id'] is int
              ? rawJson['id']
              : int.parse('${rawJson['id']}'),
          userId: rawJson['user_id'] ?? rawJson['userId'] ?? '',
          text:
              rawJson['text'] ??
              '', // Use 'text' from API, maps to taskText in DB
          completed:
              (rawJson['completed'] == 1 || rawJson['completed'] == true),
          durationHours: rawJson['duration_hours'] != null
              ? (rawJson['duration_hours'] is int
                    ? rawJson['duration_hours']
                    : int.parse('${rawJson['duration_hours']}'))
              : 0,
          durationMinutes: rawJson['duration_minutes'] != null
              ? (rawJson['duration_minutes'] is int
                    ? rawJson['duration_minutes']
                    : int.parse('${rawJson['duration_minutes']}'))
              : 0,
          focusedTime: rawJson['focused_time'] != null
              ? (rawJson['focused_time'] is int
                    ? rawJson['focused_time']
                    : int.parse('${rawJson['focused_time']}'))
              : 0,
          wasOverdue: rawJson['was_overdue'] != null
              ? (rawJson['was_overdue'] is int
                    ? rawJson['was_overdue']
                    : int.parse('${rawJson['was_overdue']}'))
              : 0,
          overdueTime: rawJson['overdue_time'] != null
              ? (rawJson['overdue_time'] is int
                    ? rawJson['overdue_time']
                    : int.parse('${rawJson['overdue_time']}'))
              : 0,
          createdAt: DateTime.parse(rawJson['created_at']), // Parse DateTime
        );
      }).toList();

      final allLocalEntries = await _localDb.select(_localDb.todos).get();
      final List<Todo> allLocalTodos = allLocalEntries
          .map(_localDb.mapTodoEntryToTodoModel)
          .toList(); // Use public mapTodoEntryToTodoModel

      final remoteIds = remoteTodos.map((t) => t.id).toSet();

      // Delete local todos that are not on the server
      for (final localTodo in allLocalTodos) {
        if (!remoteIds.contains(localTodo.id)) {
          await _localDb.deleteTodo(localTodo.id);
          debugLog(
            'TodoRepository',
            'Deleted local todo ID: ${localTodo.id} (not found on server)',
          );
        }
      }

      // Insert or update remote todos locally
      for (final remoteTodo in remoteTodos) {
        final existingLocal = allLocalTodos.firstWhereOrNull(
          (t) => t.id == remoteTodo.id,
        );
        if (existingLocal == null) {
          // Insert new todo
          // Ensure `id` is not passed for auto-incrementing inserts if it's 0 or similar
          final TodosCompanion companion =
              AppDatabase.toTodosCompanion(remoteTodo, isInsert: true).copyWith(
                id: const Value.absent(),
              ); // Explicitly absent for new inserts
          await _localDb.insertTodo(companion);
          debugLog(
            'TodoRepository',
            'Inserted new remote todo: ${remoteTodo.text}',
          );
        } else {
          // Update existing todo if remote is newer or has different data
          // Simple check: compare relevant fields. For full robustness, timestamp or versioning is better.
          if (remoteTodo.text != existingLocal.text ||
              remoteTodo.completed != existingLocal.completed ||
              remoteTodo.durationHours != existingLocal.durationHours ||
              remoteTodo.durationMinutes != existingLocal.durationMinutes ||
              remoteTodo.focusedTime != existingLocal.focusedTime ||
              remoteTodo.wasOverdue != existingLocal.wasOverdue ||
              remoteTodo.overdueTime != existingLocal.overdueTime ||
              remoteTodo.createdAt != existingLocal.createdAt) {
            await _localDb.updateTodo(
              remoteTodo.id,
              AppDatabase.toTodosCompanion(remoteTodo, isInsert: false),
            );
            debugLog(
              'TodoRepository',
              'Updated local todo ID: ${remoteTodo.id} with remote data',
            );
          }
        }
      }

      debugLog('TodoRepository', 'Todos synced successfully.');
    } catch (e, st) {
      debugLog('TodoRepository', 'Error syncing todos: $e\n$st');
      // Depending on policy, might rethrow or log silently
      rethrow;
    }
  }

  /// Adds a new todo, first to the local database, then attempts to sync with API.
  Future<void> addTodo(String text, int hours, int minutes) async {
    // Optimistically add to local database first
    final optimisticLocalTodo = Todo(
      id: -1, // Temporary ID, will be replaced by local DB auto-increment
      userId: _apiService.devUserId, // Use the dev user ID or actual user ID
      text: text,
      completed: false,
      durationHours: hours,
      durationMinutes: minutes,
      focusedTime: 0,
      wasOverdue: 0,
      overdueTime: 0,
      createdAt: DateTime.now(),
    );

    // Insert into local DB. This will trigger UI update.
    final TodosCompanion insertCompanion = AppDatabase.toTodosCompanion(
      optimisticLocalTodo,
      isInsert: true,
    ).copyWith(id: Value.absent()); // Let DB auto-assign its own local ID

    final insertedLocalTodo = await _localDb.insertTodo(insertCompanion);
    debugLog(
      'TodoRepository',
      'Optimistically added local todo with DB ID: ${insertedLocalTodo.id} (${insertedLocalTodo.text})',
    );

    try {
      // Then send to API
      final newTodoData = await _apiService.addTodo(text, hours, minutes);
      final newTodoFromServer = Todo(
        id: newTodoData['id'],
        userId: newTodoData['user_id'],
        text: newTodoData['text'],
        completed: newTodoData['completed'] == 1,
        durationHours: newTodoData['duration_hours'],
        durationMinutes: newTodoData['duration_minutes'],
        focusedTime: newTodoData['focused_time'],
        wasOverdue: newTodoData['was_overdue'] ?? 0,
        overdueTime: newTodoData['overdue_time'] ?? 0,
        createdAt: DateTime.parse(newTodoData['created_at']),
      );

      // Replace the optimistic local entry with the real server entry.
      // This is crucial: we delete the temporary local entry and insert the server-provided one.
      await _localDb.deleteTodo(insertedLocalTodo.id); // Delete the temp local
      await _localDb.insertTodo(
        AppDatabase.toTodosCompanion(newTodoFromServer, isInsert: false),
      ); // Insert the real local, preserving server ID
      debugLog(
        'TodoRepository',
        'Successfully synced new todo with API, replaced local entry. Old ID: ${insertedLocalTodo.id}, New ID: ${newTodoFromServer.id}',
      );
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to add todo to API: $e\n$st. Deleting local optimistic entry ID: ${insertedLocalTodo.id}.',
      );
      await _localDb.deleteTodo(
        insertedLocalTodo.id,
      ); // Revert optimistic local change on API failure
      rethrow;
    }
  }

  /// Deletes a todo locally and then attempts to delete from API.
  Future<void> deleteTodo(int id) async {
    final originalTodo = await _localDb.getTodoById(id);
    if (originalTodo == null) {
      debugLog(
        'TodoRepository',
        'Attempted to delete non-existent todo ID: $id',
      );
      return; // Already deleted or never existed
    }

    await _localDb.deleteTodo(id); // Optimistic local delete
    debugLog('TodoRepository', 'Optimistically deleted local todo ID: $id');

    try {
      await _apiService.deleteTodo(id); // Then delete from API
      debugLog('TodoRepository', 'Successfully deleted todo ID: $id from API');
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to delete todo ID: $id from API: $e\n$st. Reverting local delete.',
      );
      await _localDb.insertTodo(
        AppDatabase.toTodosCompanion(originalTodo, isInsert: false),
      ); // Revert local delete
      rethrow;
    }
  }

  /// Toggles a todo's completion status locally and then updates via API.
  /// Includes logic to update focused time and overdue status if provided.
  Future<void> toggleTodo(int id, {int? liveFocusedTime}) async {
    final originalTodo = await _localDb.getTodoById(id);
    if (originalTodo == null) {
      debugLog(
        'TodoRepository',
        'Attempted to toggle non-existent todo ID: $id',
      );
      return;
    }

    final focusedTime = liveFocusedTime ?? originalTodo.focusedTime;
    final plannedSeconds =
        (originalTodo.durationHours * 3600) +
        (originalTodo.durationMinutes * 60);

    final bool wasOverdue =
        (plannedSeconds > 0 && focusedTime > plannedSeconds) ||
        originalTodo.wasOverdue == 1;
    final int finalOverdueTime = wasOverdue
        ? (focusedTime - plannedSeconds).clamp(0, double.infinity).toInt()
        : originalTodo.overdueTime; // Preserve or calculate new overdue time

    final updatedLocalTodo = originalTodo.copyWith(
      completed: !originalTodo.completed,
      focusedTime: focusedTime,
      wasOverdue: wasOverdue ? 1 : 0,
      overdueTime: finalOverdueTime,
    );

    // Optimistic local update
    await _localDb.updateTodo(
      id,
      AppDatabase.toTodosCompanion(updatedLocalTodo, isInsert: false),
    );
    debugLog(
      'TodoRepository',
      'Optimistically toggled todo ID: $id to completed: ${updatedLocalTodo.completed}',
    );

    try {
      await _apiService.toggleTodoWithOverdue(
        id,
        wasOverdue: updatedLocalTodo.wasOverdue == 1,
        overdueTime: updatedLocalTodo.overdueTime,
      );
      debugLog('TodoRepository', 'Successfully toggled todo ID: $id on API');
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to toggle todo ID: $id on API: $e\n$st. Reverting local toggle.',
      );
      await _localDb.updateTodo(
        id,
        AppDatabase.toTodosCompanion(originalTodo, isInsert: false),
      ); // Revert local update
      rethrow;
    }
  }

  /// Toggles a todo with explicit overdue parameters locally and then updates via API.
  Future<void> toggleTodoWithOverdue(
    int id, {
    required bool wasOverdue,
    required int overdueTime,
  }) async {
    final originalTodo = await _localDb.getTodoById(id);
    if (originalTodo == null) {
      debugLog(
        'TodoRepository',
        'Attempted to toggle with overdue non-existent todo ID: $id',
      );
      return;
    }

    final updatedLocalTodo = originalTodo.copyWith(
      completed: !originalTodo.completed, // Always toggles completed status
      wasOverdue: wasOverdue ? 1 : 0,
      overdueTime: overdueTime,
    );

    await _localDb.updateTodo(
      id,
      AppDatabase.toTodosCompanion(updatedLocalTodo, isInsert: false),
    );
    debugLog(
      'TodoRepository',
      'Optimistically toggled todo ID: $id with overdue info locally',
    );

    try {
      await _apiService.toggleTodoWithOverdue(
        id,
        wasOverdue: wasOverdue,
        overdueTime: overdueTime,
      );
      debugLog(
        'TodoRepository',
        'Successfully toggled todo ID: $id with overdue info on API',
      );
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to toggle todo ID: $id with overdue info on API: $e\n$st. Reverting local toggle.',
      );
      await _localDb.updateTodo(
        id,
        AppDatabase.toTodosCompanion(originalTodo, isInsert: false),
      ); // Revert local update
      rethrow;
    }
  }

  /// Updates a todo's details locally and then attempts to update via API.
  Future<void> updateTodo({
    required int id,
    String? text,
    int? hours,
    int? minutes,
  }) async {
    final originalTodo = await _localDb.getTodoById(id);
    if (originalTodo == null) {
      debugLog(
        'TodoRepository',
        'Attempted to update non-existent todo ID: $id',
      );
      return;
    }

    final updatedLocalTodo = originalTodo.copyWith(
      text: text ?? originalTodo.text,
      durationHours: hours ?? originalTodo.durationHours,
      durationMinutes: minutes ?? originalTodo.durationMinutes,
    );

    await _localDb.updateTodo(
      id,
      AppDatabase.toTodosCompanion(updatedLocalTodo, isInsert: false),
    );
    debugLog('TodoRepository', 'Optimistically updated local todo ID: $id');

    try {
      await _apiService.updateTodo(
        id,
        text: text,
        hours: hours,
        minutes: minutes,
      );
      debugLog('TodoRepository', 'Successfully updated todo ID: $id on API');
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to update todo ID: $id on API: $e\n$st. Reverting local update.',
      );
      await _localDb.updateTodo(
        id,
        AppDatabase.toTodosCompanion(originalTodo, isInsert: false),
      ); // Revert local update
      rethrow;
    }
  }

  /// Marks a task as permanently overdue in the local database.
  Future<void> markTaskPermanentlyOverdue(
    int id, {
    required int overdueTime,
  }) async {
    final originalTodo = await _localDb.getTodoById(id);
    if (originalTodo == null) {
      debugLog(
        'TodoRepository',
        'Attempted to mark non-existent todo ID: $id as overdue',
      );
      return;
    }

    final updatedLocalTodo = originalTodo.copyWith(
      wasOverdue: 1,
      overdueTime: overdueTime,
    );
    await _localDb.updateTodo(
      id,
      AppDatabase.toTodosCompanion(updatedLocalTodo, isInsert: false),
    );
    debugLog(
      'TodoRepository',
      'Marked todo ID: $id as permanently overdue locally',
    );

    // No direct API call here as API focused_time update handles this indirectly
    // (This is an internal app state, not a direct API action in the current backend for the permanent overdue flag)
  }

  /// Clears all completed todos from the local database and then from the API.
  Future<void> clearCompleted() async {
    final completedTodos = (await _localDb.select(_localDb.todos).get())
        .where((entry) => entry.completed)
        .map(
          _localDb.mapTodoEntryToTodoModel,
        ) // Use public mapTodoEntryToTodoModel
        .toList();

    if (completedTodos.isEmpty) {
      debugLog('TodoRepository', 'No completed todos to clear.');
      return;
    }

    await _localDb.clearCompletedTodos(); // Optimistic local delete
    debugLog(
      'TodoRepository',
      'Optimistically cleared completed todos locally',
    );

    try {
      // Delete from API one by one as backend doesn't support bulk delete of completed
      await Future.wait(
        completedTodos.map((todo) => _apiService.deleteTodo(todo.id)),
      );
      debugLog(
        'TodoRepository',
        'Successfully cleared completed todos from API',
      );
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to clear completed todos from API: $e\n$st. Local and remote might be out of sync.',
      );
      // Reverting is complex here, better to re-sync or let user refresh to see actual state
      rethrow;
    }
  }

  /// Updates the focused time for a todo locally and then syncs with the API.
  /// This is critical for timer progress.
  Future<void> updateFocusTime(int id, int focusedTime) async {
    final originalTodo = await _localDb.getTodoById(id);
    if (originalTodo == null) {
      debugLog(
        'TodoRepository',
        'Attempted to update focus time for non-existent todo ID: $id',
      );
      return;
    }

    final updatedLocalTodo = originalTodo.copyWith(focusedTime: focusedTime);
    await _localDb.updateTodo(
      id,
      AppDatabase.toTodosCompanion(updatedLocalTodo, isInsert: false),
    );
    debugLog(
      'TodoRepository',
      'Updated focused time for todo ID: $id locally to $focusedTime',
    );

    try {
      await _apiService.updateFocusTime(id, focusedTime);
      debugLog(
        'TodoRepository',
        'Updated focused time for todo ID: $id on API',
      );
    } catch (e, st) {
      debugLog(
        'TodoRepository',
        'Failed to update focused time for todo ID: $id on API: $e\n$st. Local changes will be out of sync.',
      );
      // It might be better not to revert local, but flag as unsynced or retry
      rethrow;
    }
  }
}

// Extension to provide firstWhereOrNull for iterables.
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

// Provider for the AppDatabase, ensuring it's properly disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Provider for the TodoRepository, with dependencies injected.
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final localDb = ref.watch(databaseProvider);
  final apiService = ref.watch(
    apiServiceProvider,
  ); // Now properly uses the real ApiService
  return TodoRepository(localDb, apiService); // Pass dependencies
});
