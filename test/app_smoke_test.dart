import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/main.dart';
import 'package:stepwise/state/app_controller.dart';

void main() {
  testWidgets('app shell renders three tabs and switches to Execute',
      (tester) async {
    final c = AppController(coordinator: Coordinator(FakeLlmClient()));
    await c.submitGoal('Plan a weekend trip');
    c.confirmPlan();

    await tester.pumpWidget(StepwiseApp(controller: c));
    await tester.pumpAndSettle();

    expect(find.text('Idea'), findsWidgets);
    expect(find.text('Execute'), findsWidgets);
    expect(find.text('Trends'), findsWidgets);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Execute'));
    await tester.pumpAndSettle();
    // Seeded tasks appear in the Execute list.
    expect(find.text('Write down the outcome you want'), findsOneWidget);
  });
}
