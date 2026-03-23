import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llamadart/llamadart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BL-024 FFI Spike',
      home: const SpikePage(),
    );
  }
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  String _status = 'Auto-starting spike test...';
  String _output = '';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // Auto-run the spike test on launch
    Future.delayed(const Duration(milliseconds: 500), () => _runSpike());
  }

  Future<void> _runSpike() async {
    setState(() {
      _running = true;
      _status = 'Starting spike test...';
      _output = '';
    });

    final log = StringBuffer();
    log.writeln('=== BL-024 FFI Spike Test ===');
    log.writeln('Time: ${DateTime.now().toIso8601String()}');
    log.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    log.writeln('');

    try {
      // Step 1: Initialize the backend
      log.writeln('[STEP 1] Initializing LlamaBackend...');
      setState(() => _status = 'Step 1: Initializing backend...');
      final backend = LlamaBackend();
      log.writeln('[STEP 1] ✅ LlamaBackend created successfully');
      log.writeln('');

      // Step 2: Create engine
      log.writeln('[STEP 2] Creating LlamaEngine...');
      setState(() => _status = 'Step 2: Creating engine...');
      final engine = LlamaEngine(backend);
      log.writeln('[STEP 2] ✅ LlamaEngine created successfully');
      log.writeln('');

      // Step 3: Check if model file exists in Documents dir
      final docsDir = await getApplicationDocumentsDirectory();
      final modelPath = '${docsDir.path}/spike_model.gguf';
      log.writeln('[STEP 3] Documents dir: ${docsDir.path}');
      log.writeln('[STEP 3] Checking model at: $modelPath');
      setState(() => _status = 'Step 3: Checking model file...');

      // Also list available files in docs dir
      final files = docsDir.listSync();
      log.writeln('[STEP 3] Files in Documents: ${files.map((f) => f.path.split('/').last).toList()}');

      if (File(modelPath).existsSync()) {
        final fileSize = File(modelPath).lengthSync();
        log.writeln('[STEP 3] ✅ Model file found (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
        log.writeln('');

        // Step 4: Load model
        log.writeln('[STEP 4] Loading model...');
        setState(() => _status = 'Step 4: Loading model (this may take a while)...');
        final stopwatch = Stopwatch()..start();

        await engine.loadModel(modelPath);

        stopwatch.stop();
        log.writeln('[STEP 4] ✅ Model loaded in ${stopwatch.elapsedMilliseconds}ms');
        log.writeln('');

        // Step 5: Run inference
        log.writeln('[STEP 5] Running inference...');
        setState(() => _status = 'Step 5: Running inference...');
        stopwatch.reset();
        stopwatch.start();

        final tokens = <String>[];
        await for (final token in engine.generate('Once upon a time in a dark dungeon,')) {
          tokens.add(token);
          if (tokens.length >= 20) break; // Limit output for spike
        }

        stopwatch.stop();
        final response = tokens.join('');
        log.writeln('[STEP 5] ✅ Inference completed in ${stopwatch.elapsedMilliseconds}ms');
        log.writeln('[STEP 5] Tokens generated: ${tokens.length}');
        log.writeln('[STEP 5] Response: $response');
        log.writeln('');

        // Step 6: Cleanup
        log.writeln('[STEP 6] Disposing engine...');
        await engine.dispose();
        log.writeln('[STEP 6] ✅ Engine disposed');
        log.writeln('');

        log.writeln('=== RESULT: PASS ===');
        log.writeln('FFI bindings work. Model loads. Inference produces output.');
        setState(() => _status = '✅ PASS — Inference successful!');
      } else {
        log.writeln('[STEP 3] ⚠️ Model file not found at $modelPath');
        log.writeln('[STEP 3] FFI binding validation: Backend and Engine creation succeeded.');
        log.writeln('[STEP 3] This confirms the native library loads on this platform.');
        log.writeln('');
        log.writeln('=== RESULT: PARTIAL PASS ===');
        log.writeln('FFI bindings load correctly. Model file needed for full inference test.');
        log.writeln('Copy a GGUF model to: $modelPath');

        await engine.dispose();
        setState(() => _status = '⚠️ PARTIAL — FFI works, no model found');
      }
    } catch (e, stackTrace) {
      log.writeln('');
      log.writeln('=== ERROR ===');
      log.writeln('Exception: $e');
      log.writeln('Stack trace: $stackTrace');
      log.writeln('');
      log.writeln('=== RESULT: FAIL ===');
      setState(() => _status = '❌ FAIL — See error log');
    }

    // Print to console for CLI capture
    // ignore: avoid_print
    print(log.toString());

    // Write results to file for CLI retrieval
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final resultFile = File('${docsDir.path}/spike_result.txt');
      await resultFile.writeAsString(log.toString());
    } catch (_) {}

    setState(() {
      _output = log.toString();
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BL-024 FFI Spike')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _status.contains('PASS')
                      ? Colors.green
                      : _status.contains('FAIL')
                          ? Colors.red
                          : Colors.blue,
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _running ? null : _runSpike,
              child: Text(_running ? 'Running...' : 'Run FFI Spike Test'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _output,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
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
