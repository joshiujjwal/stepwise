import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/model_service.dart';
import 'package:stepwise/main.dart';

void main() {
  test('infers the litertlm file type from the model extension', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.network(
        'https://example.com/gemma-3n-E2B-it-int4.litertlm?sp=r&sig=abc',
      ),
    );

    expect(service.fileType, ModelFileType.litertlm);
  });

  test('infers the task file type for .task models', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.file('/tmp/models/gemma3-1b-it.task'),
    );

    expect(service.fileType, ModelFileType.task);
  });

  test('infers the binary file type for .bin and .tflite models', () {
    expect(
      GemmaModelService(
        source: const GemmaModelSource.file('/tmp/models/model.bin'),
      ).fileType,
      ModelFileType.binary,
    );
    expect(
      GemmaModelService(
        source: const GemmaModelSource.file('/tmp/models/model.tflite'),
      ).fileType,
      ModelFileType.binary,
    );
  });

  test('honors an explicit fileType override', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.file('/tmp/models/model.task'),
      fileType: ModelFileType.litertlm,
    );

    expect(service.fileType, ModelFileType.litertlm);
  });

  test('model id keeps the network filename and extension', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.network(
        'http://10.0.0.108:8000/gemma-3n-E2B-it-int4.litertlm',
      ),
    );

    expect(service.modelId, 'gemma-3n-E2B-it-int4.litertlm');
  });

  test('model id keeps the file basename and extension', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.file(
        '/tmp/models/gemma3-1b-it.task',
      ),
    );

    expect(service.modelId, 'gemma3-1b-it.task');
  });

  test('prefers explicit model token over Azure and Hugging Face fallbacks',
      () {
    expect(
      resolveModelAccessToken(
        modelToken: 'explicit-sas',
        azureBlobSasToken: 'azure-sas',
        huggingFaceToken: 'hf-token',
      ),
      'explicit-sas',
    );
  });

  test('falls back to Azure Blob SAS token when no explicit token is provided',
      () {
    expect(
      resolveModelAccessToken(
        modelToken: null,
        azureBlobSasToken: 'azure-sas',
        huggingFaceToken: 'hf-token',
      ),
      'azure-sas',
    );
  });

  test('falls back to Hugging Face token when no other token is configured',
      () {
    expect(
      resolveModelAccessToken(
        modelToken: null,
        azureBlobSasToken: null,
        huggingFaceToken: 'hf-token',
      ),
      'hf-token',
    );
  });

  test('reads a value from the process environment when no define is provided',
      () {
    expect(
      readConfigValue(
        'AZURE_BLOB_SAS_TOKEN',
        environment: {'AZURE_BLOB_SAS_TOKEN': 'env-sas'},
      ),
      'env-sas',
    );
  });

  group('appendSasToken', () {
    const url = 'https://acct.blob.core.windows.net/models/gemma.litertlm';

    test('appends a bare SAS with a leading ?', () {
      expect(
        appendSasToken(url, 'sv=2023&sig=abc'),
        '$url?sv=2023&sig=abc',
      );
    });

    test('tolerates a leading ? or & on the SAS', () {
      expect(appendSasToken(url, '?sv=2023&sig=abc'), '$url?sv=2023&sig=abc');
      expect(appendSasToken(url, '&sv=2023&sig=abc'), '$url?sv=2023&sig=abc');
    });

    test('uses & when the URL already has a query string', () {
      expect(
        appendSasToken('$url?foo=1', 'sv=2023&sig=abc'),
        '$url?foo=1&sv=2023&sig=abc',
      );
    });

    test('is a no-op when the URL already carries a SAS signature', () {
      const withSas = '$url?sv=2023&sig=existing';
      expect(appendSasToken(withSas, 'sv=2023&sig=other'), withSas);
    });

    test('is a no-op for an empty SAS', () {
      expect(appendSasToken(url, ''), url);
      expect(appendSasToken(url, '   '), url);
    });
  });

  group('buildModelNetworkSource', () {
    const url = 'https://acct.blob.core.windows.net/models/gemma.litertlm';

    test('appends Azure SAS to the URL and sends no Bearer token', () {
      final source = buildModelNetworkSource(
        url: url,
        azureBlobSasToken: 'sv=2023&sig=abc',
      );
      expect(source.location, '$url?sv=2023&sig=abc');
      expect(source.token, isNull);
    });

    test('sends an explicit model token as a Bearer token, URL untouched', () {
      final source = buildModelNetworkSource(
        url: url,
        modelToken: 'bearer-token',
        azureBlobSasToken: 'sv=2023&sig=abc',
      );
      expect(source.location, url);
      expect(source.token, 'bearer-token');
    });

    test('falls back to a Hugging Face Bearer token', () {
      final source = buildModelNetworkSource(
        url: url,
        huggingFaceToken: 'hf-token',
      );
      expect(source.location, url);
      expect(source.token, 'hf-token');
    });

    test('sends no token when none is configured', () {
      final source = buildModelNetworkSource(url: url);
      expect(source.location, url);
      expect(source.token, isNull);
    });
  });

  group('selectModelNetworkSource', () {
    const cdn = 'https://stepwise.z01.azurefd.net/models/gemma.litertlm';
    const origin = 'https://acct.blob.core.windows.net/models/gemma.litertlm';

    test('CDN URL wins and is fetched tokenless', () {
      final source = selectModelNetworkSource(
        cdnUrl: cdn,
        modelUrl: origin,
        modelToken: 'bearer-token',
        azureBlobSasToken: 'sv=2023&sig=abc',
      );
      expect(source.location, cdn); // no SAS appended
      expect(source.token, isNull); // no Bearer header
    });

    test('falls back to the direct origin URL with its auth', () {
      final source = selectModelNetworkSource(
        modelUrl: origin,
        azureBlobSasToken: 'sv=2023&sig=abc',
      );
      expect(source.location, '$origin?sv=2023&sig=abc');
      expect(source.token, isNull);
    });

    test('treats an empty CDN URL as unset', () {
      final source = selectModelNetworkSource(cdnUrl: '', modelUrl: origin);
      expect(source.location, origin);
    });

    test('throws when neither URL is configured', () {
      expect(
        () => selectModelNetworkSource(),
        throwsArgumentError,
      );
    });
  });

  group('DownloadSpeedTracker', () {
    test('derives MB/s from percent deltas over time', () {
      final tracker = DownloadSpeedTracker(totalBytes: 100 * 1024 * 1024);

      // First sample has no prior reference, so no rate yet.
      final first = tracker.update(0.0, Duration.zero);
      expect(first.bytesPerSecond, isNull);
      expect(first.downloadedBytes, 0);
      expect(first.totalBytes, 100 * 1024 * 1024);

      // 10% of 100 MiB in 1 second ⇒ ~10 MiB/s.
      final second = tracker.update(0.1, const Duration(seconds: 1));
      expect(second.downloadedBytes, (0.1 * 100 * 1024 * 1024).round());
      expect(second.bytesPerSecond, isNotNull);
      expect(second.bytesPerSecond! / (1024 * 1024), closeTo(10, 0.001));
    });

    test('reports no rate when the total size is unknown', () {
      final tracker = DownloadSpeedTracker();
      final p = tracker.update(0.5, const Duration(seconds: 1));
      expect(p.bytesPerSecond, isNull);
      expect(p.downloadedBytes, isNull);
      expect(p.totalBytes, isNull);
      expect(p.fraction, 0.5);
    });

    test('ignores non-positive time deltas without dividing by zero', () {
      final tracker = DownloadSpeedTracker(totalBytes: 1024)
        ..update(0.1, const Duration(seconds: 1));
      final same = tracker.update(0.2, const Duration(seconds: 1));
      // dt == 0 ⇒ the EMA is unchanged from the previous (still-null) value.
      expect(same.bytesPerSecond, isNull);
    });
  });

  group('formatDownloadSpeed', () {
    test('formats MB/s above 1 MiB/s', () {
      expect(formatDownloadSpeed(12.3 * 1024 * 1024), '12.3 MB/s');
    });

    test('formats KB/s below 1 MiB/s', () {
      expect(formatDownloadSpeed(200 * 1024), '200 KB/s');
    });

    test('is empty for null or non-positive rates', () {
      expect(formatDownloadSpeed(null), '');
      expect(formatDownloadSpeed(0), '');
      expect(formatDownloadSpeed(-5), '');
    });
  });

  group('formatBytes', () {
    test('formats GB, MB, KB and bytes', () {
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
      expect(formatBytes(420 * 1024 * 1024), '420 MB');
      expect(formatBytes(3 * 1024), '3 KB');
      expect(formatBytes(512), '512 B');
    });

    test('is empty for null', () {
      expect(formatBytes(null), '');
    });
  });
}
