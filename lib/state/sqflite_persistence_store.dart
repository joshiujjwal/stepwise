import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'persistence_store.dart';

/// Durable [PersistenceStore] backed by sqflite. Each entity is stored as a
/// JSON blob keyed by its id, which keeps the schema stable as models evolve
/// while still giving us per-row upserts (write-through) and an ordered,
/// append-only event log. This is the device-runtime backing referenced in
/// app_controller.dart and event_store.dart.
class SqflitePersistenceStore implements PersistenceStore {
  SqflitePersistenceStore(this._db);

  final Database _db;

  static const _dbVersion = 1;

  /// Open (or create) the database. [factory] and [path] are injectable so
  /// tests can run against an ffi/in-memory database; production uses the
  /// platform default factory under the app's databases directory.
  static Future<SqflitePersistenceStore> open({
    DatabaseFactory? factory,
    String? path,
    String fileName = 'stepwise.db',
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? '${await f.getDatabasesPath()}/$fileName';
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _createSchema(db),
      ),
    );
    return SqflitePersistenceStore(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute(
      'CREATE TABLE ideas (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE tasks (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE events ('
      'seq INTEGER PRIMARY KEY AUTOINCREMENT, '
      'id TEXT UNIQUE NOT NULL, '
      'data TEXT NOT NULL)',
    );
  }

  @override
  Future<PersistedState> load() async {
    final ideaRows = await _db.query('ideas');
    final taskRows = await _db.query('tasks');
    final eventRows = await _db.query('events', orderBy: 'seq ASC');
    // Scan raw id columns of every row — including ones that fail to decode —
    // so the controller's id counter advances past a corrupt-but-present row
    // and can't later regenerate a colliding id (which `ignore` would silently
    // drop for events). Task rows also contain higher criterion ids inside the
    // blob; those are covered by `appendEvent` using `replace` as a safety net.
    final rawIds = [
      for (final r in [...ideaRows, ...taskRows, ...eventRows])
        if (r['id'] is String) r['id']! as String,
    ];
    return PersistedState(
      ideas: _decodeRows(ideaRows, 'idea', Idea.fromMap),
      tasks: _decodeRows(taskRows, 'task', MicroTask.fromMap),
      events: _decodeRows(eventRows, 'event', EventRecord.fromMap),
      maxIdSeq: maxIdSeqOf(rawIds),
    );
  }

  // Decodes rows one at a time so a single corrupt/incompatible blob (an
  // interrupted write or a future model change) is skipped and logged rather
  // than aborting the entire restore.
  static List<T> _decodeRows<T>(
    List<Map<String, Object?>> rows,
    String kind,
    T Function(Map<String, Object?>) fromMap,
  ) {
    final out = <T>[];
    for (final row in rows) {
      try {
        out.add(fromMap(_decode(row['data'])));
      } catch (e) {
        debugPrint('skipping unreadable $kind row: $e');
      }
    }
    return out;
  }

  @override
  Future<void> upsertIdea(Idea idea) => _db.insert(
        'ideas',
        {'id': idea.id, 'data': jsonEncode(idea.toMap())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> upsertTask(MicroTask task) => _db.insert(
        'tasks',
        {'id': task.id, 'data': jsonEncode(task.toMap())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> appendEvent(EventRecord event) => _db.insert(
        'events',
        {'id': event.id, 'data': jsonEncode(event.toMap())},
        // Replace (not ignore): re-appending the same event id is idempotent
        // (identical data), but on a genuine id collision with a stale/corrupt
        // row this overwrites it instead of silently dropping the new event.
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> clear() async {
    await _db.delete('events');
    await _db.delete('tasks');
    await _db.delete('ideas');
  }

  Future<void> close() => _db.close();

  static Map<String, Object?> _decode(Object? data) =>
      (jsonDecode(data! as String) as Map).cast<String, Object?>();
}
