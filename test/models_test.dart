import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/models/models.dart';

void main() {
  group('DurationBucket.fromMinutes', () {
    test('buckets by upper bound (mirrors validate_plan.py)', () {
      expect(DurationBucket.fromMinutes(10), DurationBucket.m15);
      expect(DurationBucket.fromMinutes(15), DurationBucket.m15);
      expect(DurationBucket.fromMinutes(16), DurationBucket.m30);
      expect(DurationBucket.fromMinutes(30), DurationBucket.m30);
      expect(DurationBucket.fromMinutes(45), DurationBucket.m45);
      expect(DurationBucket.fromMinutes(60), DurationBucket.m60plus);
    });
  });

  test('MicroTask.allCriteriaSatisfied reflects its criteria', () {
    const c1 =
        AcceptanceCriterion(id: 'a', text: 'first thing', satisfied: true);
    const c2 = AcceptanceCriterion(id: 'b', text: 'second thing');
    const task = MicroTask(
      id: 't1',
      ideaId: 'i1',
      title: 'Do the thing',
      description: 'desc',
      estMinutes: 15,
      orderIndex: 1,
      acceptanceCriteria: [c1, c2],
    );
    expect(task.allCriteriaSatisfied, isFalse);

    final done = task.copyWith(
      acceptanceCriteria: [c1, c2.copyWith(satisfied: true)],
    );
    expect(done.allCriteriaSatisfied, isTrue);
    expect(done.durationBucket, DurationBucket.m15);
  });
}
