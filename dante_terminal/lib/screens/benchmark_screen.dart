import 'dart:io';

import 'package:flutter/material.dart';

import '../services/benchmark_runner.dart';
import '../services/performance_metrics.dart';

/// Screen for running standardized benchmarks across available models.
///
/// Discovers all .gguf files in the app documents directory, runs the
/// 5-turn test adventure on each, displays per-run metrics, and
/// generates a formatted comparison table.
class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final List<String> _log = [];
  bool _running = false;
  List<ModelBenchmarkResult>? _results;

  static const _terminalGreen = Color(0xFF00FF41);
  static const _terminalDim = Color(0xFF00AA2A);
  static const _bgColor = Color(0xFF0A0A0A);

  void _appendLog(String line) {
    setState(() => _log.add(line));
  }

  Future<void> _runBenchmarks() async {
    setState(() {
      _running = true;
      _log.clear();
      _results = null;
    });

    _appendLog('=== DANTE TERMINAL Benchmark Suite ===');
    _appendLog('Date: ${DateTime.now().toIso8601String()}');
    _appendLog('');

    final runner = BenchmarkRunner(
      onProgress: (model, current, total, status) {
        _appendLog('[$model] ($current/$total) $status');
      },
    );

    try {
      final results = await runner.benchmarkAllModels();
      _results = results;

      _appendLog('');
      _appendLog('=== Results ===');
      _appendLog('');

      // Display per-model results
      for (final result in results) {
        _appendLog('--- ${result.modelName} ---');
        _appendLog('File size: ${result.modelFileSizeMB.toStringAsFixed(1)} MB');
        _appendLog(
            'Avg TTFT: ${result.avgTtftSeconds.toStringAsFixed(2)}s');
        _appendLog(
            'Avg decode: ${result.avgTokensPerSecond.toStringAsFixed(1)} tok/s');
        final mem = result.peakMemoryMB;
        if (mem != null) {
          _appendLog('Peak memory: ${mem.toStringAsFixed(0)} MB');
        }
        _appendLog('');

        // Show individual run details
        for (int i = 0; i < result.runs.length; i++) {
          final run = result.runs[i];
          _appendLog('  Turn ${i + 1}: ${run.ttftSeconds.toStringAsFixed(2)}s TTFT, '
              '${run.tokensPerSecond.toStringAsFixed(1)} tok/s, '
              '${run.tokenCount} tokens');
          // Show first 100 chars of response
          final preview = run.responseText.length > 100
              ? '${run.responseText.substring(0, 100)}...'
              : run.responseText;
          _appendLog('  > ${preview.replaceAll('\n', ' ')}');
          _appendLog('');
        }
      }

      // Display comparison table
      _appendLog('=== Comparison Table ===');
      _appendLog(BenchmarkRunner.formatComparisonTable(results));

      // Save results
      try {
        final path = await runner.saveResults(results);
        _appendLog('Results saved to: $path');
      } catch (e) {
        _appendLog('[WARN] Could not save results: $e');
      }

      _appendLog('');
      _appendLog('=== Benchmark Complete ===');
    } on FileSystemException catch (e) {
      _appendLog('[ERR] ${e.message}');
      _appendLog('');
      _appendLog('To run benchmarks, copy .gguf model files to the app');
      _appendLog('documents directory. Each file will be benchmarked.');
    } catch (e) {
      _appendLog('[ERR] Benchmark failed: $e');
    }

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: _terminalGreen,
        title: const Text(
          'BENCHMARK',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 4,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Text(
              'Runs the standardized 5-turn interactive fiction test '
              'adventure on all .gguf models in the documents directory. '
              'Measures TTFT, decode speed, and memory per BL-014 targets.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: _terminalDim,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Start button
            ElevatedButton(
              onPressed: _running ? null : _runBenchmarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003311),
                foregroundColor: _terminalGreen,
                side: BorderSide(color: _terminalGreen),
              ),
              child: Text(
                _running
                    ? 'Running...'
                    : _results != null
                        ? 'Re-run Benchmark (${_results!.length} models tested)'
                        : 'Start Benchmark',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            // Log output
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _terminalDim.withAlpha(76)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Text(
                    _log[i],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: _log[i].startsWith('[ERR]')
                          ? Colors.red
                          : _log[i].startsWith('[WARN]')
                              ? Colors.amber
                              : _terminalGreen,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
