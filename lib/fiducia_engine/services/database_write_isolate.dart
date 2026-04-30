import 'dart:isolate';

import 'package:sqflite/sqflite.dart';

import '../core/result.dart';
import 'database_paths.dart';

/// Insertions groupées `locations` dans un isolate (connexion SQLite séparée, compatible WAL).
Future<Result<int, String>> flushLocationRowsInIsolate({
  required String databasePath,
  required List<Map<String, Object?>> rows,
}) async {
  if (rows.isEmpty) {
    return const Success<int, String>(0);
  }
  try {
    final int inserted = await Isolate.run(() => _insertLocationBatch(databasePath, rows));
    return Success<int, String>(inserted);
  } catch (e, st) {
    return Failure<int, String>('Isolate DB: $e\n$st');
  }
}

Future<int> _insertLocationBatch(
  String path,
  List<Map<String, Object?>> rows,
) async {
  final Database db = await openDatabase(
    path,
    readOnly: false,
    singleInstance: false,
    onConfigure: (Database db) async {
      await db.execute('PRAGMA journal_mode=WAL;');
      await db.execute('PRAGMA synchronous=NORMAL;');
      await db.execute('PRAGMA foreign_keys = ON;');
    },
  );
  try {
    await db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final Map<String, Object?> row in rows) {
        final Map<String, Object?> copy = Map<String, Object?>.from(row);
        copy.remove('id');
        batch.insert(FiduciaDatabasePaths.locationsTableName, copy);
      }
      await batch.commit(noResult: true);
    });
    return rows.length;
  } finally {
    await db.close();
  }
}
