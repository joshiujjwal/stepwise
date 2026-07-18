import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/coordinator/todo_chunking_agent.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/planning_job.dart';

const _validPlan = '''
{
  "action": "propose_plan",
  "idea_type": "other",
  "summary": "ok",
  "micro_tasks": [
    {"title": "Do step one", "description": "First.", "est_minutes": 10, "order_index": 1, "acceptance_criteria": [{"text": "done", "evidence_type": "checkbox"}]},
    {"title": "Do step two", "description": "Second.", "est_minutes": 10, "order_index": 2, "acceptance_criteria": [{"text": "done", "evidence_type": "checkbox"}]},
    {"title": "Do step three", "description": "Third.", "est_minutes": 10, "order_index": 3, "acceptance_criteria": [{"text": "done", "evidence_type": "checkbox"}]}
  ]
}
''';

void main() {
  test('plan() forwards starting-point context into the user prompt', () async {
    final llm = FakeLlmClient(scripted: [_validPlan]);
    final coordinator = Coordinator(llm);

    await coordinator.plan(
      goal: 'practice pitch',
      startingContext: 'I already have slides; I want to rehearse delivery.',
    );

    final user = llm.calls.single.user;
    expect(user, contains('I already have slides'));
    expect(user.toLowerCase(), contains('starting point'));
  });

  test('plan() omits the context line when no context is given', () async {
    final llm = FakeLlmClient(scripted: [_validPlan]);
    final coordinator = Coordinator(llm);

    await coordinator.plan(goal: 'practice pitch');

    expect(
        llm.calls.single.user.toLowerCase(), isNot(contains('starting point')));
  });

  test('chunkTodo threads context through to the coordinator', () async {
    final llm = FakeLlmClient(scripted: [_validPlan]);
    final agent = TodoChunkingAgent(coordinator: Coordinator(llm));

    await agent.chunkTodo('practice pitch',
        context: 'Slides are done, focus on delivery.');

    expect(
        llm.calls.single.user, contains('Slides are done, focus on delivery.'));
  });

  test('startPlanningJob stores context and forwards it to the planner',
      () async {
    final llm = FakeLlmClient(scripted: [_validPlan]);
    final c = AppController(coordinator: Coordinator(llm));

    final id = c.startPlanningJob('practice pitch',
        context: 'Slides done, rehearse delivery.');
    expect(c.jobById(id)!.context, 'Slides done, rehearse delivery.');

    await c.flushPlanningJobs();
    expect(llm.calls.single.user, contains('Slides done, rehearse delivery.'));
  });

  test('PlanningJob round-trips context through toMap/fromMap', () {
    final job = PlanningJob(
      id: 'j1',
      goal: 'practice pitch',
      status: PlanningJobStatus.thinking,
      createdAt: DateTime.utc(2026, 7, 18),
      context: 'Slides are done.',
    );
    expect(PlanningJob.fromMap(job.toMap()).context, 'Slides are done.');
  });
}
