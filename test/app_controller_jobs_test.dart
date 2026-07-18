import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/event_store.dart';
import 'package:stepwise/state/persistence_store.dart';
import 'package:stepwise/state/planning_job.dart';

AppController _controller({
  List<String>? scripted,
  PersistenceStore? persistence,
}) {
  return AppController(
    coordinator: Coordinator(FakeLlmClient(scripted: scripted)),
    persistence: persistence,
  );
}

class _SlowLlmClient implements LlmClient {
  final Duration delay;
  _SlowLlmClient(this.delay);
  @override
  Future<String> complete(
      {required String system, required String user}) async {
    await Future<void>.delayed(delay);
    // Minimal *valid* plan (validator requires 3-15 tasks).
    String task(int i) => '{"title":"Step $i now here","description":"do it",'
        '"est_minutes":15,"order_index":$i,'
        '"acceptance_criteria":[{"text":"done","evidence_type":"checkbox"}]}';
    return '{"action":"propose_plan","idea_type":"other","summary":"s",'
        '"micro_tasks":[${task(0)},${task(1)},${task(2)}]}';
  }
}

class _ThrowingLlmClient implements LlmClient {
  @override
  Future<String> complete(
          {required String system, required String user}) async =>
      throw Exception('inference failed');
}

void main() {
  test('startPlanningJob returns immediately and completes to ready', () async {
    final c = _controller();
    final id = c.startPlanningJob('plan my week');

    // Non-blocking: the job exists and is thinking before planning resolves.
    expect(c.jobs.single.id, id);
    expect(c.jobs.single.status, PlanningJobStatus.thinking);
    expect(c.readyJobs, isEmpty);

    await c.flushPlanningJobs();
    expect(c.jobById(id)!.status, PlanningJobStatus.ready);
    expect(c.jobById(id)!.proposal!.tasks, isNotEmpty);
    expect(c.readyJobs.single.id, id);
    // No idea/tasks persisted until the user submits.
    expect(c.ideas, isEmpty);
    expect(c.allTasks, isEmpty);
  });

  test('multiple queued jobs both reach ready (serial, single-threaded)',
      () async {
    final c = AppController(
      coordinator:
          Coordinator(_SlowLlmClient(const Duration(milliseconds: 10))),
    );
    final a = c.startPlanningJob('goal A');
    final b = c.startPlanningJob('goal B');
    expect(c.jobs.length, 2);

    await c.flushPlanningJobs();
    expect(c.jobById(a)!.status, PlanningJobStatus.ready);
    expect(c.jobById(b)!.status, PlanningJobStatus.ready);
  });

  test('submitJob persists an idea + tasks and removes the job', () async {
    final c = _controller();
    final id = c.startPlanningJob('file my 2025 taxes');
    await c.flushPlanningJobs();

    final idea = c.submitJob(id);
    expect(c.jobById(id), isNull);
    expect(c.ideas.single.id, idea.id);
    expect(c.tasksForIdea(idea.id), isNotEmpty);
    final types = c.store.events.map((e) => e.type);
    expect(types, contains(EventTypes.ideaCreated));
    expect(types, contains(EventTypes.planConfirmed));
  });

  test('discardJob removes the job without creating an idea', () async {
    final c = _controller();
    final id = c.startPlanningJob('something');
    await c.flushPlanningJobs();

    c.discardJob(id);
    expect(c.jobs, isEmpty);
    expect(c.ideas, isEmpty);
  });

  test('updateJobProposal replaces the plan for edit-before-submit', () async {
    final c = _controller();
    final id = c.startPlanningJob('trip planning');
    await c.flushPlanningJobs();

    const edited = PlanResponse(
      ideaType: 'trip',
      tasks: [
        PlannedTask(
          title: 'Edited step',
          description: 'changed',
          estMinutes: 20,
          orderIndex: 0,
          acceptanceCriteria: [
            PlannedCriterion(text: 'ok', evidenceType: 'checkbox'),
          ],
        ),
      ],
    );
    c.updateJobProposal(id, edited);
    expect(c.jobById(id)!.proposal!.tasks.single.title, 'Edited step');

    final idea = c.submitJob(id);
    expect(c.tasksForIdea(idea.id).single.title, 'Edited step');
  });

  test('a clarifying job can be answered and then reach ready', () async {
    final clarify =
        '{"action":"ask_clarifying","questions":["What does done look like?"]}';
    final c = _controller(scripted: [clarify]);
    final id = c.startPlanningJob('taxes');
    await c.flushPlanningJobs();
    expect(c.jobById(id)!.status, PlanningJobStatus.clarifying);
    expect(c.jobById(id)!.questions.single, contains('done'));

    c.answerJob(id, 'file online myself');
    await c.flushPlanningJobs();
    expect(c.jobById(id)!.status, PlanningJobStatus.ready);
  });

  test('an inference failure marks the job as error', () async {
    final c = AppController(coordinator: Coordinator(_ThrowingLlmClient()));
    final id = c.startPlanningJob('anything');
    await c.flushPlanningJobs();
    expect(c.jobById(id)!.status, PlanningJobStatus.error);
    expect(c.jobById(id)!.error, isNotNull);
  });

  test('jobs are written through and restored on hydrate', () async {
    final store = InMemoryPersistenceStore();
    final c1 = _controller(persistence: store);
    final id = c1.startPlanningJob('durable goal');
    await c1.flushPlanningJobs();
    await c1.flushPersistence();

    final c2 = _controller(persistence: store);
    await c2.hydrate();
    expect(c2.jobById(id)!.status, PlanningJobStatus.ready);
    expect(c2.jobById(id)!.goal, 'durable goal');
  });
}
