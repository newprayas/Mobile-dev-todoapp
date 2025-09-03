// lib/core/data/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../features/todo/models/todo.dart'
    as todo_model; // Alias original Todo model

part 'app_database.g.dart'; // Drift will generate this file

/// Represents the 'todos' table in the database.
///
/// This table stores all todo items with their details, including planned duration,
/// focused time, and overdue status.
@DataClassName(
  'TodoEntry',
) // Naming the generated class to avoid conflict with existing Todo model
class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get taskText =>
      text()(); // Renamed from 'text' to avoid conflict with inherited method
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get durationHours => integer().withDefault(const Constant(0))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  IntColumn get focusedTime => integer().withDefault(const Constant(0))();
  IntColumn get wasOverdue => integer().withDefault(const Constant(0))();
  IntColumn get overdueTime => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Primary key is automatically handled by integer().autoIncrement()
}

/// The main database class for the application, using drift.
///
/// This class provides typed access to the [Todos] table and facilitates
/// CRUD operations.
@DriftDatabase(tables: [Todos])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory constructor for tests (does not hit file system or plugins).
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1; // Increment this when making schema changes

  /// Provides a stream of all todo entries ordered by creation time (descending).
  ///
  /// This allows UI components to reactively update when the todo list changes.
  Stream<List<todo_model.Todo>> watchAllTodos() {
    return (select(todos)..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch()
        .map((rows) => rows.map(mapTodoEntryToTodoModel).toList());
  }

  /// Retrieves a single todo entry by its ID.
  Future<todo_model.Todo?> getTodoById(int id) {
    return (select(todos)..where((t) => t.id.equals(id)))
        .getSingleOrNull()
        .then((entry) => entry != null ? mapTodoEntryToTodoModel(entry) : null);
  }

  /// Inserts a new todo into the database.
  Future<todo_model.Todo> insertTodo(TodosCompanion entry) async {
    final id = await into(todos).insert(entry);
    return (await getTodoById(id))!; // Retrieve the full todo to return
  }

  /// Updates an existing todo in the database.
  Future<bool> updateTodo(int id, TodosCompanion entry) {
    return (update(todos)..where((t) => t.id.equals(id)))
        .write(entry)
        .then((affectedRows) => affectedRows > 0);
  }

  /// Deletes a todo from the database by its ID.
  Future<int> deleteTodo(int id) {
    return (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all completed todos from the database.
  Future<void> clearCompletedTodos() {
    return (delete(todos)..where((t) => t.completed.equals(true))).go();
  }

  /// Maps a generated `TodoEntry` from drift to our application's `Todo` model.
  todo_model.Todo mapTodoEntryToTodoModel(TodoEntry entry) {
    return todo_model.Todo(
      id: entry.id,
      userId: entry.userId,
      text: entry.taskText, // Updated to use taskText
      completed: entry.completed,
      durationHours: entry.durationHours,
      durationMinutes: entry.durationMinutes,
      focusedTime: entry.focusedTime,
      wasOverdue: entry.wasOverdue,
      overdueTime: entry.overdueTime,
      createdAt: entry.createdAt,
    );
  }

  /// Helper to convert our `Todo` model back to a `TodosCompanion` for updates/inserts.
  static TodosCompanion toTodosCompanion(
    todo_model.Todo todo, {
    bool isInsert = false,
  }) {
    return TodosCompanion(
      id: Value(todo.id), // For updates, use Value.absent() for insert
      userId: Value(todo.userId),
      taskText: Value(todo.text), // Updated to use taskText
      completed: Value(todo.completed),
      durationHours: Value(todo.durationHours),
      durationMinutes: Value(todo.durationMinutes),
      focusedTime: Value(todo.focusedTime),
      wasOverdue: Value(todo.wasOverdue),
      overdueTime: Value(todo.overdueTime),
      createdAt: isInsert
          ? Value.absent()
          : Value(todo.createdAt), // createdAt is auto for inserts
    );
  }
}

/// Helper function to open the database connection.
///
/// This abstracts the platform-specific details of opening a SQLite database.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
