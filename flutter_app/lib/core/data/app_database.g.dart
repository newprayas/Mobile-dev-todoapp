// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TodosTable extends Todos with TableInfo<$TodosTable, TodoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskTextMeta = const VerificationMeta(
    'taskText',
  );
  @override
  late final GeneratedColumn<String> taskText = GeneratedColumn<String>(
    'task_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _durationHoursMeta = const VerificationMeta(
    'durationHours',
  );
  @override
  late final GeneratedColumn<int> durationHours = GeneratedColumn<int>(
    'duration_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _focusedTimeMeta = const VerificationMeta(
    'focusedTime',
  );
  @override
  late final GeneratedColumn<int> focusedTime = GeneratedColumn<int>(
    'focused_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wasOverdueMeta = const VerificationMeta(
    'wasOverdue',
  );
  @override
  late final GeneratedColumn<int> wasOverdue = GeneratedColumn<int>(
    'was_overdue',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _overdueTimeMeta = const VerificationMeta(
    'overdueTime',
  );
  @override
  late final GeneratedColumn<int> overdueTime = GeneratedColumn<int>(
    'overdue_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    taskText,
    completed,
    durationHours,
    durationMinutes,
    focusedTime,
    wasOverdue,
    overdueTime,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('task_text')) {
      context.handle(
        _taskTextMeta,
        taskText.isAcceptableOrUnknown(data['task_text']!, _taskTextMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTextMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('duration_hours')) {
      context.handle(
        _durationHoursMeta,
        durationHours.isAcceptableOrUnknown(
          data['duration_hours']!,
          _durationHoursMeta,
        ),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('focused_time')) {
      context.handle(
        _focusedTimeMeta,
        focusedTime.isAcceptableOrUnknown(
          data['focused_time']!,
          _focusedTimeMeta,
        ),
      );
    }
    if (data.containsKey('was_overdue')) {
      context.handle(
        _wasOverdueMeta,
        wasOverdue.isAcceptableOrUnknown(data['was_overdue']!, _wasOverdueMeta),
      );
    }
    if (data.containsKey('overdue_time')) {
      context.handle(
        _overdueTimeMeta,
        overdueTime.isAcceptableOrUnknown(
          data['overdue_time']!,
          _overdueTimeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      taskText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_text'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      durationHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_hours'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      focusedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focused_time'],
      )!,
      wasOverdue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}was_overdue'],
      )!,
      overdueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overdue_time'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class TodoEntry extends DataClass implements Insertable<TodoEntry> {
  final int id;
  final String userId;
  final String taskText;
  final bool completed;
  final int durationHours;
  final int durationMinutes;
  final int focusedTime;
  final int wasOverdue;
  final int overdueTime;
  final DateTime createdAt;
  const TodoEntry({
    required this.id,
    required this.userId,
    required this.taskText,
    required this.completed,
    required this.durationHours,
    required this.durationMinutes,
    required this.focusedTime,
    required this.wasOverdue,
    required this.overdueTime,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['task_text'] = Variable<String>(taskText);
    map['completed'] = Variable<bool>(completed);
    map['duration_hours'] = Variable<int>(durationHours);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['focused_time'] = Variable<int>(focusedTime);
    map['was_overdue'] = Variable<int>(wasOverdue);
    map['overdue_time'] = Variable<int>(overdueTime);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      userId: Value(userId),
      taskText: Value(taskText),
      completed: Value(completed),
      durationHours: Value(durationHours),
      durationMinutes: Value(durationMinutes),
      focusedTime: Value(focusedTime),
      wasOverdue: Value(wasOverdue),
      overdueTime: Value(overdueTime),
      createdAt: Value(createdAt),
    );
  }

  factory TodoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoEntry(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      taskText: serializer.fromJson<String>(json['taskText']),
      completed: serializer.fromJson<bool>(json['completed']),
      durationHours: serializer.fromJson<int>(json['durationHours']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      focusedTime: serializer.fromJson<int>(json['focusedTime']),
      wasOverdue: serializer.fromJson<int>(json['wasOverdue']),
      overdueTime: serializer.fromJson<int>(json['overdueTime']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'taskText': serializer.toJson<String>(taskText),
      'completed': serializer.toJson<bool>(completed),
      'durationHours': serializer.toJson<int>(durationHours),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'focusedTime': serializer.toJson<int>(focusedTime),
      'wasOverdue': serializer.toJson<int>(wasOverdue),
      'overdueTime': serializer.toJson<int>(overdueTime),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoEntry copyWith({
    int? id,
    String? userId,
    String? taskText,
    bool? completed,
    int? durationHours,
    int? durationMinutes,
    int? focusedTime,
    int? wasOverdue,
    int? overdueTime,
    DateTime? createdAt,
  }) => TodoEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    taskText: taskText ?? this.taskText,
    completed: completed ?? this.completed,
    durationHours: durationHours ?? this.durationHours,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    focusedTime: focusedTime ?? this.focusedTime,
    wasOverdue: wasOverdue ?? this.wasOverdue,
    overdueTime: overdueTime ?? this.overdueTime,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoEntry copyWithCompanion(TodosCompanion data) {
    return TodoEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      taskText: data.taskText.present ? data.taskText.value : this.taskText,
      completed: data.completed.present ? data.completed.value : this.completed,
      durationHours: data.durationHours.present
          ? data.durationHours.value
          : this.durationHours,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      focusedTime: data.focusedTime.present
          ? data.focusedTime.value
          : this.focusedTime,
      wasOverdue: data.wasOverdue.present
          ? data.wasOverdue.value
          : this.wasOverdue,
      overdueTime: data.overdueTime.present
          ? data.overdueTime.value
          : this.overdueTime,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('taskText: $taskText, ')
          ..write('completed: $completed, ')
          ..write('durationHours: $durationHours, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('focusedTime: $focusedTime, ')
          ..write('wasOverdue: $wasOverdue, ')
          ..write('overdueTime: $overdueTime, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    taskText,
    completed,
    durationHours,
    durationMinutes,
    focusedTime,
    wasOverdue,
    overdueTime,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.taskText == this.taskText &&
          other.completed == this.completed &&
          other.durationHours == this.durationHours &&
          other.durationMinutes == this.durationMinutes &&
          other.focusedTime == this.focusedTime &&
          other.wasOverdue == this.wasOverdue &&
          other.overdueTime == this.overdueTime &&
          other.createdAt == this.createdAt);
}

class TodosCompanion extends UpdateCompanion<TodoEntry> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> taskText;
  final Value<bool> completed;
  final Value<int> durationHours;
  final Value<int> durationMinutes;
  final Value<int> focusedTime;
  final Value<int> wasOverdue;
  final Value<int> overdueTime;
  final Value<DateTime> createdAt;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.taskText = const Value.absent(),
    this.completed = const Value.absent(),
    this.durationHours = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.focusedTime = const Value.absent(),
    this.wasOverdue = const Value.absent(),
    this.overdueTime = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodosCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String taskText,
    this.completed = const Value.absent(),
    this.durationHours = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.focusedTime = const Value.absent(),
    this.wasOverdue = const Value.absent(),
    this.overdueTime = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : userId = Value(userId),
       taskText = Value(taskText);
  static Insertable<TodoEntry> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? taskText,
    Expression<bool>? completed,
    Expression<int>? durationHours,
    Expression<int>? durationMinutes,
    Expression<int>? focusedTime,
    Expression<int>? wasOverdue,
    Expression<int>? overdueTime,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (taskText != null) 'task_text': taskText,
      if (completed != null) 'completed': completed,
      if (durationHours != null) 'duration_hours': durationHours,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (focusedTime != null) 'focused_time': focusedTime,
      if (wasOverdue != null) 'was_overdue': wasOverdue,
      if (overdueTime != null) 'overdue_time': overdueTime,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodosCompanion copyWith({
    Value<int>? id,
    Value<String>? userId,
    Value<String>? taskText,
    Value<bool>? completed,
    Value<int>? durationHours,
    Value<int>? durationMinutes,
    Value<int>? focusedTime,
    Value<int>? wasOverdue,
    Value<int>? overdueTime,
    Value<DateTime>? createdAt,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskText: taskText ?? this.taskText,
      completed: completed ?? this.completed,
      durationHours: durationHours ?? this.durationHours,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      focusedTime: focusedTime ?? this.focusedTime,
      wasOverdue: wasOverdue ?? this.wasOverdue,
      overdueTime: overdueTime ?? this.overdueTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (taskText.present) {
      map['task_text'] = Variable<String>(taskText.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (durationHours.present) {
      map['duration_hours'] = Variable<int>(durationHours.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (focusedTime.present) {
      map['focused_time'] = Variable<int>(focusedTime.value);
    }
    if (wasOverdue.present) {
      map['was_overdue'] = Variable<int>(wasOverdue.value);
    }
    if (overdueTime.present) {
      map['overdue_time'] = Variable<int>(overdueTime.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('taskText: $taskText, ')
          ..write('completed: $completed, ')
          ..write('durationHours: $durationHours, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('focusedTime: $focusedTime, ')
          ..write('wasOverdue: $wasOverdue, ')
          ..write('overdueTime: $overdueTime, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TodosTable todos = $TodosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [todos];
}

typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      Value<int> id,
      required String userId,
      required String taskText,
      Value<bool> completed,
      Value<int> durationHours,
      Value<int> durationMinutes,
      Value<int> focusedTime,
      Value<int> wasOverdue,
      Value<int> overdueTime,
      Value<DateTime> createdAt,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<int> id,
      Value<String> userId,
      Value<String> taskText,
      Value<bool> completed,
      Value<int> durationHours,
      Value<int> durationMinutes,
      Value<int> focusedTime,
      Value<int> wasOverdue,
      Value<int> overdueTime,
      Value<DateTime> createdAt,
    });

class $$TodosTableFilterComposer extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskText => $composableBuilder(
    column: $table.taskText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationHours => $composableBuilder(
    column: $table.durationHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusedTime => $composableBuilder(
    column: $table.focusedTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wasOverdue => $composableBuilder(
    column: $table.wasOverdue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overdueTime => $composableBuilder(
    column: $table.overdueTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodosTableOrderingComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskText => $composableBuilder(
    column: $table.taskText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationHours => $composableBuilder(
    column: $table.durationHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusedTime => $composableBuilder(
    column: $table.focusedTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wasOverdue => $composableBuilder(
    column: $table.wasOverdue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overdueTime => $composableBuilder(
    column: $table.overdueTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get taskText =>
      $composableBuilder(column: $table.taskText, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get durationHours => $composableBuilder(
    column: $table.durationHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusedTime => $composableBuilder(
    column: $table.focusedTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wasOverdue => $composableBuilder(
    column: $table.wasOverdue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overdueTime => $composableBuilder(
    column: $table.overdueTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodosTable,
          TodoEntry,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (TodoEntry, BaseReferences<_$AppDatabase, $TodosTable, TodoEntry>),
          TodoEntry,
          PrefetchHooks Function()
        > {
  $$TodosTableTableManager(_$AppDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> taskText = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> durationHours = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> focusedTime = const Value.absent(),
                Value<int> wasOverdue = const Value.absent(),
                Value<int> overdueTime = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                userId: userId,
                taskText: taskText,
                completed: completed,
                durationHours: durationHours,
                durationMinutes: durationMinutes,
                focusedTime: focusedTime,
                wasOverdue: wasOverdue,
                overdueTime: overdueTime,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String userId,
                required String taskText,
                Value<bool> completed = const Value.absent(),
                Value<int> durationHours = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> focusedTime = const Value.absent(),
                Value<int> wasOverdue = const Value.absent(),
                Value<int> overdueTime = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                userId: userId,
                taskText: taskText,
                completed: completed,
                durationHours: durationHours,
                durationMinutes: durationMinutes,
                focusedTime: focusedTime,
                wasOverdue: wasOverdue,
                overdueTime: overdueTime,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodosTable,
      TodoEntry,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (TodoEntry, BaseReferences<_$AppDatabase, $TodosTable, TodoEntry>),
      TodoEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
}
