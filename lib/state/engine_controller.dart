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

  /// A user-facing label describing the active (or activating) engine. While the
  /// configured model downloads on startup this reports the download progress so
  /// the user can see Gemma is the default engine coming online, not demo.
  String get engineStatusLabel {
    if (mode == EngineMode.gemma) return engineLabel;
    switch (model.phase) {
      case ModelPhase.downloading:
        return 'Setting up on-device Gemma…';
      case ModelPhase.ready:
        return 'On-device Gemma (starting…)';
      case ModelPhase.error:
        return '$engineLabel — model download failed';
      case ModelPhase.unknown:
      case ModelPhase.notInstalled:
        return engineLabel;
    }
  }

  /// Bring up the preferred engine on startup. When a model service is
  /// configured (e.g. an Azure-hosted Gemma model) this downloads it if needed
  /// and switches the app to on-device Gemma, so the app defaults to Gemma
  /// instead of the offline demo planner. With no model configured it stays on
  /// the demo planner so the app is still usable.
  Future<void> initialize() async {
    if (modelService == null) return;
    await refreshStatus();
    if (model.phase == ModelPhase.notInstalled) {
      await downloadModel();
    }
    if (model.phase == ModelPhase.ready) {
      await enableGemma();
    }
  }

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
