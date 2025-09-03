import 'package:drift/drift.dart' as drift;
import 'package:logger/logger.dart';
import '../../features/todo/models/todo.dart';
import 'app_database.dart';
import '../services/api_service.dart';

/// Handles full sync from remote API to local DB (one-way authoritative remote).
class TodoSyncService {
  final AppDatabase _db;
  final ApiService _api;
  final Logger logger = Logger();

  TodoSyncService(this._db, this._api);

  Future<void> syncTodos() async {
    logger.i('[TodoSyncService] Sync start');
    final remoteData = await _api.fetchTodos();
    final List<Todo> remoteTodos = remoteData.map((e) {
      final Map<String, dynamic> raw = Map<String, dynamic>.from(e);
      return Todo(
        id: raw['id'] is int ? raw['id'] : int.parse('${raw['id']}'),
        userId: raw['user_id'] ?? raw['userId'] ?? '',
        text: raw['text'] ?? '',
        completed: (raw['completed'] == 1 || raw['completed'] == true),
        durationHours: _asInt(raw['duration_hours']),
        durationMinutes: _asInt(raw['duration_minutes']),
        focusedTime: _asInt(raw['focused_time']),
        wasOverdue: _asInt(raw['was_overdue']),
        overdueTime: _asInt(raw['overdue_time']),
        createdAt: DateTime.parse(raw['created_at']),
      );
    }).toList();

    final localRows = await _db.select(_db.todos).get();
    final localTodos = localRows.map(_db.mapTodoEntryToTodoModel).toList();
    final remoteIds = remoteTodos.map((t) => t.id).toSet();

    // Delete local not on server
    for (final local in localTodos) {
      if (!remoteIds.contains(local.id)) {
        await _db.deleteTodo(local.id);
      }
    }

    // Upsert remote
    for (final remote in remoteTodos) {
      final existing = localTodos.where((t) => t.id == remote.id).toList();
      if (existing.isEmpty) {
        final companion = AppDatabase.toTodosCompanion(
          remote,
          isInsert: true,
        ).copyWith(id: const drift.Value.absent());
        await _db.insertTodo(companion);
      } else {
        final current = existing.first;
        if (!_equivalent(current, remote)) {
          await _db.updateTodo(
            remote.id,
            AppDatabase.toTodosCompanion(remote, isInsert: false),
          );
        }
      }
    }
    logger.i('[TodoSyncService] Sync complete');
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.parse('$v');
  }

  bool _equivalent(Todo a, Todo b) {
    return a.text == b.text &&
        a.completed == b.completed &&
        a.durationHours == b.durationHours &&
        a.durationMinutes == b.durationMinutes &&
        a.focusedTime == b.focusedTime &&
        a.wasOverdue == b.wasOverdue &&
        a.overdueTime == b.overdueTime &&
        a.createdAt == b.createdAt;
  }
}
