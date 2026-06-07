import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/event_store.dart';
import 'package:stepwise/state/projections.dart';

MicroTask _task(
  String id,
  int order,
  TaskState state, {
  int focus = 0,
  int est = 15,
}) =>
    MicroTask(
      id: id,
      ideaId: 'i1',
      title: 'Task number $order',
      description: 'd',
      estMinutes: est,
      orderIndex: order,
      state: state,
      focusSeconds: focus,
      acceptanceCriteria: const [
        AcceptanceCriterion(id: 'c', text: 'a criterion'),
      ],
    );

EventRecord _approved(DateTime day) => EventRecord(
      id: 'e${day.millisecondsSinceEpoch}',
      ideaId: 'i1',
      type: EventTypes.taskApproved,
      actor: 'user',
      ts: day,
    );

void main() {
  group('progressFor', () {
    test('reports step N of M and percent', () {
      final p = progressFor([
        _task('a', 1, TaskState.done),
        _task('b', 2, TaskState.done),
        _task('c', 3, TaskState.inProgress),
        _task('d', 4, TaskState.todo),
      ]);
      expect(p.total, 4);
      expect(p.done, 2);
      expect(p.currentStep, 3); // first not-done by order
      expect(p.percentComplete, 50);
      expect(p.isComplete, isFalse);
    });

    test('excludes re-tasked containers and detects completion', () {
      final p = progressFor([
        _task('a', 1, TaskState.done),
        _task('b', 2, TaskState.reTasked), // excluded
        _task('c', 3, TaskState.done),
      ]);
      expect(p.total, 2);
      expect(p.isComplete, isTrue);
      expect(p.currentStep, 2);
      expect(p.percentComplete, 100);
    });

    test('empty plan is 0%', () {
      expect(progressFor(const []).percentComplete, 0);
    });
  });

  group('trends', () {
    test('throughputByDay buckets approvals by date', () {
      final events = [
        _approved(DateTime(2026, 6, 6, 9)),
        _approved(DateTime(2026, 6, 6, 18)),
        _approved(DateTime(2026, 6, 5, 10)),
      ];
      final t = throughputByDay(events);
      expect(t[DateTime(2026, 6, 6)], 2);
      expect(t[DateTime(2026, 6, 5)], 1);
    });

    test('currentStreak counts consecutive days up to today', () {
      final events = [
        _approved(DateTime(2026, 6, 6)),
        _approved(DateTime(2026, 6, 5)),
        _approved(DateTime(2026, 6, 3)), // gap on the 4th
      ];
      expect(currentStreak(events, today: DateTime(2026, 6, 6, 23)), 2);
    });

    test('frictionCounts tallies blocked/retasked/rejected', () {
      EventRecord f(String type) => EventRecord(
            id: type,
            ideaId: 'i1',
            type: type,
            actor: 'user',
            ts: DateTime(2026, 6, 6),
          );
      final c = frictionCounts([
        f(EventTypes.taskBlocked),
        f(EventTypes.taskRetasked),
        f(EventTypes.taskRetasked),
        f(EventTypes.taskRejected),
      ]);
      expect(c.blocked, 1);
      expect(c.reTasked, 2);
      expect(c.rejected, 1);
    });

    test('calibration includes only done tasks with timer use', () {
      final points = calibration([
        _task('a', 1, TaskState.done, est: 30, focus: 38 * 60),
        _task('b', 2, TaskState.done,
            est: 15, focus: 0), // no timer -> excluded
        _task('c', 3, TaskState.inProgress, est: 45, focus: 600), // not done
      ]);
      expect(points.length, 1);
      expect(points.single.taskId, 'a');
      expect(points.single.estMinutes, 30);
      expect(points.single.actualMinutes, 38);
    });
  });
}
