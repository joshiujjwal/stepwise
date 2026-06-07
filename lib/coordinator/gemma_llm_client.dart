import 'package:flutter_gemma/flutter_gemma.dart';

import 'planner.dart';

/// On-device [LlmClient] backed by flutter_gemma (spec / ADR 0002).
///
/// Not unit-tested: it needs a real model on a device/simulator. The app uses
/// [FakeLlmClient] by default (demo mode); swap this in once a model is loaded:
///
/// ```dart
/// final llm = await GemmaLlmClient.create();      // after the model is installed
/// final controller = AppController(coordinator: Coordinator(llm));
/// ```
///
/// Model installation/download is handled per the flutter_gemma docs (Phase 0).
class GemmaLlmClient implements LlmClient {
  GemmaLlmClient(this._model);

  final InferenceModel _model;

  /// Create a client over an already-installed model. Defaults to Gemma IT
  /// (e.g. Gemma 3 1B) which is the planning sweet spot for on-device JSON.
  static Future<GemmaLlmClient> create({
    ModelType modelType = ModelType.gemmaIt,
    int maxTokens = 2048,
  }) async {
    final model = await FlutterGemmaPlugin.instance.createModel(
      modelType: modelType,
      maxTokens: maxTokens,
    );
    return GemmaLlmClient(model);
  }

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    // Low temperature for consistent, schema-shaped planning output.
    final session = await _model.createSession(
      temperature: 0.2,
      systemInstruction: system,
    );
    try {
      await session.addQueryChunk(Message.text(text: user, isUser: true));
      return await session.getResponse();
    } finally {
      await session.close();
    }
  }

  Future<void> dispose() => _model.close();
}
