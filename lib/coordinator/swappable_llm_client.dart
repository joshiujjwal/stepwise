import 'planner.dart';

/// An [LlmClient] that forwards to a swappable delegate. Lets the app start in
/// offline demo mode and switch to on-device Gemma at runtime (once a model is
/// downloaded) without rebuilding the controller/coordinator.
class SwappableLlmClient implements LlmClient {
  SwappableLlmClient(this._delegate, {this.engineLabel = 'Demo (offline)'});

  LlmClient _delegate;

  /// Human-readable name of the active engine, shown in Settings.
  String engineLabel;

  LlmClient get delegate => _delegate;

  void swap(LlmClient delegate, {required String label}) {
    _delegate = delegate;
    engineLabel = label;
  }

  @override
  Future<String> complete({required String system, required String user}) =>
      _delegate.complete(system: system, user: user);
}
