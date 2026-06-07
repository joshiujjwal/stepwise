import 'package:flutter/material.dart';

import 'coordinator/fake_llm_client.dart';
import 'coordinator/planner.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'ui/execute_screen.dart';
import 'ui/idea_screen.dart';
import 'ui/trends_screen.dart';

Future<void> main() async {
  // Demo mode: an offline planner so the app is fully usable with no model.
  // Swap FakeLlmClient -> GemmaLlmClient to run on-device Gemma (see
  // lib/coordinator/gemma_llm_client.dart).
  final controller = AppController(coordinator: Coordinator(FakeLlmClient()));
  await _seedDemo(controller);
  runApp(StepwiseApp(controller: controller));
}

Future<void> _seedDemo(AppController controller) async {
  await controller.submitGoal('Plan a weekend trip');
  if (controller.session?.phase == PlanningPhase.proposed) {
    controller.confirmPlan();
  }
}

class StepwiseApp extends StatelessWidget {
  const StepwiseApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'stepwise',
        theme: buildStepwiseTheme(),
        debugShowCheckedModeBanner: false,
        home: const HomeShell(),
      ),
    );
  }
}

/// Two primary tabs - Idea | Execute - plus Trends (spec section 11).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _tabs = [
    IdeaScreen(),
    ExecuteScreen(),
    TrendsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Idea',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: 'Execute',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Trends',
          ),
        ],
      ),
    );
  }
}
