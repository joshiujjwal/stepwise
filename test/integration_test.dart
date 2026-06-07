import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/event_store.dart';
import 'package:stepwise/state/projections.dart';

/// End-to-end: idea -> plan -> execute (with focus timer) -> approve everything,
/// then assert the event log and projections tell the right story.
void main() {
  test('full lifecycle drives projections correctly', () async {
    var now = DateTime(2026, 6, 6, 9);
    final c = AppController(
      coordinator: Coordinator(FakeLlmClient()),
      clock: () => now,
    );

    await c.submitGoal('file my 2025 taxes');
    final idea = c.confirmPlan();
    final tasks = c.tasksForIdea(idea.id);
    expect(tasks, hasLength(5));
    expect(c.progressForIdea(idea.id).percentComplete, 0);

    // Work the first task with the focus timer running for 25 minutes.
    final first = tasks.first;
    c.startTask(first.id);
    c.startTimer(first.id);
    now = now.add(const Duration(minutes: 25));
    c.stopTimer(first.id);
    c.submitTask(first.id);
    for (final crit in c.taskById(first.id).acceptanceCriteria) {
      c.satisfyCriterion(first.id, crit.id);
    }
    expect(c.approveTask(first.id), isTrue);
    expect(c.progressForIdea(idea.id).percentComplete, 20);

    // Complete the rest.
    for (final t in tasks.skip(1)) {
      c.startTask(t.id);
      c.submitTask(t.id);
      for (final crit in c.taskById(t.id).acceptanceCriteria) {
        c.satisfyCriterion(t.id, crit.id);
      }
      expect(c.approveTask(t.id), isTrue);
    }

    // Idea is complete.
    expect(c.ideas.single.status, IdeaStatus.done);
    expect(c.progressForIdea(idea.id).isComplete, isTrue);

    // Projections over the resulting event log.
    final events = c.store.events;
    expect(
        events.where((e) => e.type == EventTypes.taskApproved), hasLength(5));
    expect(currentStreak(events, today: now), 1);
    expect(throughputByDay(events)[DateTime(2026, 6, 6)], 5);

    // Only the timed task contributes a calibration point (est 15 vs actual 25).
    final points = calibration(c.allTasks);
    expect(points, hasLength(1));
    expect(points.single.estMinutes, 15);
    expect(points.single.actualMinutes, 25);
  });
}
