import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

final String databasePath = 'database.db';

Database getDb() {
  final db = sqlite3.open(databasePath);
  return db;
}

Map<String, dynamic>? currentUser(Request request) {
  // First check for Bearer token authorization (for real Google auth)
  final authHeader = request.headers['authorization'];
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    final token = authHeader.substring(7);
    // In development, accept any bearer token as valid
    // In production, this would verify the JWT token
    print('DEBUG: Auth with bearer token: ${token.substring(0, 10)}...');
    return {'sub': 'google_user_$token', 'email': 'user@example.com'};
  }

  // Simple development fallback: if header 'x-user-id' present use it.
  final userId = request.headers['x-user-id'];
  if (userId != null && userId.isNotEmpty) {
    return {'sub': userId};
  }
  // If running in debug locally, allow a default dev user
  if (Platform.environment['DEBUG'] == '1') {
    return {'sub': 'dev'};
  }
  return null;
}

void ensureWasOverdueColumn(Database db) {
  // Check if columns exist in 'todos' and add if missing
  final result = db.select("PRAGMA table_info('todos');");
  final cols = result.map((r) => r['name'] as String).toList();
  if (!cols.contains('was_overdue')) {
    db.execute(
      "ALTER TABLE todos ADD COLUMN was_overdue INTEGER NOT NULL DEFAULT 0",
    );
  }
  if (!cols.contains('overdue_time')) {
    db.execute(
      "ALTER TABLE todos ADD COLUMN overdue_time INTEGER NOT NULL DEFAULT 0",
    );
  }
}

int maxSessionSeconds = 24 * 3600;

Response jsonResponse(Object? obj, {int status = 200}) {
  return Response(
    status,
    body: json.encode(obj),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> apiTodos(Request request) async {
  final user = currentUser(request);
  if (user == null) return jsonResponse([], status: 200);

  final db = getDb();
  ensureWasOverdueColumn(db);
  final rows = db.select('SELECT * FROM todos WHERE user_id = ?', [
    user['sub'],
  ]);
  final result = rows.map((r) {
    return {
      'id': r['id'],
      'user_id': r['user_id'],
      'text': r['text'],
      'completed': r['completed'],
      'duration_hours': r['duration_hours'],
      'duration_minutes': r['duration_minutes'],
      'focused_time': r['focused_time'],
      'was_overdue': r['was_overdue'] ?? 0,
      'overdue_time': r['overdue_time'] ?? 0,
    };
  }).toList();
  db.dispose();
  return jsonResponse(result);
}

Future<Response> authWithIdToken(Request request) async {
  print('DEBUG: Auth endpoint called');
  try {
    final payload =
        json.decode(await request.readAsString()) as Map<String, dynamic>;
    final idToken = payload['id_token'] as String?;

    if (idToken == null || idToken.isEmpty) {
      return jsonResponse({'error': 'Missing id_token'}, status: 400);
    }

    print(
        'DEBUG: Received ID token: ${idToken.length > 20 ? idToken.substring(0, 20) : idToken}...');

    // In development mode, accept any ID token and generate a simple server token
    // In production, you would verify the Google ID token here
    final serverToken = 'server_token_${DateTime.now().millisecondsSinceEpoch}';

    print('DEBUG: Generated server token: $serverToken');

    // Return the server token for the client to store and use
    return jsonResponse({
      'token': serverToken,
      'user': {
        'id': 'google_user_dev',
        'email': 'dev@example.com',
        'name': 'Dev User'
      }
    });
  } catch (e) {
    print('DEBUG: Auth error: $e');
    return jsonResponse({'error': 'Invalid request'}, status: 400);
  }
}

Future<Response> addTodo(Request request) async {
  final user = currentUser(request);
  if (user == null) return jsonResponse({'error': 'Unauthorized'}, status: 401);
  final payload =
      json.decode(await request.readAsString()) as Map<String, dynamic>;
  final todoText = (payload['text'] as String?)?.trim() ?? '';
  final durationHours =
      int.tryParse((payload['duration_hours'] ?? '0').toString()) ?? 0;
  final durationMinutes =
      int.tryParse((payload['duration_minutes'] ?? '0').toString()) ?? 0;
  if (todoText.isEmpty)
    return jsonResponse({'error': 'Text is required'}, status: 400);

  final db = getDb();
  final stmt = db.prepare(
    'INSERT INTO todos (user_id, text, duration_hours, duration_minutes, focused_time, was_overdue, overdue_time) VALUES (?, ?, ?, ?, 0, 0, 0)',
  );
  stmt.execute([user['sub'], todoText, durationHours, durationMinutes]);
  final newId = db.lastInsertRowId;
  stmt.dispose();
  db.dispose();

  return jsonResponse({
    'id': newId,
    'text': todoText,
    'completed': 0,
    'duration_hours': durationHours,
    'duration_minutes': durationMinutes,
    'focused_time': 0,
    'was_overdue': 0,
    'overdue_time': 0,
  });
}

Future<Response> deleteTodo(Request request) async {
  final user = currentUser(request);
  if (user == null) return jsonResponse({'error': 'Unauthorized'}, status: 401);
  final payload =
      json.decode(await request.readAsString()) as Map<String, dynamic>;
  final todoId = payload['id'];
  final db = getDb();
  final stmt = db.prepare('DELETE FROM todos WHERE id = ? AND user_id = ?');
  stmt.execute([todoId, user['sub']]);
  stmt.dispose();
  db.dispose();
  return jsonResponse({'result': 'success'});
}

Future<Response> toggleTodo(Request request) async {
  final user = currentUser(request);
  if (user == null) return jsonResponse({'error': 'Unauthorized'}, status: 401);
  final payload =
      json.decode(await request.readAsString()) as Map<String, dynamic>;
  final todoId = payload['id'];
  final db = getDb();
  final row = db.select(
    'SELECT completed FROM todos WHERE id = ? AND user_id = ?',
    [todoId, user['sub']],
  );
  if (row.isNotEmpty) {
    final current = row.first['completed'] as int;
    final newVal = current == 0 ? 1 : 0;
    final stmt = db.prepare(
      'UPDATE todos SET completed = ? WHERE id = ? AND user_id = ?',
    );
    stmt.execute([newVal, todoId, user['sub']]);
    stmt.dispose();
  }
  db.dispose();
  return jsonResponse({'result': 'success'});
}

Future<Response> updateTodo(Request request) async {
  final user = currentUser(request);
  if (user == null) return jsonResponse({'error': 'Unauthorized'}, status: 401);
  final payload =
      json.decode(await request.readAsString()) as Map<String, dynamic>;
  final todoId = payload['id'];
  if (todoId == null) return jsonResponse({'error': 'Missing id'}, status: 400);
  final db = getDb();
  if (payload.containsKey('text')) {
    final stmt = db.prepare(
      'UPDATE todos SET text = ? WHERE id = ? AND user_id = ?',
    );
    stmt.execute([payload['text'], todoId, user['sub']]);
    stmt.dispose();
  }
  if (payload.containsKey('duration_hours')) {
    final stmt = db.prepare(
      'UPDATE todos SET duration_hours = ? WHERE id = ? AND user_id = ?',
    );
    stmt.execute([payload['duration_hours'], todoId, user['sub']]);
    stmt.dispose();
  }
  if (payload.containsKey('duration_minutes')) {
    final stmt = db.prepare(
      'UPDATE todos SET duration_minutes = ? WHERE id = ? AND user_id = ?',
    );
    stmt.execute([payload['duration_minutes'], todoId, user['sub']]);
    stmt.dispose();
  }
  db.dispose();
  return jsonResponse({'result': 'success'});
}

Future<Response> updateFocusTime(Request request) async {
  final user = currentUser(request);
  if (user == null) return jsonResponse({'error': 'Unauthorized'}, status: 401);
  final payload =
      json.decode(await request.readAsString()) as Map<String, dynamic>;
  final todoId = payload['id'];
  int ft = 0;
  try {
    ft = int.tryParse((payload['focused_time'] ?? '0').toString()) ?? 0;
  } catch (_) {
    ft = 0;
  }
  if (ft > 1000000) ft = ft ~/ 1000;
  if (ft > maxSessionSeconds) ft = maxSessionSeconds;

  final db = getDb();
  final stmt = db.prepare(
    'UPDATE todos SET focused_time = ? WHERE id = ? AND user_id = ?',
  );
  stmt.execute([ft, todoId, user['sub']]);
  stmt.dispose();

  final rows = db.select(
    'SELECT duration_hours, duration_minutes FROM todos WHERE id = ? AND user_id = ?',
    [todoId, user['sub']],
  );
  int wasOverdue = 0;
  int overdueTime = 0;
  if (rows.isNotEmpty) {
    final row = rows.first;
    final durationHours = row['duration_hours'] as int? ?? 0;
    final durationMinutes = row['duration_minutes'] as int? ?? 0;
    final totalSeconds = (durationHours * 3600) + (durationMinutes * 60);
    if (totalSeconds > 0 && ft > totalSeconds) {
      wasOverdue = 1;
      overdueTime = ft - totalSeconds;
    }
  }
  final stmt2 = db.prepare(
    'UPDATE todos SET was_overdue = ?, overdue_time = ? WHERE id = ? AND user_id = ?',
  );
  stmt2.execute([wasOverdue, overdueTime, todoId, user['sub']]);
  stmt2.dispose();
  db.dispose();

  return jsonResponse({
    'result': 'success',
    'was_overdue': wasOverdue,
    'overdue_time': overdueTime,
    'focused_time': ft,
  });
}

void main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final port = int.tryParse(Platform.environment['PORT'] ?? '5000') ?? 5000;

  final router = Router();

  router.post('/api/auth', (Request request) => authWithIdToken(request));
  router.get('/api/todos', (Request request) => apiTodos(request));
  router.post('/add', (Request request) => addTodo(request));
  router.post('/delete', (Request request) => deleteTodo(request));
  router.post('/toggle', (Request request) => toggleTodo(request));
  router.post('/update', (Request request) => updateTodo(request));
  router.post(
    '/update_focus_time',
    (Request request) => updateFocusTime(request),
  );
  router.get('/health', (Request request) => jsonResponse({'status': 'ok'}));

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router);

  final server = await io.serve(handler, ip, port);
  print('Server listening on http://${server.address.host}:${server.port}');
}
