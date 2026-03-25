import 'dart:async';
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

/// Status of the inference engine lifecycle.
enum InferenceStatus {
  uninitialized,
  initializing,
  ready,
  loading,
  modelLoaded,
  generating,
  error,
  disposed,
}

/// A reusable service layer wrapping llamadart for on-device LLM inference.
///
/// Ported from spike_llama_ffi (BL-024) and cleaned up into a proper service
/// with lifecycle management, streaming support, and error handling.
class InferenceService {
  LlamaBackend? _backend;
  LlamaEngine? _engine;
  InferenceStatus _status = InferenceStatus.uninitialized;
  String? _loadedModelPath;
  String? _lastError;

  /// Current status of the inference engine.
  InferenceStatus get status => _status;

  /// Whether the engine has a model loaded and is ready for inference.
  bool get isReady => _status == InferenceStatus.modelLoaded;

  /// The path of the currently loaded model, if any.
  String? get loadedModelPath => _loadedModelPath;

  /// The last error message, if any.
  String? get lastError => _lastError;

  /// Initialize the llama backend and engine.
  ///
  /// Must be called before [loadModel]. Safe to call multiple times —
  /// subsequent calls are no-ops if already initialized.
  Future<void> initialize() async {
    if (_status != InferenceStatus.uninitialized) return;

    _status = InferenceStatus.initializing;
    _lastError = null;

    try {
      _backend = LlamaBackend();
      _engine = LlamaEngine(_backend!);
      _status = InferenceStatus.ready;
    } catch (e) {
      _status = InferenceStatus.error;
      _lastError = 'Failed to initialize backend: $e';
      rethrow;
    }
  }

  /// Load a GGUF model from the given [modelPath].
  ///
  /// If [modelPath] is null, looks for a model file in the app's documents
  /// directory matching common naming patterns.
  ///
  /// Returns the path of the loaded model.
  Future<String> loadModel([String? modelPath]) async {
    if (_engine == null) {
      throw StateError(
        'Engine not initialized. Call initialize() first.',
      );
    }

    _status = InferenceStatus.loading;
    _lastError = null;

    try {
      final resolvedPath = modelPath ?? await _findModelInDocuments();

      if (resolvedPath == null) {
        throw FileSystemException(
          'No model file found. Copy a .gguf file to the app documents directory.',
        );
      }

      final file = File(resolvedPath);
      if (!file.existsSync()) {
        throw FileSystemException(
          'Model file not found at: $resolvedPath',
        );
      }

      await _engine!.loadModel(resolvedPath);
      _loadedModelPath = resolvedPath;
      _status = InferenceStatus.modelLoaded;
      return resolvedPath;
    } catch (e) {
      _status = InferenceStatus.error;
      _lastError = 'Failed to load model: $e';
      rethrow;
    }
  }

  /// Generate a response to [prompt] as a stream of tokens.
  ///
  /// Yields individual tokens as they are generated. The caller can
  /// concatenate them for the full response, or display them incrementally
  /// for a typewriter effect.
  ///
  /// [maxTokens] limits the number of tokens generated (default: 256).
  Stream<String> generate(String prompt, {int maxTokens = 256}) async* {
    if (_engine == null || _status != InferenceStatus.modelLoaded) {
      throw StateError(
        'Model not loaded. Call initialize() then loadModel() first.',
      );
    }

    _status = InferenceStatus.generating;
    _lastError = null;

    try {
      int tokenCount = 0;
      await for (final token in _engine!.generate(prompt)) {
        yield token;
        tokenCount++;
        if (tokenCount >= maxTokens) break;
      }
      _status = InferenceStatus.modelLoaded;
    } catch (e) {
      _status = InferenceStatus.error;
      _lastError = 'Inference failed: $e';
      rethrow;
    }
  }

  /// Generate a complete response to [prompt] (non-streaming).
  ///
  /// Convenience method that collects all tokens into a single string.
  /// For UI with typewriter effects, prefer [generate] instead.
  Future<String> generateComplete(String prompt, {int maxTokens = 256}) async {
    final tokens = <String>[];
    await for (final token in generate(prompt, maxTokens: maxTokens)) {
      tokens.add(token);
    }
    return tokens.join('');
  }

  /// Returns the default model directory path (app documents directory).
  Future<String> getModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return docsDir.path;
  }

  /// Dispose of the engine and backend, releasing native resources.
  ///
  /// After calling dispose, the service cannot be reused. Create a new
  /// instance if needed.
  Future<void> dispose() async {
    if (_engine != null) {
      try {
        await _engine!.dispose();
      } catch (_) {
        // Best-effort cleanup
      }
    }
    _engine = null;
    _backend = null;
    _loadedModelPath = null;
    _status = InferenceStatus.disposed;
  }

  /// Search the app documents directory for a .gguf model file.
  Future<String?> _findModelInDocuments() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final entries = docsDir.listSync();

    // Look for .gguf files, preferring known names
    final preferredNames = [
      'model.gguf',
      'dante_model.gguf',
      'spike_model.gguf',
    ];

    for (final name in preferredNames) {
      final candidate = File('${docsDir.path}/$name');
      if (candidate.existsSync()) {
        return candidate.path;
      }
    }

    // Fall back to any .gguf file
    for (final entry in entries) {
      if (entry.path.endsWith('.gguf') && entry is File) {
        return entry.path;
      }
    }

    return null;
  }
}
