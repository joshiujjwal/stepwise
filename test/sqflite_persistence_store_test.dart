import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/sqflite_persistence_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Future<SqflitePersistenceStore> openStore() async {
    await databaseFactoryFfi.deleteDatabase(inMemoryDatabasePath);
    return SqflitePersistenceStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  }

  test('round-trips ideas, tasks and events through the database', () async {
    final store = await openStore();

    final idea = Idea(
      id: 'i1',
      title: 'Do taxes',
      rawInput: 'do my taxes',
      type: IdeaType.tax,
      status: IdeaStatus.active,
      createdAt: DateTime.utc(2026, 6, 21, 8),
    );
    final task = MicroTask(
      id: 't1',
      ideaId: 'i1',
      title: 'Gather documents',
      description: 'W-2 and receipts',
      estMinutes: 30,
      orderIndex: 1,
      state: TaskState.inProgress,
      scheduledStart: DateTime.utc(2026, 6, 22, 9),
      acceptanceCriteria: const [
        AcceptanceCriterion(id: 'c1', text: 'All forms collected'),
      ],
    );
    final event = EventRecord(
      id: 'e1',
      ideaId: 'i1',
      microTaskId: 't1',
      type: 'task_started',
      actor: 'user',
      fromState: TaskState.todo,
      toState: TaskState.inProgress,
      ts: DateTime.utc(2026, 6, 21, 9),
    );

    await store.upsertIdea(idea);
    await store.upsertTask(task);
    await store.appendEvent(event);

    final snapshot = await store.load();
    expect(snapshot.ideas.single.id, 'i1');
    expect(snapshot.ideas.single.type, IdeaType.tax);
    expect(snapshot.tasks.single.state, TaskState.inProgress);
    expect(snapshot.tasks.single.scheduledStart, DateTime.utc(2026, 6, 22, 9));
    expect(snapshot.tasks.single.acceptanceCriteria.single.text,
        'All forms collected');
    expect(snapshot.events.single.toState, TaskState.inProgress);
  });

  test('upsert replaces an existing row by id', () async {
    final store = await openStore();
    const base = MicroTask(
      id: 't1',
      ideaId: 'i1',
      title: 'Task',
      description: '',
      estMinutes: 15,
      orderIndex: 0,
      acceptanceCriteria: [],
    );

    await store.upsertTask(base);
    await store.upsertTask(base.copyWith(state: TaskState.done));

    final snapshot = await store.load();
    expect(snapshot.tasks.length, 1);
    expect(snapshot.tasks.single.state, TaskState.done);
  });

  test('events load in append order', () async {
    final store = await openStore();
    for (var i = 0; i < 5; i++) {
      await store.appendEvent(EventRecord(
        id: 'e$i',
        ideaId: 'i1',
        type: 'task_started',
        actor: 'user',
        ts: DateTime.utc(2026, 6, 21, 9, i),
      ));
    }

    final snapshot = await store.load();
    expect(snapshot.events.map((e) => e.id), ['e0', 'e1', 'e2', 'e3', 'e4']);
  });

  test('clear wipes all persisted data', () async {
    final store = await openStore();
    await store.upsertIdea(Idea(
      id: 'i1',
      title: 't',
      rawInput: 't',
      type: IdeaType.other,
      createdAt: DateTime.utc(2026),
    ));

    await store.clear();

    final snapshot = await store.load();
    expect(snapshot.isEmpty, isTrue);
  });

  test('load skips a corrupt row instead of aborting the whole restore',
      () async {
    final store = await openStore();
    await store.upsertIdea(Idea(
      id: 'good',
      title: 'ok',
      rawInput: 'ok',
      type: IdeaType.other,
      createdAt: DateTime.utc(2026),
    ));

    // Simulate an interrupted/corrupt write directly at the SQL layer.
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.insert('ideas', {'id': 'bad', 'data': 'not-json{'});

    final snapshot = await store.load();
    expect(snapshot.ideas.map((i) => i.id), ['good']);
  });

  test('maxIdSeq counts undecodable rows so the id counter can skip past them',
      () async {
    final store = await openStore();
    await store.upsertIdea(Idea(
      id: 'id2',
      title: 'ok',
      rawInput: 'ok',
      type: IdeaType.other,
      createdAt: DateTime.utc(2026),
    ));
    // A corrupt latest write whose id (id7) is higher than any decodable row.
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.insert('events', {'id': 'id7', 'data': 'not-json{'});

    final snapshot = await store.load();
    expect(snapshot.events, isEmpty);
    expect(snapshot.maxIdSeq, 7);
  });

  test('appendEvent overwrites on id collision instead of dropping the event',
      () async {
    final store = await openStore();
    // A stale row occupying id3 (e.g. a corrupt row that was skipped on load).
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
    await db.insert('events', {'id': 'id3', 'data': 'not-json{'});

    await store.appendEvent(EventRecord(
      id: 'id3',
      ideaId: 'i1',
      type: 'task_started',
      actor: 'user',
      ts: DateTime.utc(2026, 6, 21, 9),
    ));

    final snapshot = await store.load();
    expect(snapshot.events.single.type, 'task_started');
  });
}
