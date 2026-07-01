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
}
