import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/model_service.dart';
import 'package:stepwise/main.dart';

void main() {
  test('normalizes model id from network source file extension', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.network(
        'http://10.0.0.108:8000/gemma-3n-E2B-it-int4.litertlm',
      ),
    );

    expect(service.modelId, 'gemma-3n-E2B-it-int4');
  });

  test('normalizes model id from file source task extension', () {
    final service = GemmaModelService(
      source: const GemmaModelSource.file(
        '/tmp/models/gemma3-1b-it.task',
      ),
    );

    expect(service.modelId, 'gemma3-1b-it');
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
}
