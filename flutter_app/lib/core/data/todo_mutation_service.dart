import 'package:drift/drift.dart';
import '../../features/todo/models/todo.dart';
import '../utils/debug_logger.dart';
import 'app_database.dart';
import '../services/api_service.dart';

/// Handles add/update/delete/toggle mutations with optimistic logic.
class TodoMutationService {
  final AppDatabase _db;
  final ApiService _api;
  TodoMutationService(this._db, this._api);

  Future<Todo> addTodo(String text, int hours, int minutes) async {
    final Todo optimistic = Todo(
      id: -1,
      userId: _api.devUserId,
      text: text,
      completed: false,
      durationHours: hours,
      durationMinutes: minutes,
      focusedTime: 0,
      wasOverdue: 0,
      overdueTime: 0,
      createdAt: DateTime.now(),
    );
    final inserted = await _db.insertTodo(
      AppDatabase.toTodosCompanion(optimistic, isInsert: true)
          .copyWith(id: const Value.absent()),
    );
    debugLog('TodoMutationService', 'Optimistic add local id=${inserted.id}');
    try {
      final data = await _api.addTodo(text, hours, minutes);
      final Todo serverTodo = Todo(
        id: data['id'],
        userId: data['user_id'],
        text: data['text'],
        completed: data['completed'] == 1,
        durationHours: data['duration_hours'],
        durationMinutes: data['duration_minutes'],
        focusedTime: data['focused_time'],
        wasOverdue: data['was_overdue'] ?? 0,
        overdueTime: data['overdue_time'] ?? 0,
        createdAt: DateTime.parse(data['created_at']),
      );
      await _db.deleteTodo(inserted.id);
      await _db.insertTodo(AppDatabase.toTodosCompanion(serverTodo, isInsert: false));
      return serverTodo;
    } catch (e, st) {
      debugLog('TodoMutationService', 'API add failed, reverting: $e\n$st');
      await _db.deleteTodo(inserted.id);
      rethrow;
    }
  }

  Future<void> deleteTodo(int id) async {
    final original = await _db.getTodoById(id);
    if (original == null) return;
    await _db.deleteTodo(id);
    try {
      await _api.deleteTodo(id);
    } catch (e, st) {
      debugLog('TodoMutationService', 'Delete revert due API fail: $e\n$st');
      await _db.insertTodo(AppDatabase.toTodosCompanion(original, isInsert: false));
      rethrow;
    }
  }

  Future<void> toggleTodo(int id, {int? liveFocusedTime}) async {
    final original = await _db.getTodoById(id);
    if (original == null) return;
    final int focused = liveFocusedTime ?? original.focusedTime;
    final int planned = (original.durationHours * 3600) + (original.durationMinutes * 60);
    final bool overdue = (planned > 0 && focused > planned) || original.wasOverdue == 1;
    final int overdueTime = overdue ? (focused - planned).clamp(0, double.infinity).toInt() : original.overdueTime;
    final updated = original.copyWith(
      completed: !original.completed,
      focusedTime: focused,
      wasOverdue: overdue ? 1 : 0,
      overdueTime: overdueTime,
    );
    await _db.updateTodo(id, AppDatabase.toTodosCompanion(updated, isInsert: false));
    try {
      await _api.toggleTodoWithOverdue(id, wasOverdue: overdue, overdueTime: overdueTime);
    } catch (e, st) {
      debugLog('TodoMutationService', 'Toggle revert API fail: $e\n$st');
      await _db.updateTodo(id, AppDatabase.toTodosCompanion(original, isInsert: false));
      rethrow;
    }
  }

  Future<void> updateTodo({required int id, String? text, int? hours, int? minutes}) async {
    final original = await _db.getTodoById(id);
    if (original == null) return;
    final updated = original.copyWith(
      text: text ?? original.text,
      durationHours: hours ?? original.durationHours,
      durationMinutes: minutes ?? original.durationMinutes,
    );
    await _db.updateTodo(id, AppDatabase.toTodosCompanion(updated, isInsert: false));
    try {
      await _api.updateTodo(id, text: text, hours: hours, minutes: minutes);
    } catch (e, st) {
      debugLog('TodoMutationService', 'Update revert API fail: $e\n$st');
      await _db.updateTodo(id, AppDatabase.toTodosCompanion(original, isInsert: false));
      rethrow;
    }
  }

  Future<void> markTaskPermanentlyOverdue(int id, {required int overdueTime}) async {
    final original = await _db.getTodoById(id);
    if (original == null) return;
    final updated = original.copyWith(wasOverdue: 1, overdueTime: overdueTime);
    await _db.updateTodo(id, AppDatabase.toTodosCompanion(updated, isInsert: false));
  }

  Future<void> clearCompleted() async {
    final all = await _db.select(_db.todos).get();
    final completed = all.where((e) => e.completed).map(_db.mapTodoEntryToTodoModel).toList();
    if (completed.isEmpty) return;
    await _db.clearCompletedTodos();
    try {
      await Future.wait(completed.map((t) => _api.deleteTodo(t.id)));
    } catch (e, st) {
      debugLog('TodoMutationService', 'Clear completed remote fail: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateFocusTime(int id, int focusedTime) async {
    final original = await _db.getTodoById(id);
    if (original == null) return;
    final updated = original.copyWith(focusedTime: focusedTime);
    await _db.updateTodo(id, AppDatabase.toTodosCompanion(updated, isInsert: false));
    try {
      await _api.updateFocusTime(id, focusedTime);
    } catch (e, st) {
      debugLog('TodoMutationService', 'Focus time sync fail: $e\n$st');
      rethrow;
    }
  }
}
