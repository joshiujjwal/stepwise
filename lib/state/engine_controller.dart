import 'package:flutter/foundation.dart';

import '../coordinator/fake_llm_client.dart';
import '../coordinator/model_service.dart';
import '../coordinator/swappable_llm_client.dart';

/// Which planning engine is active.
enum EngineMode { demo, gemma }

/// Manages the on-device model lifecycle and swaps the app's [SwappableLlmClient]
/// between the offline demo planner and on-device Gemma. The app always starts
/// in [EngineMode.demo] so it is usable (and TestFlight-testable) with no model.
class EngineController extends ChangeNotifier {
  EngineController({required this.swappable, this.modelService});

  final SwappableLlmClient swappable;

  /// Null when on-device Gemma isn't configured for this build (e.g. no model
  /// URL supplied). Settings then only offers demo mode.
  final ModelService? modelService;

  EngineMode mode = EngineMode.demo;
  ModelState model = const ModelState(ModelPhase.unknown);

  bool get gemmaAvailable => modelService != null;
  String get engineLabel => swappable.engineLabel;

  Future<void> refreshStatus() async {
    final service = modelService;
    if (service == null) {
      model = const ModelState(ModelPhase.notInstalled);
      notifyListeners();
      return;
    }
    try {
      final installed = await service.isInstalled();
      model = ModelState(
        installed ? ModelPhase.ready : ModelPhase.notInstalled,
        progress: installed ? 1 : 0,
      );
    } catch (e) {
      model = ModelState(ModelPhase.error, error: '$e');
    }
    notifyListeners();
  }

  Future<void> downloadModel() async {
    final service = modelService;
    if (service == null) return;
    model = const ModelState(ModelPhase.downloading);
    notifyListeners();
    try {
      await for (final p in service.download()) {
        model = ModelState(ModelPhase.downloading, progress: p);
        notifyListeners();
      }
      model = const ModelState(ModelPhase.ready, progress: 1);
    } catch (e) {
      model = ModelState(ModelPhase.error, error: '$e');
    }
    notifyListeners();
  }

  /// Switch planning to on-device Gemma. Degrades gracefully to demo on failure
  /// so the app never gets stuck with a broken engine.
  Future<bool> enableGemma() async {
    final service = modelService;
    if (service == null) return false;
    try {
      final client = await service.activate();
      swappable.swap(client, label: 'On-device Gemma');
      mode = EngineMode.gemma;
      notifyListeners();
      return true;
    } catch (e) {
      model = ModelState(ModelPhase.error, error: '$e');
      notifyListeners();
      return false;
    }
  }

  void useDemo() {
    swappable.swap(FakeLlmClient(), label: 'Demo (offline)');
    mode = EngineMode.demo;
    notifyListeners();
  }
}
