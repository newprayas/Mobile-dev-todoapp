import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

final String databasePath = 'database.db';

Database getDb() => sqlite3.open(databasePath);

void initDb() {
  final dbFile = File('../schema.sql');
  if (!dbFile.existsSync()) {
    print('schema.sql not found at ../schema.sql');
    exit(1);
  }
  final sql = dbFile.readAsStringSync();
  final db = getDb();
  db.execute(sql);
  db.dispose();
  print('Initialized the database.');
}

void fixFocusedTimes() {
  final db = getDb();
  final rows = db.select('SELECT id, focused_time, overdue_time FROM todos');
  var fixed = 0;
  for (final r in rows) {
    final tid = r['id'] as int;
    var ft = (r['focused_time'] as int?) ?? 0;
    var ot = (r['overdue_time'] as int?) ?? 0;
    if (ft > 1000000) {
      final newFt = ft ~/ 1000;
      final newOt = (ot != 0 && ot > 1000000) ? (ot ~/ 1000) : ot;
      final meta = db.select(
        'SELECT duration_hours, duration_minutes FROM todos WHERE id = ?',
        [tid],
      );
      var dh = 0;
      var dm = 0;
      if (meta.isNotEmpty) {
        dh = (meta.first['duration_hours'] as int?) ?? 0;
        dm = (meta.first['duration_minutes'] as int?) ?? 0;
      }
      final total = (dh * 3600) + (dm * 60);
      final wasOverdue = (total > 0 && newFt > total) ? 1 : 0;
      final overdueTime = (total > 0)
          ? ((newFt > total) ? (newFt - total) : 0)
          : newOt;
      final stmt = db.prepare(
        'UPDATE todos SET focused_time = ?, overdue_time = ?, was_overdue = ? WHERE id = ?',
      );
      stmt.execute([newFt, overdueTime, wasOverdue, tid]);
      stmt.dispose();
      fixed += 1;
    }
  }
  db.dispose();
  print('Fixed $fixed todos.');
}

void printUsage() {
  print('Usage: dart run bin/cli.dart <command>');
  print('Commands:');
  print('  init-db           Initialize the database using ../schema.sql');
  print(
    '  fix-focused-times Fix obviously bad focused_time/overdue_time values',
  );
}

void main(List<String> args) {
  if (args.isEmpty) {
    printUsage();
    exit(0);
  }
  final cmd = args.first;
  if (cmd == 'init-db') {
    initDb();
  } else if (cmd == 'fix-focused-times') {
    fixFocusedTimes();
  } else {
    printUsage();
  }
}
