import 'dart:io';

/// Captures performance metrics for a single inference run.
///
/// Used by [InferenceService] and [BenchmarkRunner] to track TTFT,
/// throughput, and memory usage per BL-014 performance budget targets.
class InferenceMetrics {
  /// Model name / identifier.
  final String modelName;

  /// Time to first token in milliseconds.
  final int ttftMs;

  /// Total tokens generated.
  final int tokenCount;

  /// Total generation time in milliseconds (including TTFT).
  final int totalTimeMs;

  /// Peak memory usage in MB during generation (if measurable).
  final double? peakMemoryMB;

  /// The complete generated text.
  final String responseText;

  /// Timestamp when the measurement was taken.
  final DateTime timestamp;

  InferenceMetrics({
    required this.modelName,
    required this.ttftMs,
    required this.tokenCount,
    required this.totalTimeMs,
    this.peakMemoryMB,
    required this.responseText,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Decode speed in tokens per second (excluding TTFT).
  double get tokensPerSecond {
    final decodeTimeMs = totalTimeMs - ttftMs;
    if (decodeTimeMs <= 0 || tokenCount <= 1) return 0.0;
    // First token is covered by TTFT, remaining tokens by decode time
    return (tokenCount - 1) / (decodeTimeMs / 1000.0);
  }

  /// TTFT in seconds.
  double get ttftSeconds => ttftMs / 1000.0;

  /// Whether this run meets BL-014 TTFT target (≤3.0s).
  bool get meetsTtftTarget => ttftSeconds <= 3.0;

  /// Whether this run meets BL-014 decode speed target (≥4 tok/s).
  bool get meetsDecodeTarget => tokensPerSecond >= 4.0;

  /// Whether this run meets BL-014 memory target (≤1500 MB iOS).
  bool get meetsMemoryTarget =>
      peakMemoryMB == null || peakMemoryMB! <= 1500.0;

  /// Summarize metrics as a formatted string.
  String toSummary() {
    final buf = StringBuffer();
    buf.writeln('Model: $modelName');
    buf.writeln('TTFT: ${ttftSeconds.toStringAsFixed(2)}s '
        '(target ≤3.0s: ${meetsTtftTarget ? "✅" : "❌"})');
    buf.writeln('Decode: ${tokensPerSecond.toStringAsFixed(1)} tok/s '
        '(target ≥4.0: ${meetsDecodeTarget ? "✅" : "❌"})');
    buf.writeln('Tokens: $tokenCount in ${totalTimeMs}ms');
    if (peakMemoryMB != null) {
      buf.writeln('Memory: ${peakMemoryMB!.toStringAsFixed(0)} MB '
          '(target ≤1500: ${meetsMemoryTarget ? "✅" : "❌"})');
    }
    return buf.toString();
  }

  /// Convert to a Map for JSON serialization.
  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'ttftMs': ttftMs,
        'ttftSeconds': ttftSeconds,
        'tokenCount': tokenCount,
        'totalTimeMs': totalTimeMs,
        'tokensPerSecond': tokensPerSecond,
        'peakMemoryMB': peakMemoryMB,
        'meetsTtftTarget': meetsTtftTarget,
        'meetsDecodeTarget': meetsDecodeTarget,
        'meetsMemoryTarget': meetsMemoryTarget,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Tracks performance across multiple inference runs for a model.
class ModelBenchmarkResult {
  final String modelName;
  final String modelPath;
  final double modelFileSizeMB;
  final List<InferenceMetrics> runs;
  int qualityScore; // 1-5 interactive fiction quality
  String qualityRationale;

  ModelBenchmarkResult({
    required this.modelName,
    required this.modelPath,
    required this.modelFileSizeMB,
    List<InferenceMetrics>? runs,
    this.qualityScore = 0,
    this.qualityRationale = '',
  }) : runs = runs ?? [];

  /// Average TTFT across all runs in seconds.
  double get avgTtftSeconds {
    if (runs.isEmpty) return 0.0;
    return runs.map((r) => r.ttftSeconds).reduce((a, b) => a + b) /
        runs.length;
  }

  /// Average decode speed across all runs in tok/s.
  double get avgTokensPerSecond {
    if (runs.isEmpty) return 0.0;
    return runs.map((r) => r.tokensPerSecond).reduce((a, b) => a + b) /
        runs.length;
  }

  /// Peak memory across all runs in MB.
  double? get peakMemoryMB {
    final memRuns = runs.where((r) => r.peakMemoryMB != null);
    if (memRuns.isEmpty) return null;
    return memRuns.map((r) => r.peakMemoryMB!).reduce(
        (a, b) => a > b ? a : b);
  }

  /// Format as a comparison table row.
  String toTableRow() {
    final mem = peakMemoryMB?.toStringAsFixed(0) ?? 'N/A';
    return '| $modelName | llamadart/llama.cpp | '
        '${avgTokensPerSecond.toStringAsFixed(1)} | $mem | '
        '${avgTtftSeconds.toStringAsFixed(2)} | '
        '$qualityScore/5 |';
  }

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'modelPath': modelPath,
        'modelFileSizeMB': modelFileSizeMB,
        'avgTtftSeconds': avgTtftSeconds,
        'avgTokensPerSecond': avgTokensPerSecond,
        'peakMemoryMB': peakMemoryMB,
        'qualityScore': qualityScore,
        'qualityRationale': qualityRationale,
        'runs': runs.map((r) => r.toJson()).toList(),
      };
}

/// Attempts to read current process memory usage.
///
/// Returns RSS in MB on platforms that support /proc/self/status (Linux/Android).
/// Returns null on iOS and simulator where /proc is not available.
/// On iOS, use Xcode Instruments or os_proc_available_memory() via platform channel.
double? getCurrentMemoryMB() {
  try {
    if (Platform.isAndroid || Platform.isLinux) {
      final status = File('/proc/self/status').readAsStringSync();
      final vmRss = RegExp(r'VmRSS:\s+(\d+)\s+kB')
          .firstMatch(status)
          ?.group(1);
      if (vmRss != null) {
        return int.parse(vmRss) / 1024.0;
      }
    }
    // iOS: would need platform channel to os_proc_available_memory()
    // Simulator: no reliable memory API
    return null;
  } catch (_) {
    return null;
  }
}
