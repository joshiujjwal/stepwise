import 'package:flutter/widgets.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stepwise/coordinator/model_service.dart';
import 'package:stepwise/coordinator/planner.dart';

/// On-simulator end-to-end check of the REAL on-device Gemma model.
///
/// Loads the model from `GEMMA_MODEL_FILE`, then drives the same
/// `Coordinator.plan` path the app uses and asserts the model returns a
/// schema-valid plan (or a clarifying turn) rather than crashing / emitting
/// gibberish that fails validation even after the repair retry.
///
/// Run:
///   flutter test integration_test/model_plan_test.dart -d SIMULATOR_ID \
///     --dart-define=GEMMA_MODEL_FILE=$PWD/model/gemma-3n-E2B-it-int4.litertlm \
///     --dart-define=GEMMA_MODEL_TYPE=gemmaIt
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const modelFile = String.fromEnvironment('GEMMA_MODEL_FILE');

  test('real Gemma model produces a schema-valid plan', () async {
    expect(
      modelFile,
      isNotEmpty,
      reason: 'Pass --dart-define=GEMMA_MODEL_FILE=/abs/path/to/model',
    );

    // The plugin must be initialized before use (main() does this in the app).
    WidgetsFlutterBinding.ensureInitialized();
    await FlutterGemma.initialize();

    final service = GemmaModelService(
      source: const GemmaModelSource.file(modelFile),
    );
    final llm = await service.activate();
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'buy groceries');

    switch (response) {
      case PlanResponse():
        expect(response.tasks, isNotEmpty,
            reason: 'a proposed plan must contain at least one task');
        for (final t in response.tasks) {
          expect(t.title.trim(), isNotEmpty);
          expect(t.estMinutes, inInclusiveRange(5, 60));
          expect(t.estMinutes % 5, 0);
          expect(t.acceptanceCriteria, isNotEmpty);
        }
      case ClarifyResponse():
        expect(response.questions, isNotEmpty,
            reason: 'a clarifying turn must ask at least one question');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
