import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/state/planning_job.dart';

void main() {
  const proposal = PlanResponse(
    ideaType: 'project',
    summary: 's',
    tasks: [
      PlannedTask(
        title: 'a',
        description: 'b',
        estMinutes: 10,
        orderIndex: 0,
        acceptanceCriteria: [
          PlannedCriterion(text: 'done', evidenceType: 'checkbox'),
        ],
      ),
    ],
  );

  test('a ready job round-trips through toMap/fromMap', () {
    final job = PlanningJob(
      id: 'job1',
      goal: 'plan my week',
      status: PlanningJobStatus.ready,
      proposal: proposal,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );

    final restored = PlanningJob.fromMap(job.toMap());
    expect(restored.id, 'job1');
    expect(restored.goal, 'plan my week');
    expect(restored.status, PlanningJobStatus.ready);
    expect(restored.proposal!.tasks.single.title, 'a');
    expect(restored.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(restored.error, isNull);
    expect(restored.questions, isEmpty);
  });

  test('a clarifying job round-trips its questions', () {
    final job = PlanningJob(
      id: 'job2',
      goal: 'taxes',
      status: PlanningJobStatus.clarifying,
      questions: const ['What year?', 'Filing jointly?'],
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final restored = PlanningJob.fromMap(job.toMap());
    expect(restored.status, PlanningJobStatus.clarifying);
    expect(restored.questions, ['What year?', 'Filing jointly?']);
    expect(restored.proposal, isNull);
  });

  test('an error job round-trips its message', () {
    final job = PlanningJob(
      id: 'job3',
      goal: 'x',
      status: PlanningJobStatus.error,
      error: 'model failed',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final restored = PlanningJob.fromMap(job.toMap());
    expect(restored.status, PlanningJobStatus.error);
    expect(restored.error, 'model failed');
  });

  test('copyWith replaces status and clears via new values', () {
    final job = PlanningJob(
      id: 'j',
      goal: 'g',
      status: PlanningJobStatus.thinking,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final ready = job.copyWith(
      status: PlanningJobStatus.ready,
      proposal: proposal,
    );
    expect(ready.status, PlanningJobStatus.ready);
    expect(ready.proposal, isNotNull);
    expect(ready.id, 'j');
    expect(ready.goal, 'g');
  });
}
