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

AppController _fresh() =>
    AppController(coordinator: Coordinator(FakeLlmClient()));

Widget _app(AppController c, Widget home) =>
    AppScope(controller: c, child: MaterialApp(home: home));

void main() {
  testWidgets('Idea capture: goal -> proposed plan -> confirm creates an idea',
      (tester) async {
    final c = _fresh();
    await tester.pumpWidget(_app(c, const IdeaScreen()));

    await tester.enterText(find.byType(TextField), 'file my 2025 taxes');
    await tester.tap(find.text('Start planning'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Proposed plan'), findsOneWidget);
    await tester.tap(find.text('Confirm plan'));
    await tester.pumpAndSettle();

    expect(c.ideas.length, 1);
    expect(find.text('Start planning'), findsOneWidget); // back to capture
  });

  testWidgets('Execute: duration filter narrows the list', (tester) async {
    final c = _fresh();
    await c.submitGoal('clean the garage');
    c.confirmPlan();
    await tester.pumpWidget(_app(c, const ExecuteScreen()));

    expect(find.text('Do the main part of the work'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '15 min'));
    await tester.pump();

    // The 45-minute task is filtered out; a 15-minute one remains.
    expect(find.text('Do the main part of the work'), findsNothing);
    expect(find.text('Write down the outcome you want'), findsOneWidget);
  });

  testWidgets('Acceptance gate: Approve is disabled until criteria are checked',
      (tester) async {
    final c = _fresh();
    await c.submitGoal('book the dentist');
    final idea = c.confirmPlan();
    final t = c.tasksForIdea(idea.id).first;
    c.startTask(t.id);
    c.submitTask(t.id);

    await tester.pumpWidget(_app(c, IdeaProgressScreen(ideaId: idea.id)));

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

  testWidgets('Idea progress shows step N of M', (tester) async {
    final c = _fresh();
    await c.submitGoal('write a blog post');
    final idea = c.confirmPlan();
    await tester.pumpWidget(_app(c, IdeaProgressScreen(ideaId: idea.id)));
    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
  });
}
