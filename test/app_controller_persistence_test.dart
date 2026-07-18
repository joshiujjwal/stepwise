import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/event_store.dart';
import 'package:stepwise/state/persistence_store.dart';
import 'package:stepwise/state/planning_job.dart';

AppController _controller(PersistenceStore store) => AppController(
      coordinator: Coordinator(FakeLlmClient()),
      persistence: store,
    );

void main() {
  test('write-through persists idea, tasks and events on confirmPlan',
      () async {
    final store = InMemoryPersistenceStore();
    final c = _controller(store);

    await c.submitGoal('file my 2025 taxes');
    final idea = c.confirmPlan();
    await c.flushPersistence();

    final snapshot = await store.load();
    expect(snapshot.ideas.single.id, idea.id);
    expect(snapshot.tasks.length, c.tasksForIdea(idea.id).length);
    expect(
        snapshot.events.map((e) => e.type), contains(EventTypes.ideaCreated));
  });

  test('task mutations are written through to the store', () async {
    final store = InMemoryPersistenceStore();
    final c = _controller(store);
    await c.submitGoal('book the dentist');
    c.confirmPlan();
    final task = c.allTasks.first;

    expect(c.startTask(task.id), isTrue);
    await c.flushPersistence();

    final snapshot = await store.load();
    final persisted = snapshot.tasks.firstWhere((t) => t.id == task.id);
    expect(persisted.state, TaskState.inProgress);
  });

  test('hydrate restores ideas, tasks and events from the store', () async {
    final store = InMemoryPersistenceStore();
    final seed = _controller(store);
    await seed.submitGoal('plan a weekend trip');
    final idea = seed.confirmPlan();
    final taskCount = seed.tasksForIdea(idea.id).length;
    await seed.flushPersistence();

    final restored = _controller(store);
    expect(restored.ideas, isEmpty);

    await restored.hydrate();

    expect(restored.ideas.single.id, idea.id);
    expect(restored.tasksForIdea(idea.id).length, taskCount);
    expect(restored.store.events.map((e) => e.type),
        contains(EventTypes.planConfirmed));
  });

  test('hydrate on an empty store leaves the controller empty', () async {
    final c = _controller(InMemoryPersistenceStore());
    await c.hydrate();
    expect(c.ideas, isEmpty);
    expect(c.allTasks, isEmpty);
  });

  test('controller works without a persistence store (hermetic default)',
      () async {
    final c = AppController(coordinator: Coordinator(FakeLlmClient()));
    await c.submitGoal('quick errand');
    final idea = c.confirmPlan();
    await c.flushPersistence();
    await c.hydrate();
    expect(c.ideas.single.id, idea.id);
  });

  test('hydrate advances id counter past maxIdSeq even with no decoded rows',
      () async {
    final c = AppController(
      coordinator: Coordinator(FakeLlmClient()),
      persistence: _MaxIdSeqOnlyStore(10),
    );

    await c.hydrate();
    await c.submitGoal('quick errand');
    final idea = c.confirmPlan();

    // First id generated after hydrate must clear the corrupt-row high-water
    // mark (id10), so the new idea is id11 — never colliding with id<=10.
    expect(idea.id, 'id11');
  });
}

/// Reports only a [PersistedState.maxIdSeq] (no entities) — models a store whose
/// highest id belongs to a corrupt row that was skipped during decode.
class _MaxIdSeqOnlyStore implements PersistenceStore {
  _MaxIdSeqOnlyStore(this._maxIdSeq);
  final int _maxIdSeq;

  @override
  Future<PersistedState> load() async => PersistedState(maxIdSeq: _maxIdSeq);

  @override
  Future<void> upsertIdea(Idea idea) async {}

  @override
  Future<void> upsertTask(MicroTask task) async {}

  @override
  Future<void> appendEvent(EventRecord event) async {}

  @override
  Future<void> upsertJob(PlanningJob job) async {}

  @override
  Future<void> deleteJob(String jobId) async {}

  @override
  Future<void> clear() async {}
}
