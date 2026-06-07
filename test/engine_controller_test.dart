import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/model_service.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/coordinator/swappable_llm_client.dart';
import 'package:stepwise/state/engine_controller.dart';

/// A ModelService that needs no native code, for testing engine logic.
class _FakeModelService implements ModelService {
  _FakeModelService({this.installed = false, this.failActivate = false});
  bool installed;
  final bool failActivate;

  @override
  String get modelId => 'fake-model';

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Stream<double> download() async* {
    yield 0.5;
    yield 1.0;
    installed = true;
  }

  @override
  Future<LlmClient> activate() async {
    if (failActivate) throw StateError('activate failed');
    return FakeLlmClient();
  }
}

void main() {
  test('SwappableLlmClient forwards and swaps delegate', () async {
    final scripted = FakeLlmClient(
        scripted: ['{"action":"ask_clarifying","questions":["q here?"]}']);
    final swap = SwappableLlmClient(scripted, engineLabel: 'A');
    expect(swap.engineLabel, 'A');
    final out = await swap.complete(system: 's', user: 'u');
    expect(out, contains('ask_clarifying'));

    swap.swap(FakeLlmClient(), label: 'B');
    expect(swap.engineLabel, 'B');
  });

  test('engine starts in demo and reports gemma availability', () {
    final swap = SwappableLlmClient(FakeLlmClient());
    final engine = EngineController(swappable: swap, modelService: null);
    expect(engine.mode, EngineMode.demo);
    expect(engine.gemmaAvailable, isFalse);
  });

  test('download then enable swaps to gemma; useDemo swaps back', () async {
    final swap = SwappableLlmClient(FakeLlmClient());
    final engine =
        EngineController(swappable: swap, modelService: _FakeModelService());

    await engine.refreshStatus();
    expect(engine.model.phase, ModelPhase.notInstalled);

    await engine.downloadModel();
    expect(engine.model.phase, ModelPhase.ready);

    final ok = await engine.enableGemma();
    expect(ok, isTrue);
    expect(engine.mode, EngineMode.gemma);
    expect(swap.engineLabel, 'On-device Gemma');

    engine.useDemo();
    expect(engine.mode, EngineMode.demo);
    expect(swap.engineLabel, 'Demo (offline)');
  });

  test('enableGemma degrades gracefully on failure', () async {
    final swap = SwappableLlmClient(FakeLlmClient());
    final engine = EngineController(
      swappable: swap,
      modelService: _FakeModelService(installed: true, failActivate: true),
    );
    final ok = await engine.enableGemma();
    expect(ok, isFalse);
    expect(engine.mode, EngineMode.demo); // stayed on demo
    expect(engine.model.phase, ModelPhase.error);
  });
}
