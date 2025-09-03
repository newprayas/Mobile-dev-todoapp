import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_timer_app/core/data/todo_repository.dart';
import 'package:focus_timer_app/core/data/app_database.dart';
import 'package:focus_timer_app/core/services/mock_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TodoRepository repo;

  setUp(() {
  db = AppDatabase();
  repo = TodoRepository(db, MockApiService('http://localhost:5000'));
  });

  tearDown(() async {
    await db.close();
  });

  group('TodoRepository', () {
    test('addTodo inserts and syncs (optimistic then replaces)', () async {
      await repo.addTodo('Test Task', 0, 30);
      final todos = await db.select(db.todos).get();
      expect(todos.isNotEmpty, true);
    });

    test('toggleTodo flips completed flag', () async {
      await repo.addTodo('Toggle Task', 0, 25);
      final inserted = await db.select(db.todos).get();
      final id = inserted.first.id;
      await repo.toggleTodo(id);
      final after = await db.getTodoById(id);
      expect(after?.completed, true);
    });
  });
}
