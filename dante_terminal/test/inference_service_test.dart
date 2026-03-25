import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/inference_service.dart';

/// Tests for InferenceService lifecycle and API surface.
///
/// NOTE: Full model-loading and inference tests require a real GGUF model file
/// and a native llama.cpp backend (i.e., they must run on a real device or
/// simulator, not in the Dart test runner). These tests verify the service's
/// state machine, error handling, and API contracts using only Dart-level logic.
void main() {
  group('InferenceService', () {
    late InferenceService service;

    setUp(() {
      service = InferenceService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('starts in uninitialized state', () {
      expect(service.status, InferenceStatus.uninitialized);
      expect(service.isReady, isFalse);
      expect(service.loadedModelPath, isNull);
      expect(service.lastError, isNull);
    });

    test('isReady is false before initialization', () {
      expect(service.isReady, isFalse);
    });

    test('generate throws StateError when model not loaded', () {
      expect(
        () => service.generate('test prompt').first,
        throwsStateError,
      );
    });

    test('generateComplete throws StateError when model not loaded', () {
      expect(
        () => service.generateComplete('test prompt'),
        throwsStateError,
      );
    });

    test('loadModel throws StateError when engine not initialized', () {
      expect(
        () => service.loadModel('/fake/path.gguf'),
        throwsStateError,
      );
    });

    test('dispose sets status to disposed', () async {
      await service.dispose();
      expect(service.status, InferenceStatus.disposed);
      expect(service.isReady, isFalse);
      expect(service.loadedModelPath, isNull);
    });

    test('initialize is idempotent after first call attempt', () async {
      // First call will attempt native init — may throw in test env
      // but the service should handle the state transition correctly.
      try {
        await service.initialize();
        // If it succeeded, subsequent calls should be no-ops
        await service.initialize();
        expect(
          service.status,
          anyOf(InferenceStatus.ready, InferenceStatus.error),
        );
      } catch (_) {
        // Expected in test environment without native backend
        expect(service.status, InferenceStatus.error);
        expect(service.lastError, isNotNull);
      }
    });

    test('InferenceStatus enum has expected values', () {
      expect(InferenceStatus.values, hasLength(8));
      expect(InferenceStatus.values, contains(InferenceStatus.uninitialized));
      expect(InferenceStatus.values, contains(InferenceStatus.initializing));
      expect(InferenceStatus.values, contains(InferenceStatus.ready));
      expect(InferenceStatus.values, contains(InferenceStatus.loading));
      expect(InferenceStatus.values, contains(InferenceStatus.modelLoaded));
      expect(InferenceStatus.values, contains(InferenceStatus.generating));
      expect(InferenceStatus.values, contains(InferenceStatus.error));
      expect(InferenceStatus.values, contains(InferenceStatus.disposed));
    });
  });
}
