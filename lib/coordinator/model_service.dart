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
String? resolveModelAccessToken({
  String? modelToken,
  String? azureBlobSasToken,
  String? huggingFaceToken,
}) {
  return modelToken ?? azureBlobSasToken ?? huggingFaceToken;
}

abstract interface class ModelService {
  /// A stable id used to check installation.
  String get modelId;

  Future<bool> isInstalled();

  /// Emits progress 0..1 while downloading; completes when installed.
  Stream<double> download();

  /// Build an [LlmClient] over the installed model.
  Future<LlmClient> activate();
}

enum GemmaModelSourceKind { network, asset, file }

class GemmaModelSource {
  const GemmaModelSource.network(this.location, {this.token})
      : kind = GemmaModelSourceKind.network;

  const GemmaModelSource.asset(this.location)
      : kind = GemmaModelSourceKind.asset,
        token = null;

  const GemmaModelSource.file(this.location)
      : kind = GemmaModelSourceKind.file,
        token = null;

  final GemmaModelSourceKind kind;
  final String location;
  final String? token;
}

/// Real [ModelService] backed by flutter_gemma. Defaults to a Gemma IT model
/// suitable for on-device JSON planning. Source is provided by the caller so
/// credentials and paths are never hard-coded.
class GemmaModelService implements ModelService {
  GemmaModelService({
    required this.source,
    this.modelType = ModelType.gemmaIt,
    this.maxTokens = 2048,
    String? id,
  }) : modelId = id ?? _modelIdFromSource(source.location);

  final GemmaModelSource source;
  final ModelType modelType;
  final int maxTokens;

  @override
  final String modelId;

  @override
  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(modelId);

  @override
  Stream<double> download() {
    final controller = StreamController<double>();
    try {
      final installRequest = switch (source.kind) {
        GemmaModelSourceKind.network =>
          FlutterGemma.installModel(modelType: modelType)
              .fromNetwork(source.location, token: source.token),
        GemmaModelSourceKind.asset => FlutterGemma.installModel(
            modelType: modelType,
          ).fromAsset(source.location),
        GemmaModelSourceKind.file => FlutterGemma.installModel(
            modelType: modelType,
          ).fromFile(source.location),
      };
      installRequest
          .withProgress((percent) {
            if (!controller.isClosed) {
              controller.add((percent / 100).clamp(0, 1));
            }
          })
          .install()
          .then((_) {
            if (!controller.isClosed) controller.add(1);
          })
          .catchError((Object e) {
            if (!controller.isClosed) {
              controller.addError(_wrapInstallError(e));
            }
          })
          .whenComplete(controller.close);
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(_wrapInstallError(e));
      }
      controller.close();
    }
    return controller.stream;
  }

  @override
  Future<LlmClient> activate() =>
      GemmaLlmClient.create(modelType: modelType, maxTokens: maxTokens);

  static String _modelIdFromSource(String sourceLocation) {
    final uri = Uri.tryParse(sourceLocation);
    final rawName = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : sourceLocation.split('/').last;
    return rawName
        .replaceFirst(RegExp(r'\.litertlm$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\.task$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\.bin$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\.tflite$', caseSensitive: false), '');
  }

  Object _wrapInstallError(Object error) {
    if (source.kind == GemmaModelSourceKind.asset) {
      return 'Asset install failed for "${source.location}". '
          'Ensure the file exists and is declared under "flutter/assets" in pubspec.yaml. '
          'Original error: $error';
    }
    return error;
  }
}
