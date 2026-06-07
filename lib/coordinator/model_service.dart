import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'gemma_llm_client.dart';
import 'planner.dart';

/// Download/availability state of the on-device model.
enum ModelPhase { unknown, notInstalled, downloading, ready, error }

class ModelState {
  const ModelState(this.phase, {this.progress = 0, this.error});
  final ModelPhase phase;
  final double progress; // 0..1 while downloading
  final String? error;

  ModelState copyWith({ModelPhase? phase, double? progress, String? error}) =>
      ModelState(phase ?? this.phase,
          progress: progress ?? this.progress, error: error);
}

/// Abstraction over the on-device model lifecycle, so Settings logic can be
/// tested with a fake (the real one needs native MediaPipe + a multi-GB model).
abstract interface class ModelService {
  /// A stable id used to check installation.
  String get modelId;

  Future<bool> isInstalled();

  /// Emits progress 0..1 while downloading; completes when installed.
  Stream<double> download();

  /// Build an [LlmClient] over the installed model.
  Future<LlmClient> activate();
}

/// Real [ModelService] backed by flutter_gemma. Defaults to a Gemma IT model
/// suitable for on-device JSON planning. The URL/token are provided by the
/// caller (Settings) so no credentials are hard-coded.
class GemmaModelService implements ModelService {
  GemmaModelService({
    required this.modelUrl,
    this.modelType = ModelType.gemmaIt,
    this.maxTokens = 2048,
    this.huggingFaceToken,
    String? id,
  }) : modelId = id ?? Uri.parse(modelUrl).pathSegments.last;

  final String modelUrl;
  final ModelType modelType;
  final int maxTokens;
  final String? huggingFaceToken;

  @override
  final String modelId;

  @override
  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(modelId);

  @override
  Stream<double> download() {
    final controller = StreamController<double>();
    FlutterGemma.installModel(modelType: modelType)
        .fromNetwork(modelUrl, token: huggingFaceToken)
        .withProgress((percent) {
          if (!controller.isClosed) controller.add((percent / 100).clamp(0, 1));
        })
        .install()
        .then((_) {
          if (!controller.isClosed) controller.add(1);
        })
        .catchError((Object e) {
          if (!controller.isClosed) controller.addError(e);
        })
        .whenComplete(controller.close);
    return controller.stream;
  }

  @override
  Future<LlmClient> activate() =>
      GemmaLlmClient.create(modelType: modelType, maxTokens: maxTokens);
}
