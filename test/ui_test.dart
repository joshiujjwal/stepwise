import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/app_scope.dart';
import 'package:stepwise/ui/execute_screen.dart';
import 'package:stepwise/ui/idea_progress_screen.dart';
import 'package:stepwise/ui/idea_screen.dart';

AppController _fresh({DateTime Function()? clock}) =>
    AppController(coordinator: Coordinator(FakeLlmClient()), clock: clock);

Widget _app(AppController c, Widget home) =>
    AppScope(controller: c, child: MaterialApp(home: home));

/// Never completes, so the controller stays in the `thinking` phase — lets us
/// inspect the planning progress UI.
class _BlockingLlmClient implements LlmClient {
  final _completer = Completer<String>();
  @override
  Future<String> complete({required String system, required String user}) =>
      _completer.future;
}

void main() {
  testWidgets('Idea capture exposes tooltip and semantics guidance',
      (tester) async {
    final c = _fresh();
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(c, const IdeaScreen()));

      expect(
        find.byTooltip('Describe one TODO you want to capture.'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Split this TODO into smaller steps.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(TextField).first),
        isSemantics(
          label: 'TODO input',
          hint: 'Enter one task to split into smaller steps.',
          isTextField: true,
        ),
      );
      expect(
        tester.getSemantics(find.widgetWithText(FilledButton, 'Chunk TODO')),
        isSemantics(
          label: 'Chunk TODO',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Idea capture: goal -> proposed plan -> confirm creates an idea',
      (tester) async {
    final c = _fresh();
    await tester.pumpWidget(_app(c, const IdeaScreen()));

    await tester.enterText(find.byType(TextField).first, 'file my 2025 taxes');
    await tester.tap(find.text('Chunk TODO'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Proposed plan'), findsOneWidget);
    await tester.tap(find.text('Confirm plan'));
    await tester.pumpAndSettle();

    expect(c.ideas.length, 1);
    expect(find.text('Chunk TODO'), findsOneWidget); // back to capture
  });

  testWidgets('confirming a plan clears the goal and starting-context fields',
      (tester) async {
    final c = _fresh();
    await tester.pumpWidget(_app(c, const IdeaScreen()));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'practice pitch');
    await tester.enterText(fields.at(1), 'Slides are done, rehearse delivery.');
    await tester.tap(find.text('Chunk TODO'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm plan'));
    await tester.pumpAndSettle();

    // Back on the capture screen both inputs must be empty so the next TODO
    // does not silently inherit the previous starting context (issue #9).
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('Thinking state shows a progress bar that advances over time',
      (tester) async {
    final c = AppController(coordinator: Coordinator(_BlockingLlmClient()));
    await tester.pumpWidget(_app(c, const IdeaScreen()));

    unawaited(c.submitGoal('plan a small dinner'));
    await tester.pump();

    expect(find.text('Thinking…'), findsOneWidget);
    final bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    final initial = bar.value ?? 0;

    await tester.pump(const Duration(seconds: 3));
    final later = tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value ??
        0;

    expect(later, greaterThan(initial));
    expect(later, lessThan(1.0)); // never claims completion while waiting
    expect(find.textContaining('elapsed'), findsOneWidget);

    // Dispose the view so its periodic timer is cancelled before teardown.
    await tester.pumpWidget(const SizedBox());
  });

  test('estimatedThinkingProgress eases toward but never reaches 1', () {
    const expected = Duration(seconds: 18);
    expect(estimatedThinkingProgress(Duration.zero, expected), 0);
    final mid = estimatedThinkingProgress(const Duration(seconds: 6), expected);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(0.97));
    final far =
        estimatedThinkingProgress(const Duration(minutes: 10), expected);
    expect(far, lessThanOrEqualTo(0.97));
  });

  testWidgets('Execute: duration filter narrows the list', (tester) async {
    final c = _fresh();
    await c.submitGoal('clean the garage');
    c.confirmPlan();
    await tester.pumpWidget(_app(c, const ExecuteScreen()));

    expect(find.byIcon(Icons.calendar_today), findsNothing);
    expect(find.text('Do the main part of the work'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '15 min'));
    await tester.pump();

    // The 45-minute task is filtered out; a 15-minute one remains.
    expect(find.text('Do the main part of the work'), findsNothing);
    expect(find.text('Write down the outcome you want'), findsOneWidget);
  });

  testWidgets('Execute: grouped mode shows idea progress and can collapse',
      (tester) async {
    final c = _fresh();
    await c.submitGoal('clean the garage');
    final idea = c.confirmPlan();
    final first = c.tasksForIdea(idea.id).first;
    c.startTask(first.id);
    c.submitTask(first.id);
    c.satisfyCriterion(
      first.id,
      c.taskById(first.id).acceptanceCriteria.first.id,
    );
    c.approveTask(first.id);

    await tester.pumpWidget(_app(c, const ExecuteScreen()));

    expect(find.textContaining('1/5 tasks done'), findsOneWidget);
    expect(find.text('Micro tasks'), findsOneWidget);
    expect(find.text('Collect what you need to start'), findsOneWidget);

    await tester.tap(find.text('clean the garage'));
    await tester.pumpAndSettle();

    expect(find.text('Collect what you need to start'), findsNothing);
  });

  testWidgets('Acceptance gate: Approve is disabled until criteria are checked',
      (tester) async {
    final c = _fresh();
    await c.submitGoal('book the dentist');
    final idea = c.confirmPlan();
    final t = c.tasksForIdea(idea.id).first;
    c.startTask(t.id);
    c.submitTask(t.id);

    await tester.pumpWidget(_app(c, IdeaProgressScreen(taskId: t.id)));

    final approve = find.widgetWithText(FilledButton, 'Approve -> Done');
    expect(approve, findsOneWidget);
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);

    await tester.tap(approve);
    await tester.pump();
    expect(c.taskById(t.id).state, TaskState.done);
  });

  testWidgets('Task detail shows the selected task actions', (tester) async {
    final c = _fresh();
    await c.submitGoal('write a blog post');
    final idea = c.confirmPlan();
    final task = c.tasksForIdea(idea.id).first;
    await tester.pumpWidget(_app(c, IdeaProgressScreen(taskId: task.id)));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('Blocked task can be marked unstuck from progress view',
      (tester) async {
    final c = _fresh();
    await c.submitGoal('plan a trip');
    final idea = c.confirmPlan();
    final t = c.tasksForIdea(idea.id).first;
    c.startTask(t.id);
    c.blockTask(t.id, "don't know where to start");

    await tester.pumpWidget(_app(c, IdeaProgressScreen(taskId: t.id)));

    expect(find.text("I'm unstuck"), findsOneWidget);
    await tester.tap(find.text("I'm unstuck"));
    await tester.pump();

    expect(c.taskById(t.id).state, TaskState.inProgress);
  });

  testWidgets('Focus timer shows a live countdown while running',
      (tester) async {
    var now = DateTime(2026, 6, 6, 9);
    final c = _fresh(clock: () => now);
    await c.submitGoal('write a blog post');
    final idea = c.confirmPlan();
    final t = c.tasksForIdea(idea.id).first;
    c.startTask(t.id);

    await tester.pumpWidget(_app(c, IdeaProgressScreen(taskId: t.id)));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Focus timer'));
    await tester.pump();

    expect(find.textContaining('Time left'), findsOneWidget);
    expect(find.textContaining('15:00'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('14:59'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Stop timer'));
    await tester.pump();
  });
}
