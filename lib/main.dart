import 'package:flutter/material.dart';

import 'coordinator/fake_llm_client.dart';
import 'coordinator/model_service.dart';
import 'coordinator/planner.dart';
import 'coordinator/swappable_llm_client.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'state/engine_controller.dart';
import 'state/engine_scope.dart';
import 'theme/app_theme.dart';
import 'ui/execute_screen.dart';
import 'ui/idea_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/trends_screen.dart';

Future<void> main() async {
  // The app starts in offline demo mode so it is fully usable with no model
  // download. On-device Gemma can be enabled from Settings once a model URL is
  // configured below (see _gemmaService).
  final llm = SwappableLlmClient(FakeLlmClient());
  final controller = AppController(coordinator: Coordinator(llm));
  final engine =
      EngineController(swappable: llm, modelService: _gemmaService());

  await _seedDemo(controller);
  runApp(StepwiseApp(controller: controller, engine: engine));
}

/// Configure on-device Gemma by returning a GemmaModelService with your model
/// URL (e.g. a Gemma IT .task on Hugging Face). Returns null -> Settings shows
/// demo-only. Kept out of source control by default so no token ships in git.
///
/// Example:
///   return GemmaModelService(
///     modelUrl: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it.task',
///     huggingFaceToken: const String.fromEnvironment('HF_TOKEN'),
///   );
ModelService? _gemmaService() => null;

Future<void> _seedDemo(AppController controller) async {
  await controller.submitGoal('Plan a weekend trip');
  if (controller.session?.phase == PlanningPhase.proposed) {
    controller.confirmPlan();
  }
}

class StepwiseApp extends StatelessWidget {
  const StepwiseApp({
    super.key,
    required this.controller,
    required this.engine,
  });

  final AppController controller;
  final EngineController engine;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: EngineScope(
        controller: engine,
        child: MaterialApp(
          title: 'stepwise',
          theme: buildStepwiseTheme(),
          debugShowCheckedModeBanner: false,
          home: const HomeShell(),
        ),
      ),
    );
  }
}

/// Idea | Execute | Trends | Settings (spec section 11 + engine management).
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
    SettingsScreen(),
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
