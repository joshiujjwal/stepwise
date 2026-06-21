import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/coordinator/swappable_llm_client.dart';
import 'package:stepwise/main.dart';
import 'package:stepwise/state/app_controller.dart';
import 'package:stepwise/state/engine_controller.dart';

/// Drives the REAL StepwiseApp through the whole user journey across every tab
/// (capture -> confirm -> execute -> timer -> acceptance gate -> approve ->
/// trends -> settings, plus the calendar view). Headless, so it runs in CI.
void main() {
  ({AppController controller, EngineController engine}) build() {
    final llm = SwappableLlmClient(FakeLlmClient());
    final controller = AppController(coordinator: Coordinator(llm));
    final engine = EngineController(swappable: llm, modelService: null);
    return (controller: controller, engine: engine);
  }

  testWidgets('end-to-end: capture an idea, complete a task, see it in Trends',
      (tester) async {
    final app = build();
    await tester.pumpWidget(
      StepwiseApp(controller: app.controller, engine: app.engine),
    );
    await tester.pumpAndSettle();

    // --- Idea tab: type a goal and start planning ---
    expect(find.text('Chunk TODO'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Organize the garage');
    await tester.tap(find.text('Chunk TODO'));
    await tester.pumpAndSettle();

    // The coordinator proposed a plan; confirm it.
    expect(find.textContaining('Proposed plan'), findsOneWidget);
    await tester.tap(find.text('Confirm plan'));
    await tester.pumpAndSettle();
    expect(app.controller.ideas, hasLength(1));
    final ideaId = app.controller.ideas.single.id;

    // --- Execute tab: the new tasks are listed ---
    await tester.tap(find.widgetWithText(NavigationDestination, 'Execute'));
    await tester.pumpAndSettle();
    expect(find.text('Write down the outcome you want'), findsOneWidget);

    // Filter to 15-minute tasks; the 45m task disappears.
    await tester.tap(find.widgetWithText(ChoiceChip, '15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Do the main part of the work'), findsNothing);

    // Open a task -> task detail screen.
    await tester.tap(find.text('Write down the outcome you want'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.calendar_today), findsNothing);

    // Start it, run the focus timer, then submit for approval. Scope to the
    // first task card (every todo task renders its own Start button).
    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Focus timer'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Stop timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit for approval'));
    await tester.pumpAndSettle();

    // Acceptance gate: Approve is disabled until the criterion is checked.
    final approve = find.widgetWithText(FilledButton, 'Approve -> Done');
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.tap(approve);
    await tester.pumpAndSettle();

    // One task done.
    expect(app.controller.progressForIdea(ideaId).percentComplete, 20);

    // Pop back from the pushed detail route to reach the bottom nav.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // --- Trends tab reflects the completion ---
    await tester.tap(find.widgetWithText(NavigationDestination, 'Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);

    // --- Settings tab renders engine status + privacy note ---
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.text('AI engine'), findsOneWidget);
    expect(find.textContaining('never'), findsOneWidget);
  });

  testWidgets('execute list does not expose the calendar view', (tester) async {
    final app = build();
    await app.controller.submitGoal('Plan a trip');
    app.controller.confirmPlan();
    await tester.pumpWidget(
      StepwiseApp(controller: app.controller, engine: app.engine),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Execute'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.calendar_today), findsNothing);
    expect(find.textContaining('Unscheduled'), findsNothing);
  });
}
