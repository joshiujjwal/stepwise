import '../models/models.dart';

/// A point-in-time snapshot of everything restored on startup: entity state
/// (ideas + tasks) plus the full event log that powers trends/history.
class PersistedState {
  const PersistedState({
    this.ideas = const [],
    this.tasks = const [],
    this.events = const [],
    this.maxIdSeq = 0,
  });

  final List<Idea> ideas;
  final List<MicroTask> tasks;
  final List<EventRecord> events;

  /// Highest numeric suffix of any `idN`-form id physically present in storage,
  /// *including rows that failed to decode and were skipped*. The controller
  /// advances its id counter past this so a regenerated id can never collide
  /// with a corrupt-but-present row. 0 when nothing `idN`-shaped is stored.
  final int maxIdSeq;

  bool get isEmpty => ideas.isEmpty && tasks.isEmpty && events.isEmpty;
}

/// Highest numeric suffix among `idN`-form ids, or [floor] when none exceed it.
int maxIdSeqOf(Iterable<String> ids, {int floor = 0}) {
  final pattern = RegExp(r'^id(\d+)$');
  var max = floor;
  for (final id in ids) {
    final m = pattern.firstMatch(id);
    if (m == null) continue;
    final n = int.parse(m.group(1)!);
    if (n > max) max = n;
  }
  return max;
}

/// Durable, on-device store for the app's entity state and event log.
///
/// v1 keeps the in-memory entities/[EventStore] as the runtime read model; this
/// store is the backing copy. The controller hydrates from [load] on startup
/// and write-throughs every mutation via the upsert/append methods so data
/// survives app restarts (spec §1 — local, offline, private).
abstract interface class PersistenceStore {
  /// Load the persisted snapshot. Returns an empty snapshot on first run.
  Future<PersistedState> load();

  Future<void> upsertIdea(Idea idea);

  Future<void> upsertTask(MicroTask task);

  Future<void> appendEvent(EventRecord event);

  /// Wipe all persisted data (used by tests and a future "reset" affordance).
  Future<void> clear();
}

/// In-memory [PersistenceStore] used by tests and as a hermetic default. It is
/// NOT durable across process restarts — production wires the sqflite store.
class InMemoryPersistenceStore implements PersistenceStore {
  final Map<String, Idea> _ideas = {};
  final Map<String, MicroTask> _tasks = {};
  final List<EventRecord> _events = [];

  @override
  Future<PersistedState> load() async => PersistedState(
        ideas: _ideas.values.toList(growable: false),
        tasks: _tasks.values.toList(growable: false),
        events: List.unmodifiable(_events),
        maxIdSeq: maxIdSeqOf([
          ..._ideas.keys,
          for (final t in _tasks.values) ...[
            t.id,
            for (final c in t.acceptanceCriteria) c.id,
          ],
          for (final e in _events) e.id,
        ]),
      );

  @override
  Future<void> upsertIdea(Idea idea) async => _ideas[idea.id] = idea;

  @override
  Future<void> upsertTask(MicroTask task) async => _tasks[task.id] = task;

  @override
  Future<void> appendEvent(EventRecord event) async => _events.add(event);

  @override
  Future<void> clear() async {
    _ideas.clear();
    _tasks.clear();
    _events.clear();
  }
}
