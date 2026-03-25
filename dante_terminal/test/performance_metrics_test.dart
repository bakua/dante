import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/performance_metrics.dart';

void main() {
  group('InferenceMetrics', () {
    test('calculates tokens per second correctly', () {
      final metrics = InferenceMetrics(
        modelName: 'test-model',
        ttftMs: 500,
        tokenCount: 51,
        totalTimeMs: 5500, // 5000ms decode time for 50 tokens
        responseText: 'test response',
      );

      // 50 decoded tokens (first token is TTFT) in 5.0 seconds = 10 tok/s
      expect(metrics.tokensPerSecond, closeTo(10.0, 0.1));
    });

    test('reports TTFT in seconds', () {
      final metrics = InferenceMetrics(
        modelName: 'test-model',
        ttftMs: 1500,
        tokenCount: 10,
        totalTimeMs: 5000,
        responseText: 'test',
      );

      expect(metrics.ttftSeconds, 1.5);
    });

    test('meets TTFT target when under 3 seconds', () {
      final fast = InferenceMetrics(
        modelName: 'fast',
        ttftMs: 2000,
        tokenCount: 10,
        totalTimeMs: 5000,
        responseText: 'test',
      );
      expect(fast.meetsTtftTarget, isTrue);

      final slow = InferenceMetrics(
        modelName: 'slow',
        ttftMs: 3500,
        tokenCount: 10,
        totalTimeMs: 5000,
        responseText: 'test',
      );
      expect(slow.meetsTtftTarget, isFalse);
    });

    test('meets decode target when above 4 tok/s', () {
      final fast = InferenceMetrics(
        modelName: 'fast',
        ttftMs: 500,
        tokenCount: 21,
        totalTimeMs: 5500, // 20 tokens in 5s = 4 tok/s
        responseText: 'test',
      );
      expect(fast.meetsDecodeTarget, isTrue);

      final slow = InferenceMetrics(
        modelName: 'slow',
        ttftMs: 500,
        tokenCount: 11,
        totalTimeMs: 5500, // 10 tokens in 5s = 2 tok/s
        responseText: 'test',
      );
      expect(slow.meetsDecodeTarget, isFalse);
    });

    test('meets memory target when under 1500 MB', () {
      final ok = InferenceMetrics(
        modelName: 'ok',
        ttftMs: 500,
        tokenCount: 10,
        totalTimeMs: 5000,
        peakMemoryMB: 1200.0,
        responseText: 'test',
      );
      expect(ok.meetsMemoryTarget, isTrue);

      final high = InferenceMetrics(
        modelName: 'high',
        ttftMs: 500,
        tokenCount: 10,
        totalTimeMs: 5000,
        peakMemoryMB: 1800.0,
        responseText: 'test',
      );
      expect(high.meetsMemoryTarget, isFalse);
    });

    test('meets memory target when memory is null (unmeasurable)', () {
      final unknown = InferenceMetrics(
        modelName: 'unknown',
        ttftMs: 500,
        tokenCount: 10,
        totalTimeMs: 5000,
        responseText: 'test',
      );
      expect(unknown.meetsMemoryTarget, isTrue);
    });

    test('handles zero tokens edge case', () {
      final empty = InferenceMetrics(
        modelName: 'empty',
        ttftMs: 100,
        tokenCount: 0,
        totalTimeMs: 100,
        responseText: '',
      );
      expect(empty.tokensPerSecond, 0.0);
    });

    test('handles single token edge case', () {
      final single = InferenceMetrics(
        modelName: 'single',
        ttftMs: 100,
        tokenCount: 1,
        totalTimeMs: 100,
        responseText: 'a',
      );
      expect(single.tokensPerSecond, 0.0);
    });

    test('toJson produces all expected keys', () {
      final metrics = InferenceMetrics(
        modelName: 'test',
        ttftMs: 500,
        tokenCount: 50,
        totalTimeMs: 5500,
        peakMemoryMB: 1200.0,
        responseText: 'test output',
      );

      final json = metrics.toJson();
      expect(json.containsKey('modelName'), isTrue);
      expect(json.containsKey('ttftMs'), isTrue);
      expect(json.containsKey('ttftSeconds'), isTrue);
      expect(json.containsKey('tokenCount'), isTrue);
      expect(json.containsKey('totalTimeMs'), isTrue);
      expect(json.containsKey('tokensPerSecond'), isTrue);
      expect(json.containsKey('peakMemoryMB'), isTrue);
      expect(json.containsKey('meetsTtftTarget'), isTrue);
      expect(json.containsKey('meetsDecodeTarget'), isTrue);
      expect(json.containsKey('meetsMemoryTarget'), isTrue);
      expect(json.containsKey('timestamp'), isTrue);
    });

    test('toSummary produces readable output', () {
      final metrics = InferenceMetrics(
        modelName: 'test',
        ttftMs: 1500,
        tokenCount: 50,
        totalTimeMs: 6500,
        responseText: 'test',
      );

      final summary = metrics.toSummary();
      expect(summary, contains('test'));
      expect(summary, contains('TTFT'));
      expect(summary, contains('tok/s'));
    });
  });

  group('ModelBenchmarkResult', () {
    test('calculates averages across runs', () {
      final result = ModelBenchmarkResult(
        modelName: 'test-model',
        modelPath: '/path/to/model.gguf',
        modelFileSizeMB: 1200.0,
      );

      result.runs.add(InferenceMetrics(
        modelName: 'test-model',
        ttftMs: 500,
        tokenCount: 21,
        totalTimeMs: 5500,
        peakMemoryMB: 1000.0,
        responseText: 'response 1',
      ));

      result.runs.add(InferenceMetrics(
        modelName: 'test-model',
        ttftMs: 700,
        tokenCount: 21,
        totalTimeMs: 5700,
        peakMemoryMB: 1100.0,
        responseText: 'response 2',
      ));

      // Average TTFT: (0.5 + 0.7) / 2 = 0.6s
      expect(result.avgTtftSeconds, closeTo(0.6, 0.01));

      // Average tok/s: (4.0 + 4.0) / 2 = 4.0
      expect(result.avgTokensPerSecond, closeTo(4.0, 0.1));

      // Peak memory: max(1000, 1100) = 1100
      expect(result.peakMemoryMB, 1100.0);
    });

    test('handles empty runs', () {
      final result = ModelBenchmarkResult(
        modelName: 'empty',
        modelPath: '/path/to/model.gguf',
        modelFileSizeMB: 500.0,
      );

      expect(result.avgTtftSeconds, 0.0);
      expect(result.avgTokensPerSecond, 0.0);
      expect(result.peakMemoryMB, isNull);
    });

    test('toTableRow produces pipe-delimited row', () {
      final result = ModelBenchmarkResult(
        modelName: 'gemma-3n',
        modelPath: '/path/model.gguf',
        modelFileSizeMB: 1200.0,
        qualityScore: 4,
      );

      result.runs.add(InferenceMetrics(
        modelName: 'gemma-3n',
        ttftMs: 500,
        tokenCount: 21,
        totalTimeMs: 5500,
        responseText: 'test',
      ));

      final row = result.toTableRow();
      expect(row, contains('gemma-3n'));
      expect(row, contains('llamadart/llama.cpp'));
      expect(row, contains('4/5'));
    });

    test('toJson includes all fields', () {
      final result = ModelBenchmarkResult(
        modelName: 'test',
        modelPath: '/path/model.gguf',
        modelFileSizeMB: 1200.0,
        qualityScore: 3,
        qualityRationale: 'Good prose, weak suggestions',
      );

      final json = result.toJson();
      expect(json['modelName'], 'test');
      expect(json['qualityScore'], 3);
      expect(json['qualityRationale'], 'Good prose, weak suggestions');
    });
  });
}
