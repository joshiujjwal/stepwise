import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/app_scope.dart';
import 'package:stepwise/state/planning_job.dart';
import 'package:stepwise/ui/idea_screen.dart';
import 'package:stepwise/ui/review_plan_screen.dart';

AppController _fresh() =>
    AppController(coordinator: Coordinator(FakeLlmClient()));

Widget _host(AppController c, Widget home) =>
    AppScope(controller: c, child: MaterialApp(home: home));

Future<String> _readyJob(AppController c) async {
  final id = c.startPlanningJob('plan my launch');
  await c.flushPlanningJobs();
  return id;
}

void main() {
  testWidgets('Chunk in background enqueues a job and shows the inbox',
      (tester) async {
    final c = _fresh();
    await tester.pumpWidget(_host(c, const IdeaScreen()));

    await tester.enterText(find.byType(TextField).first, 'plan my launch');
    await tester.tap(find.text('Chunk in background'));
    await tester.pump();

    expect(c.jobs, hasLength(1));
    expect(find.text('Background plans'), findsOneWidget);

    await c.flushPlanningJobs();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);
  });

  testWidgets('ReviewPlanScreen submit persists an idea + tasks',
      (tester) async {
    final c = _fresh();
    final id = await _readyJob(c);
    await tester.pumpWidget(_host(c, ReviewPlanScreen(jobId: id)));

    expect(find.text('Submit plan'), findsOneWidget);
    await tester.tap(find.text('Submit plan'));
    await tester.pump();

    expect(c.ideas, hasLength(1));
    expect(c.tasksForIdea(c.ideas.single.id), isNotEmpty);
    expect(c.jobs, isEmpty);
  });

  testWidgets('editing a step title carries through to the submitted task',
      (tester) async {
    final c = _fresh();
    final id = await _readyJob(c);
    await tester.pumpWidget(_host(c, ReviewPlanScreen(jobId: id)));

    await tester.enterText(
        find.byType(TextField).first, 'My edited first step');
    await tester.tap(find.text('Submit plan'));
    await tester.pump();

    final titles =
        c.tasksForIdea(c.ideas.single.id).map((t) => t.title).toList();
    expect(titles, contains('My edited first step'));
  });

  testWidgets('removing a step drops it from the submitted plan',
      (tester) async {
    final c = _fresh();
    final id = await _readyJob(c);
    final before = c.jobById(id)!.proposal!.tasks.length;
    await tester.pumpWidget(_host(c, ReviewPlanScreen(jobId: id)));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    await tester.tap(find.text('Submit plan'));
    await tester.pump();

    expect(c.tasksForIdea(c.ideas.single.id), hasLength(before - 1));
  });

  testWidgets('discard removes the job without creating an idea',
      (tester) async {
    final c = _fresh();
    final id = await _readyJob(c);
    await tester.pumpWidget(_host(c, ReviewPlanScreen(jobId: id)));

    await tester.tap(find.text('Discard'));
    await tester.pump();

    expect(c.jobs, isEmpty);
    expect(c.ideas, isEmpty);
  });

  testWidgets('a clarifying job renders its questions in review',
      (tester) async {
    final clarify =
        '{"action":"ask_clarifying","questions":["What does done look like?"]}';
    final c = AppController(
        coordinator: Coordinator(FakeLlmClient(scripted: [clarify])));
    final id = c.startPlanningJob('taxes');
    await c.flushPlanningJobs();
    expect(c.jobById(id)!.status, PlanningJobStatus.clarifying);

    await tester.pumpWidget(_host(c, ReviewPlanScreen(jobId: id)));
    expect(find.textContaining('done look like'), findsOneWidget);
    expect(find.text('Send answer'), findsOneWidget);
  });
}
