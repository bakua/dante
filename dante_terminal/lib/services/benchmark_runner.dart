import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'inference_service.dart';
import 'performance_metrics.dart';

/// Standardized 5-turn interactive fiction test adventure prompts.
///
/// Designed to exercise key Game Master capabilities:
/// 1. Scene opening / world building
/// 2. Navigation / exploration
/// 3. Object interaction
/// 4. NPC/character interaction
/// 5. Problem-solving / creative action
const List<String> kTestAdventurePrompts = [
  // Turn 1: Scene opening — tests world-building, atmosphere, descriptive prose
  'You are a Game Master for a text adventure. The player enters a dark cave. '
      'Describe the scene in 2-3 sentences, including what they can see, hear, '
      'and smell. End with 3 action suggestions.',

  // Turn 2: Navigation — tests spatial awareness and scene continuity
  'The player says: "I walk deeper into the cave, following the sound of '
      'dripping water." Continue the adventure in 2-3 sentences with new '
      'details. End with 3 action suggestions.',

  // Turn 3: Object interaction — tests item tracking and world consistency
  'The player says: "I pick up the glowing crystal from the ledge and '
      'examine it closely." Describe what happens in 2-3 sentences. '
      'End with 3 action suggestions.',

  // Turn 4: NPC interaction — tests character voice and dialogue
  'The player says: "I call out to the shadowy figure in the corner: '
      'Who are you?" Write the NPC\'s response and the scene in 2-3 sentences. '
      'End with 3 action suggestions.',

  // Turn 5: Problem-solving — tests creative response to player agency
  'The player says: "I use the glowing crystal to light up the dark passage '
      'and try to find a way out." Describe the outcome in 2-3 sentences. '
      'End with 3 action suggestions.',
];

/// Quality assessment criteria for the 5-turn test adventure.
///
/// Each dimension is scored 1-5:
/// - Narrative coherence: Does the story flow logically across turns?
/// - Scene detail: Are descriptions vivid and immersive?
/// - Action acknowledgment: Does the AI respond to the specific player action?
/// - Suggestion relevance: Are the 3 suggestions contextually appropriate?
/// - Factual consistency: Does the AI remember and reference earlier details?
const List<String> kQualityDimensions = [
  'Narrative coherence',
  'Scene detail',
  'Action acknowledgment',
  'Suggestion relevance',
  'Factual consistency',
];

/// Callback for benchmark progress updates.
typedef BenchmarkProgressCallback = void Function(
  String modelName,
  int promptIndex,
  int totalPrompts,
  String status,
);

/// Runs standardized benchmarks across one or more model files.
///
/// Produces [ModelBenchmarkResult] objects with performance metrics
/// and collects responses for quality assessment.
class BenchmarkRunner {
  final BenchmarkProgressCallback? onProgress;

  BenchmarkRunner({this.onProgress});

  /// Run the full benchmark suite on a single model.
  ///
  /// [modelPath] - Path to the GGUF model file.
  /// [modelName] - Human-readable name for the comparison table.
  /// [maxTokensPerPrompt] - Token limit per generation (default: 150 per BL-012).
  Future<ModelBenchmarkResult> benchmarkModel({
    required String modelPath,
    required String modelName,
    int maxTokensPerPrompt = 150,
  }) async {
    final file = File(modelPath);
    final fileSizeMB = file.lengthSync() / (1024 * 1024);

    final result = ModelBenchmarkResult(
      modelName: modelName,
      modelPath: modelPath,
      modelFileSizeMB: fileSizeMB,
    );

    // Create a fresh inference service for this model
    final service = InferenceService();

    try {
      _report(modelName, 0, kTestAdventurePrompts.length, 'Initializing...');
      await service.initialize();

      _report(modelName, 0, kTestAdventurePrompts.length, 'Loading model...');
      final loadStopwatch = Stopwatch()..start();
      await service.loadModel(modelPath);
      loadStopwatch.stop();

      // Run each test prompt
      for (int i = 0; i < kTestAdventurePrompts.length; i++) {
        final prompt = kTestAdventurePrompts[i];
        _report(modelName, i + 1, kTestAdventurePrompts.length,
            'Running prompt ${i + 1}...');

        final metrics = await _runSinglePrompt(
          service: service,
          modelName: modelName,
          prompt: prompt,
          maxTokens: maxTokensPerPrompt,
        );

        result.runs.add(metrics);
      }
    } finally {
      await service.dispose();
    }

    return result;
  }

  /// Run benchmark on all .gguf files found in the app documents directory.
  Future<List<ModelBenchmarkResult>> benchmarkAllModels({
    int maxTokensPerPrompt = 150,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final models = <MapEntry<String, String>>[];

    for (final entry in docsDir.listSync()) {
      if (entry is File && entry.path.endsWith('.gguf')) {
        final name = entry.path.split('/').last.replaceAll('.gguf', '');
        models.add(MapEntry(name, entry.path));
      }
    }

    if (models.isEmpty) {
      throw FileSystemException(
        'No .gguf model files found in ${docsDir.path}',
      );
    }

    final results = <ModelBenchmarkResult>[];
    for (final model in models) {
      final result = await benchmarkModel(
        modelPath: model.value,
        modelName: model.key,
        maxTokensPerPrompt: maxTokensPerPrompt,
      );
      results.add(result);
    }

    return results;
  }

  /// Run a single prompt and capture metrics.
  Future<InferenceMetrics> _runSinglePrompt({
    required InferenceService service,
    required String modelName,
    required String prompt,
    required int maxTokens,
  }) async {
    final memBefore = getCurrentMemoryMB();
    double? peakMem = memBefore;

    final stopwatch = Stopwatch()..start();
    int? ttftMs;
    int tokenCount = 0;
    final responseBuffer = StringBuffer();

    await for (final token
        in service.generate(prompt, maxTokens: maxTokens)) {
      ttftMs ??= stopwatch.elapsedMilliseconds;
      responseBuffer.write(token);
      tokenCount++;

      // Sample memory periodically
      if (tokenCount % 10 == 0) {
        final currentMem = getCurrentMemoryMB();
        if (currentMem != null && (peakMem == null || currentMem > peakMem)) {
          peakMem = currentMem;
        }
      }
    }

    stopwatch.stop();

    return InferenceMetrics(
      modelName: modelName,
      ttftMs: ttftMs ?? stopwatch.elapsedMilliseconds,
      tokenCount: tokenCount,
      totalTimeMs: stopwatch.elapsedMilliseconds,
      peakMemoryMB: peakMem,
      responseText: responseBuffer.toString(),
    );
  }

  /// Save benchmark results to a JSON file in the documents directory.
  Future<String> saveResults(List<ModelBenchmarkResult> results) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filePath = '${docsDir.path}/benchmark_$timestamp.json';

    final json = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'results': results.map((r) => r.toJson()).toList(),
    });

    await File(filePath).writeAsString(json);
    return filePath;
  }

  /// Generate a formatted comparison table from results.
  static String formatComparisonTable(List<ModelBenchmarkResult> results) {
    final buf = StringBuffer();
    buf.writeln('| Model Name | SDK | tok/s | Peak Memory MB | '
        'TTFT (s) | IF Quality (1-5) |');
    buf.writeln('|---|---|---|---|---|---|');
    for (final r in results) {
      buf.writeln(r.toTableRow());
    }
    return buf.toString();
  }

  void _report(String model, int current, int total, String status) {
    onProgress?.call(model, current, total, status);
  }
}
