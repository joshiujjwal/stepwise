import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/planner.dart';

void main() {
  test('PlanResponse round-trips through toMap/fromMap', () {
    const original = PlanResponse(
      ideaType: 'project',
      summary: 'ship the thing',
      tasks: [
        PlannedTask(
          title: 'Draft outline',
          description: 'Sketch the sections',
          estMinutes: 15,
          orderIndex: 0,
          acceptanceCriteria: [
            PlannedCriterion(text: 'outline exists', evidenceType: 'checkbox'),
            PlannedCriterion(text: 'link saved', evidenceType: 'url'),
          ],
        ),
        PlannedTask(
          title: 'Write draft',
          description: 'First pass',
          estMinutes: 30,
          orderIndex: 1,
          acceptanceCriteria: [
            PlannedCriterion(text: 'draft done', evidenceType: 'note'),
          ],
        ),
      ],
    );

    final restored = PlanResponse.fromMap(original.toMap());

    expect(restored.ideaType, original.ideaType);
    expect(restored.summary, original.summary);
    expect(restored.tasks.length, 2);
    final t0 = restored.tasks.first;
    expect(t0.title, 'Draft outline');
    expect(t0.description, 'Sketch the sections');
    expect(t0.estMinutes, 15);
    expect(t0.orderIndex, 0);
    expect(t0.acceptanceCriteria.length, 2);
    expect(t0.acceptanceCriteria.first.text, 'outline exists');
    expect(t0.acceptanceCriteria.first.evidenceType, 'checkbox');
    expect(t0.acceptanceCriteria[1].evidenceType, 'url');
    expect(restored.tasks[1].acceptanceCriteria.single.evidenceType, 'note');
  });

  test('PlanResponse.fromMap tolerates a null summary', () {
    const original = PlanResponse(ideaType: 'errand', tasks: []);
    final restored = PlanResponse.fromMap(original.toMap());
    expect(restored.summary, isNull);
    expect(restored.tasks, isEmpty);
  });
}
