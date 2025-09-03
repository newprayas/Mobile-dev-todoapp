// lib/core/data/todo_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/mock_api_service.dart';
import '../../features/todo/models/todo.dart';
import 'app_database.dart';
import 'todo_mutation_service.dart';
import 'todo_sync_service.dart';

/// Manages data operations for Todo items, acting as an abstraction layer
/// between the UI (via TodosNotifier) and data sources (local database, API).
/// Implements a local-first strategy with optimistic updates and API syncing.
class TodoRepository {
  final AppDatabase _localDb;
  final ApiService _apiService;
  late final TodoMutationService _mutations;
  late final TodoSyncService _sync;
  TodoRepository(this._localDb, this._apiService) {
    _mutations = TodoMutationService(_localDb, _apiService);
    _sync = TodoSyncService(_localDb, _apiService);
  }

  /// Provides a stream of all todos from the local database.
  ///
  /// This is the primary source of truth for the UI.
  Stream<List<Todo>> watchTodos() {
    return _localDb.watchAllTodos();
  }

  /// Fetches todos from the API and syncs them with the local database.
  ///
  /// This method is called on app startup or when a refresh is explicitly requested.
  Future<void> syncTodos() async => _sync.syncTodos();

  /// Adds a new todo, first to the local database, then attempts to sync with API.
  Future<void> addTodo(String text, int hours, int minutes) async =>
      _mutations.addTodo(text, hours, minutes);

  /// Deletes a todo locally and then attempts to delete from API.
  Future<void> deleteTodo(int id) async => _mutations.deleteTodo(id);

  /// Toggles a todo's completion status locally and then updates via API.
  /// Includes logic to update focused time and overdue status if provided.
  Future<void> toggleTodo(int id, {int? liveFocusedTime}) async =>
      _mutations.toggleTodo(id, liveFocusedTime: liveFocusedTime);

  /// Toggles a todo with explicit overdue parameters locally and then updates via API.
  Future<void> toggleTodoWithOverdue(int id, {required bool wasOverdue, required int overdueTime}) async {
    // Delegate using existing mutation logic; overdue handling embedded in toggle (wasOverdue/overdueTime currently not separately persisted via API here)
    await _mutations.toggleTodo(id, liveFocusedTime: null);
  }

  /// Updates a todo's details locally and then attempts to update via API.
  Future<void> updateTodo({required int id, String? text, int? hours, int? minutes}) async =>
      _mutations.updateTodo(id: id, text: text, hours: hours, minutes: minutes);

  /// Marks a task as permanently overdue in the local database.
  Future<void> markTaskPermanentlyOverdue(int id, {required int overdueTime}) async =>
      _mutations.markTaskPermanentlyOverdue(id, overdueTime: overdueTime);

  /// Clears all completed todos from the local database and then from the API.
  Future<void> clearCompleted() async => _mutations.clearCompleted();

  /// Updates the focused time for a todo locally and then syncs with the API.
  /// This is critical for timer progress.
  Future<void> updateFocusTime(int id, int focusedTime) async =>
      _mutations.updateFocusTime(id, focusedTime);
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
