import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/model_service.dart';

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
}
