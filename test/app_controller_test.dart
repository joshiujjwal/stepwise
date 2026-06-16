import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/event_store.dart';

AppController _controller(
    {List<String>? scripted, DateTime Function()? clock}) {
  return AppController(
    coordinator: Coordinator(FakeLlmClient(scripted: scripted)),
    clock: clock,
  );
}

class _ThrowingLlmClient implements LlmClient {
  @override
  Future<String> complete({required String system, required String user}) async {
    throw Exception('inference failed');
  }
}

void main() {
  test('submitGoal -> proposed plan, confirm creates idea + tasks + events',
      () async {
    final c = _controller();
    await c.submitGoal('file my 2025 taxes');
    expect(c.session!.phase, PlanningPhase.proposed);
    expect(c.session!.proposal!.tasks, isNotEmpty);

    final idea = c.confirmPlan();
    expect(c.session, isNull);
    expect(c.ideas.single.id, idea.id);
    expect(c.ideas.single.type, IdeaType.tax); // guessed from "taxes"
    expect(c.tasksForIdea(idea.id).length, 5);
    final types = c.store.events.map((e) => e.type);
    expect(types, contains(EventTypes.ideaCreated));
    expect(types, contains(EventTypes.planConfirmed));
  });

  test('clarify path then answers -> plan', () async {
    final clarify =
        '{"action":"ask_clarifying","questions":["What does done look like?"]}';
    final c = _controller(
        scripted: [clarify]); // first call clarifies, then demo plans
    await c.submitGoal('taxes');
    expect(c.session!.phase, PlanningPhase.clarifying);
    expect(c.session!.questions.single, contains('done'));

    await c.submitAnswers('file online myself');
    expect(c.session!.phase, PlanningPhase.proposed);
  });

  test('approve is blocked until criteria satisfied, then completes idea',
      () async {
    final c = _controller();
    await c.submitGoal('book the dentist');
    final idea = c.confirmPlan();
    final tasks = c.tasksForIdea(idea.id);

    for (final t in tasks) {
      expect(c.startTask(t.id), isTrue);
      expect(c.submitTask(t.id), isTrue);
      // approving before satisfying criteria must fail (the gate)
      expect(c.approveTask(t.id), isFalse);
      for (final crit in c.taskById(t.id).acceptanceCriteria) {
        c.satisfyCriterion(t.id, crit.id);
      }
      expect(c.approveTask(t.id), isTrue);
    }
    expect(c.ideas.single.status, IdeaStatus.done);
    final approvals =
        c.store.events.where((e) => e.type == EventTypes.taskApproved).length;
    expect(approvals, tasks.length);
  });

  test('block then retask spawns children and stalls the idea', () async {
    final c = _controller();
    await c.submitGoal('plan a trip');
    final idea = c.confirmPlan();
    final t = c.tasksForIdea(idea.id).first;

    expect(c.blockTask(t.id, "don't know where to start"), isTrue);
    expect(c.ideas.single.status, IdeaStatus.stalled);

    final before = c.tasksForIdea(idea.id).length;
    await c.retask(t.id, reason: "don't know where to start");
    expect(c.taskById(t.id).state, TaskState.reTasked);
    expect(
        c.tasksForIdea(idea.id).length, greaterThan(before)); // children added
    expect(
        c.store.events.any((e) => e.type == EventTypes.taskRetasked), isTrue);
  });

  test('focus timer accumulates focused seconds using injected clock',
      () async {
    var now = DateTime(2026, 6, 6, 9);
    final c = _controller(clock: () => now);
    await c.submitGoal('write a blog post');
    final idea = c.confirmPlan();
    final t = c.tasksForIdea(idea.id).first;

    c.startTask(t.id);
    c.startTimer(t.id);
    expect(c.isTimerRunning(t.id), isTrue);
    now = now.add(const Duration(minutes: 12));
    c.stopTimer(t.id);
    expect(c.isTimerRunning(t.id), isFalse);
    expect(c.taskById(t.id).focusSeconds, 12 * 60);
  });

  test('availableTasks filters by duration bucket', () async {
    final c = _controller();
    await c.submitGoal('clean the garage');
    c.confirmPlan();
    final m15 = c.availableTasks(bucket: DurationBucket.m15);
    expect(m15, isNotEmpty);
    expect(m15.every((t) => t.durationBucket == DurationBucket.m15), isTrue);
  });

  test('submitGoal surfaces non-coordinator planner errors as session error',
      () async {
    final c = AppController(coordinator: Coordinator(_ThrowingLlmClient()));
    await c.submitGoal('organize files');

    expect(c.session, isNotNull);
    expect(c.session!.phase, PlanningPhase.error);
    expect(c.session!.error, contains('inference failed'));
  });
}
