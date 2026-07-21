import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'gemma_llm_client.dart';
import 'planner.dart';

/// Download/availability state of the on-device model.
enum ModelPhase { unknown, notInstalled, downloading, ready, error }

class ModelState {
  const ModelState(
    this.phase, {
    this.progress = 0,
    this.bytesPerSecond,
    this.downloadedBytes,
    this.totalBytes,
    this.error,
  });
  final ModelPhase phase;
  final double progress; // 0..1 while downloading

  /// Smoothed download speed in bytes/second, or null when the total model
  /// size is unknown (flutter_gemma only reports percent, so a configured
  /// size is required to derive a byte rate).
  final double? bytesPerSecond;

  /// Bytes downloaded so far, derived from [progress] × total size. Null when
  /// the total size is unknown.
  final int? downloadedBytes;

  /// Total model size in bytes, when known.
  final int? totalBytes;
  final String? error;

  ModelState copyWith({
    ModelPhase? phase,
    double? progress,
    double? bytesPerSecond,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
  }) =>
      ModelState(
        phase ?? this.phase,
        progress: progress ?? this.progress,
        bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        error: error,
      );
}

/// A single download progress observation, carrying enough to render a
/// speedtest-style readout (percentage, live MB/s, and downloaded/total size).
class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.fraction,
    this.bytesPerSecond,
    this.downloadedBytes,
    this.totalBytes,
  });

  /// Overall completion, 0..1.
  final double fraction;

  /// Smoothed transfer rate in bytes/second, or null when unknown.
  final double? bytesPerSecond;

  /// Bytes transferred so far, or null when the total size is unknown.
  final int? downloadedBytes;

  /// Total bytes to transfer, or null when unknown.
  final int? totalBytes;
}

/// Turns flutter_gemma's percent-only progress into a smoothed byte rate.
///
/// flutter_gemma's `withProgress` callback only surfaces an integer percent
/// (0–100) — no byte counters — so a live MB/s readout needs the configured
/// [totalBytes] plus timing between updates. An exponential moving average
/// ([smoothing] is the weight of the newest sample) keeps the number steady
/// instead of jittering with each callback.
class DownloadSpeedTracker {
  DownloadSpeedTracker({this.totalBytes, double smoothing = 0.3})
      : assert(smoothing > 0 && smoothing <= 1),
        _smoothing = smoothing;

  final int? totalBytes;
  final double _smoothing;

  double? _lastFraction;
  Duration? _lastElapsed;
  double? _emaBytesPerSecond;

  /// Records a new [fraction] (0..1) observed at [elapsed] since the download
  /// started and returns the derived progress snapshot.
  ModelDownloadProgress update(double fraction, Duration elapsed) {
    final clamped = fraction.clamp(0.0, 1.0).toDouble();
    final total = totalBytes;
    if (total != null && _lastFraction != null && _lastElapsed != null) {
      final dtSeconds = (elapsed - _lastElapsed!).inMicroseconds /
          Duration.microsecondsPerSecond;
      final deltaBytes = (clamped - _lastFraction!) * total;
      if (dtSeconds > 0 && deltaBytes >= 0) {
        final instant = deltaBytes / dtSeconds;
        _emaBytesPerSecond = _emaBytesPerSecond == null
            ? instant
            : _emaBytesPerSecond! * (1 - _smoothing) + instant * _smoothing;
      }
    }
    _lastFraction = clamped;
    _lastElapsed = elapsed;
    return ModelDownloadProgress(
      fraction: clamped,
      bytesPerSecond: total == null ? null : _emaBytesPerSecond,
      downloadedBytes: total == null ? null : (clamped * total).round(),
      totalBytes: total,
    );
  }
}

/// Formats a byte rate as a compact, human-readable speed (e.g. `12.3 MB/s`).
/// Returns an empty string when the rate is unknown or non-positive.
String formatDownloadSpeed(double? bytesPerSecond) {
  if (bytesPerSecond == null || bytesPerSecond <= 0) return '';
  const kb = 1024.0;
  const mb = kb * 1024;
  if (bytesPerSecond >= mb) {
    return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/s';
  }
  return '${(bytesPerSecond / kb).toStringAsFixed(0)} KB/s';
}

/// Formats a byte count as a compact size (e.g. `420 MB`, `1.05 GB`).
/// Returns an empty string when [bytes] is null.
String formatBytes(int? bytes) {
  if (bytes == null) return '';
  const kb = 1024.0;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(0)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
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

/// Appends an Azure Blob **SAS** to [url] as a query string.
///
/// Azure authenticates SAS via the URL query (`?sv=...&sig=...`), NOT an
/// `Authorization: Bearer` header — which is the only way flutter_gemma sends a
/// `token`. Passing a SAS as a token therefore yields a 403
/// `AuthenticationFailed` (commonly seen when the model blob lives in a
/// different storage account/region). Appending it here fixes that.
///
/// Idempotent: returns [url] unchanged when [sas] is empty or the URL already
/// carries a SAS signature (`sig=`). Tolerates a leading `?`/`&` on [sas].
String appendSasToken(String url, String sas) {
  final trimmed = sas.trim().replaceFirst(RegExp(r'^[?&]+'), '');
  if (trimmed.isEmpty) return url;
  if (RegExp(r'[?&]sig=').hasMatch(url)) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url$separator$trimmed';
}

/// Builds a network [GemmaModelSource] with the correct auth mechanism.
///
/// Precedence:
/// 1. An explicit [modelToken] is sent as a Bearer header (private HF/GCS).
/// 2. An [azureBlobSasToken] is appended to the URL query string and sent
///    with NO token, because Azure ignores Bearer auth for SAS.
/// 3. A [huggingFaceToken] is sent as a Bearer header.
GemmaModelSource buildModelNetworkSource({
  required String url,
  String? modelToken,
  String? azureBlobSasToken,
  String? huggingFaceToken,
}) {
  if (modelToken != null && modelToken.isNotEmpty) {
    return GemmaModelSource.network(url, token: modelToken);
  }
  if (azureBlobSasToken != null && azureBlobSasToken.isNotEmpty) {
    return GemmaModelSource.network(appendSasToken(url, azureBlobSasToken));
  }
  if (huggingFaceToken != null && huggingFaceToken.isNotEmpty) {
    return GemmaModelSource.network(url, token: huggingFaceToken);
  }
  return GemmaModelSource.network(url);
}

/// Chooses the network model source from the configured URLs.
///
/// A [cdnUrl] (e.g. Azure Front Door) wins and is fetched **tokenless**: the
/// edge handles origin auth via a Front Door rule or a public models container,
/// so attaching a Bearer token or SAS would defeat edge caching and can 403.
/// Any [modelToken] / [azureBlobSasToken] are deliberately ignored for a CDN
/// URL. Otherwise falls back to a direct-origin [modelUrl] via
/// [buildModelNetworkSource].
///
/// Throws [ArgumentError] if neither URL is provided.
GemmaModelSource selectModelNetworkSource({
  String? cdnUrl,
  String? modelUrl,
  String? modelToken,
  String? azureBlobSasToken,
  String? huggingFaceToken,
}) {
  if (cdnUrl != null && cdnUrl.isNotEmpty) {
    return GemmaModelSource.network(cdnUrl);
  }
  if (modelUrl != null && modelUrl.isNotEmpty) {
    return buildModelNetworkSource(
      url: modelUrl,
      modelToken: modelToken,
      azureBlobSasToken: azureBlobSasToken,
      huggingFaceToken: huggingFaceToken,
    );
  }
  throw ArgumentError('No model URL configured (cdnUrl or modelUrl required).');
}

abstract interface class ModelService {
  /// A stable id used to check installation.
  String get modelId;

  Future<bool> isInstalled();

  /// Emits progress while downloading; completes when installed.
  Stream<ModelDownloadProgress> download();

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
    this.sizeBytes,
    String? id,
    ModelFileType? fileType,
  })  : modelId = id ?? _modelIdFromSource(source.location),
        fileType = fileType ?? _fileTypeFromSource(source.location);

  final GemmaModelSource source;
  final ModelType modelType;
  final int maxTokens;

  /// Total download size in bytes, when known ahead of time (e.g. from a
  /// build-time `GEMMA_MODEL_SIZE_BYTES` define). Optional: for network
  /// downloads the size is auto-detected via an HTTP `Content-Length` probe,
  /// so the live MB/s readout works without this. When set, it takes precedence
  /// over the probe (useful for CDNs that reject `HEAD`).
  final int? sizeBytes;

  /// The on-disk format of the model file, derived from its extension unless
  /// overridden. This is required so `.litertlm` models route to the LiteRT/FFI
  /// path instead of MediaPipe (which only loads `.task` bundles).
  final ModelFileType fileType;

  @override
  final String modelId;

  @override
  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(modelId);

  @override
  Stream<ModelDownloadProgress> download() {
    final controller = StreamController<ModelDownloadProgress>();
    _runDownload(controller);
    return controller.stream;
  }

  /// Resolves the total size (configured or probed), then installs while
  /// forwarding a byte-rate-aware progress snapshot on every percent update.
  Future<void> _runDownload(
      StreamController<ModelDownloadProgress> controller) async {
    final total = sizeBytes ?? await probeTotalBytes();
    final tracker = DownloadSpeedTracker(totalBytes: total);
    final stopwatch = Stopwatch()..start();
    try {
      await _buildInstallRequest().withProgress((percent) {
        if (!controller.isClosed) {
          controller.add(tracker.update(percent / 100, stopwatch.elapsed));
        }
      }).install();
      if (!controller.isClosed) {
        controller.add(tracker.update(1, stopwatch.elapsed));
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(_wrapInstallError(e));
      }
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  /// Best-effort `Content-Length` probe for network models, so the download UI
  /// can show a live MB/s rate and downloaded/total size without a configured
  /// [sizeBytes]. Returns null for non-network sources or on any failure (a
  /// missing size just degrades the UI to a percentage-only readout).
  Future<int?> probeTotalBytes() async {
    if (source.kind != GemmaModelSourceKind.network) return null;
    final uri = Uri.tryParse(source.location);
    if (uri == null) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.headUrl(uri);
      final token = source.token;
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, token);
      }
      final response = await request.close();
      await response.drain<void>();
      final length = response.contentLength;
      return length > 0 ? length : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
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
