import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/models/models.dart';

void main() {
  test('AcceptanceCriterion round-trips through toMap/fromMap', () {
    const c = AcceptanceCriterion(
      id: 'c1',
      text: 'Receipt uploaded',
      evidenceType: EvidenceType.url,
      satisfied: true,
      evidenceValue: 'https://example.com/r.pdf',
    );

    final restored = AcceptanceCriterion.fromMap(c.toMap());

    expect(restored.id, c.id);
    expect(restored.text, c.text);
    expect(restored.evidenceType, c.evidenceType);
    expect(restored.satisfied, c.satisfied);
    expect(restored.evidenceValue, c.evidenceValue);
  });

  test('MicroTask round-trips including criteria and nullable fields', () {
    final task = MicroTask(
      id: 't1',
      ideaId: 'i1',
      parentTaskId: 'p1',
      title: 'File taxes',
      description: 'Submit the return',
      estMinutes: 30,
      orderIndex: 2,
      scheduledStart: DateTime.utc(2026, 6, 21, 9, 30),
      state: TaskState.awaitingApproval,
      focusSeconds: 120,
      acceptanceCriteria: const [
        AcceptanceCriterion(id: 'c1', text: 'Form complete'),
        AcceptanceCriterion(
            id: 'c2', text: 'Paid', evidenceType: EvidenceType.note),
      ],
    );

    final restored = MicroTask.fromMap(task.toMap());

    expect(restored.id, task.id);
    expect(restored.ideaId, task.ideaId);
    expect(restored.parentTaskId, task.parentTaskId);
    expect(restored.title, task.title);
    expect(restored.description, task.description);
    expect(restored.estMinutes, task.estMinutes);
    expect(restored.orderIndex, task.orderIndex);
    expect(restored.scheduledStart, task.scheduledStart);
    expect(restored.state, task.state);
    expect(restored.focusSeconds, task.focusSeconds);
    expect(restored.acceptanceCriteria.length, 2);
    expect(restored.acceptanceCriteria[1].evidenceType, EvidenceType.note);
  });

  test('MicroTask round-trips when optional fields are null', () {
    const task = MicroTask(
      id: 't2',
      ideaId: 'i1',
      title: 'Quick call',
      description: '',
      estMinutes: 10,
      orderIndex: 0,
      acceptanceCriteria: [],
    );

    final restored = MicroTask.fromMap(task.toMap());

    expect(restored.parentTaskId, isNull);
    expect(restored.scheduledStart, isNull);
    expect(restored.acceptanceCriteria, isEmpty);
    expect(restored.state, TaskState.todo);
  });

  test('Idea round-trips through toMap/fromMap', () {
    final idea = Idea(
      id: 'i1',
      title: 'Do taxes',
      rawInput: 'do my taxes',
      type: IdeaType.tax,
      status: IdeaStatus.active,
      planVersion: 3,
      createdAt: DateTime.utc(2026, 6, 21, 8),
    );

    final restored = Idea.fromMap(idea.toMap());

    expect(restored.id, idea.id);
    expect(restored.title, idea.title);
    expect(restored.rawInput, idea.rawInput);
    expect(restored.type, idea.type);
    expect(restored.status, idea.status);
    expect(restored.planVersion, idea.planVersion);
    expect(restored.createdAt, idea.createdAt);
  });

  test('EventRecord round-trips including payload and state transition', () {
    final event = EventRecord(
      id: 'e1',
      ideaId: 'i1',
      microTaskId: 't1',
      type: 'task_approved',
      actor: 'user',
      fromState: TaskState.awaitingApproval,
      toState: TaskState.done,
      payload: const {'criterionId': 'c1', 'count': 2},
      ts: DateTime.utc(2026, 6, 21, 10),
    );

    final restored = EventRecord.fromMap(event.toMap());

    expect(restored.id, event.id);
    expect(restored.ideaId, event.ideaId);
    expect(restored.microTaskId, event.microTaskId);
    expect(restored.type, event.type);
    expect(restored.actor, event.actor);
    expect(restored.fromState, event.fromState);
    expect(restored.toState, event.toState);
    expect(restored.payload, event.payload);
    expect(restored.ts, event.ts);
  });

  test('EventRecord round-trips with null states and empty payload', () {
    final event = EventRecord(
      id: 'e2',
      ideaId: 'i1',
      type: 'idea_created',
      actor: 'user',
      ts: DateTime.utc(2026, 6, 21, 10),
    );

    final restored = EventRecord.fromMap(event.toMap());

    expect(restored.microTaskId, isNull);
    expect(restored.fromState, isNull);
    expect(restored.toState, isNull);
    expect(restored.payload, isEmpty);
  });
}
