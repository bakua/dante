import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/benchmark_runner.dart';
import 'package:dante_terminal/services/performance_metrics.dart';

void main() {
  group('BenchmarkRunner', () {
    test('kTestAdventurePrompts has exactly 5 prompts', () {
      expect(kTestAdventurePrompts, hasLength(5));
    });

    test('kTestAdventurePrompts cover required interaction categories', () {
      // Turn 1: Scene opening / world building
      expect(kTestAdventurePrompts[0].toLowerCase(), contains('describe'));

      // Turn 2: Navigation
      expect(kTestAdventurePrompts[1].toLowerCase(), contains('walk'));

      // Turn 3: Object interaction
      expect(kTestAdventurePrompts[2].toLowerCase(), contains('pick up'));

      // Turn 4: NPC interaction
      expect(kTestAdventurePrompts[3].toLowerCase(), contains('who are you'));

      // Turn 5: Problem-solving
      expect(kTestAdventurePrompts[4].toLowerCase(), contains('find a way'));
    });

    test('each prompt asks for 3 action suggestions', () {
      for (final prompt in kTestAdventurePrompts) {
        expect(prompt, contains('3 action suggestions'));
      }
    });

    test('kQualityDimensions has 5 dimensions', () {
      expect(kQualityDimensions, hasLength(5));
      expect(kQualityDimensions, contains('Narrative coherence'));
      expect(kQualityDimensions, contains('Scene detail'));
      expect(kQualityDimensions, contains('Action acknowledgment'));
      expect(kQualityDimensions, contains('Suggestion relevance'));
      expect(kQualityDimensions, contains('Factual consistency'));
    });

    test('formatComparisonTable produces markdown table', () {
      final results = [
        ModelBenchmarkResult(
          modelName: 'gemma-3n-e2b-q4',
          modelPath: '/models/gemma.gguf',
          modelFileSizeMB: 1200.0,
          qualityScore: 4,
        ),
        ModelBenchmarkResult(
          modelName: 'llama-3.2-3b-q4',
          modelPath: '/models/llama.gguf',
          modelFileSizeMB: 2000.0,
          qualityScore: 3,
        ),
      ];

      // Add a synthetic run to each
      for (final r in results) {
        r.runs.add(InferenceMetrics(
          modelName: r.modelName,
          ttftMs: 800,
          tokenCount: 51,
          totalTimeMs: 5800,
          peakMemoryMB: 1200.0,
          responseText: 'test response',
        ));
      }

      final table = BenchmarkRunner.formatComparisonTable(results);
      expect(table, contains('Model Name'));
      expect(table, contains('SDK'));
      expect(table, contains('tok/s'));
      expect(table, contains('Peak Memory MB'));
      expect(table, contains('TTFT'));
      expect(table, contains('IF Quality'));
      expect(table, contains('gemma-3n-e2b-q4'));
      expect(table, contains('llama-3.2-3b-q4'));
    });

    test('BenchmarkRunner can be constructed with progress callback', () {
      final logs = <String>[];
      final runner = BenchmarkRunner(
        onProgress: (model, current, total, status) {
          logs.add('$model: $current/$total $status');
        },
      );
      expect(runner, isNotNull);
    });
  });
}
