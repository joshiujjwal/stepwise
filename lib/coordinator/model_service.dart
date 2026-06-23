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
    ModelFileType? fileType,
  })  : modelId = id ?? _modelIdFromSource(source.location),
        fileType = fileType ?? _fileTypeFromSource(source.location);

  final GemmaModelSource source;
  final ModelType modelType;
  final int maxTokens;

  /// The on-disk format of the model file, derived from its extension unless
  /// overridden. This is required so `.litertlm` models route to the LiteRT/FFI
  /// path instead of MediaPipe (which only loads `.task` bundles).
  final ModelFileType fileType;

  @override
  final String modelId;

  @override
  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(modelId);

  @override
  Stream<double> download() {
    final controller = StreamController<double>();
    try {
      _buildInstallRequest()
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
  Future<LlmClient> activate() async {
    // Ensure an active inference model is set before createModel(). install() is
    // idempotent: when the file is already on disk it skips the download and
    // just (re)registers + activates it with the correct fileType. This fixes
    // the "No active inference model set" error after an app restart and keeps
    // .litertlm models on the LiteRT/FFI path.
    await _buildInstallRequest().install();
    return GemmaLlmClient.create(
      modelType: modelType,
      fileType: fileType,
      maxTokens: maxTokens,
    );
  }

  InferenceInstallationBuilder _buildInstallRequest() {
    final builder =
        FlutterGemma.installModel(modelType: modelType, fileType: fileType);
    return switch (source.kind) {
      GemmaModelSourceKind.network =>
        builder.fromNetwork(source.location, token: source.token),
      GemmaModelSourceKind.asset => builder.fromAsset(source.location),
      GemmaModelSourceKind.file => builder.fromFile(source.location),
    };
  }

  /// The model id must match the identifier flutter_gemma registers on install,
  /// which is the source file's basename *including* its extension
  /// (e.g. `gemma3-1b-it.task`). Stripping the extension here would make
  /// [isInstalled] miss the on-disk model and re-download it every launch.
  static String _modelIdFromSource(String sourceLocation) {
    final uri = Uri.tryParse(sourceLocation);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return sourceLocation.split(RegExp(r'[/\\]')).last;
  }

  /// Maps the model file extension to the [ModelFileType] flutter_gemma uses to
  /// pick a loader. `.litertlm` → LiteRT (FFI on iOS), `.bin`/`.tflite` →
  /// binary, everything else → MediaPipe `.task`.
  static ModelFileType _fileTypeFromSource(String sourceLocation) {
    final id = _modelIdFromSource(sourceLocation);
    final dot = id.lastIndexOf('.');
    final ext = dot == -1 ? '' : id.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'litertlm' => ModelFileType.litertlm,
      'bin' || 'tflite' => ModelFileType.binary,
      _ => ModelFileType.task,
    };
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
