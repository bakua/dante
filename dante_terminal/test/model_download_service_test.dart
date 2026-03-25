import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/model_download_service.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter
// ---------------------------------------------------------------------------

/// Mock [HttpClientAdapter] that serves content from an in-memory byte list.
///
/// Automatically handles Range headers: when a request includes
/// `Range: bytes=N-`, the response returns status 206 with bytes from
/// offset N, simulating HTTP resume semantics.
class MockHttpClientAdapter implements HttpClientAdapter {
  final List<int> fullContent;
  final int chunkSize;

  /// Tracks all requests made (URL + headers) for assertion.
  final List<({Uri url, Map<String, String>? headers})> calls = [];

  /// Override the status code for error testing.
  /// When non-null, this status code is returned regardless of Range headers.
  final int? overrideStatusCode;

  int get callCount => calls.length;

  MockHttpClientAdapter({
    required this.fullContent,
    this.chunkSize = 1024,
    this.overrideStatusCode,
  });

  @override
  Future<DownloadHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    calls.add((url: url, headers: headers));

    // Allow error testing
    if (overrideStatusCode != null &&
        overrideStatusCode != 200 &&
        overrideStatusCode != 206) {
      return DownloadHttpResponse(
        statusCode: overrideStatusCode!,
        contentLength: 0,
        bodyStream: const Stream.empty(),
      );
    }

    // Parse Range header for resume support
    int startByte = 0;
    int statusCode = 200;
    final rangeHeader = headers?['Range'];
    if (rangeHeader != null) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
      if (match != null) {
        startByte = int.parse(match.group(1)!);
        statusCode = 206;
      }
    }

    final body = fullContent.sublist(startByte);

    // Stream body in chunks with yields to allow consumer processing
    final controller = StreamController<List<int>>();
    bool cancelled = false;
    controller.onCancel = () {
      cancelled = true;
    };

    Future(() async {
      for (var i = 0; i < body.length; i += chunkSize) {
        if (cancelled) break;
        final end = (i + chunkSize).clamp(0, body.length);
        controller.add(body.sublist(i, end));
        // Yield to event loop so the consumer can process and set flags
        await Future.delayed(Duration.zero);
      }
      if (!cancelled && !controller.isClosed) {
        await controller.close();
      }
    });

    return DownloadHttpResponse(
      statusCode: statusCode,
      contentLength: body.length,
      bodyStream: controller.stream,
    );
  }

  @override
  void close() {
    // No-op for mock
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates test data of the given [size] and returns both the bytes and
/// their SHA-256 hash as a lowercase hex string.
({List<int> bytes, String sha256Hash}) createTestData(int size) {
  final bytes = List<int>.generate(size, (i) => i % 256);
  final hash = sha256.convert(bytes).toString();
  return (bytes: bytes, sha256Hash: hash);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('model_download_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ModelDownloadService', () {
    test('starts in idle status with null error', () {
      final service = ModelDownloadService();
      expect(service.status, DownloadStatus.idle);
      expect(service.lastError, isNull);
      expect(service.bytesDownloaded, 0);
      expect(service.totalBytes, 0);
      service.dispose();
    });

    test('download completes successfully and produces correct file', () async {
      final testData = createTestData(4096);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 512,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      expect(service.status, DownloadStatus.completed);
      expect(File(destPath).existsSync(), isTrue);
      expect(File(destPath).readAsBytesSync(), testData.bytes);

      // .part file should have been renamed away
      expect(File('$destPath.part').existsSync(), isFalse);

      service.dispose();
    });

    test('emits monotonically increasing progress values ending at 1.0',
        () async {
      final testData = createTestData(2048);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 256,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      final progressValues = <double>[];
      service.progress.listen(progressValues.add);

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      // Should have emitted progress values
      expect(progressValues, isNotEmpty);

      // All values in [0.0, 1.0]
      for (final p in progressValues) {
        expect(p, greaterThanOrEqualTo(0.0));
        expect(p, lessThanOrEqualTo(1.0));
      }

      // Last value should be 1.0 (completion signal)
      expect(progressValues.last, 1.0);

      // Values should be monotonically non-decreasing
      for (var i = 1; i < progressValues.length; i++) {
        expect(progressValues[i], greaterThanOrEqualTo(progressValues[i - 1]));
      }

      service.dispose();
    });

    test('SHA-256 verification passes with correct hash', () async {
      final testData = createTestData(1024);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 256,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
        expectedSha256: testData.sha256Hash,
      ));

      expect(service.status, DownloadStatus.completed);
      expect(File(destPath).existsSync(), isTrue);
      expect(File(destPath).readAsBytesSync(), testData.bytes);

      service.dispose();
    });

    test('SHA-256 verification throws ChecksumMismatchException on mismatch',
        () async {
      final testData = createTestData(1024);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 512,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      await expectLater(
        service.download(ModelDownloadConfig(
          url: Uri.parse('https://cdn.example.com/model.gguf'),
          destinationPath: destPath,
          expectedSha256: 'deadbeef' * 8, // 64 hex chars, wrong hash
        )),
        throwsA(isA<ChecksumMismatchException>()),
      );

      expect(service.status, DownloadStatus.failed);

      service.dispose();
    });

    test('SHA-256 mismatch deletes the .part file', () async {
      final testData = createTestData(1024);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 512,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      try {
        await service.download(ModelDownloadConfig(
          url: Uri.parse('https://cdn.example.com/model.gguf'),
          destinationPath: destPath,
          expectedSha256: 'deadbeef' * 8,
        ));
      } on ChecksumMismatchException {
        // expected
      }

      // Both .part and final should not exist after checksum failure
      expect(File('$destPath.part').existsSync(), isFalse);
      expect(File(destPath).existsSync(), isFalse);

      service.dispose();
    });

    test('ChecksumMismatchException contains expected and actual hashes',
        () async {
      final testData = createTestData(512);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 512,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      final wrongHash = 'deadbeef' * 8;
      try {
        await service.download(ModelDownloadConfig(
          url: Uri.parse('https://cdn.example.com/model.gguf'),
          destinationPath: destPath,
          expectedSha256: wrongHash,
        ));
        fail('Expected ChecksumMismatchException');
      } on ChecksumMismatchException catch (e) {
        expect(e.expected, wrongHash);
        expect(e.actual, testData.sha256Hash);
        expect(e.toString(), contains(wrongHash));
        expect(e.toString(), contains(testData.sha256Hash));
      }

      service.dispose();
    });

    test('cancel during download sets cancelled status and cleans up',
        () async {
      final testData = createTestData(8192);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 64, // Small chunks to give time for cancel
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      // Cancel after first progress emission
      var cancelSent = false;
      service.progress.listen((_) {
        if (!cancelSent) {
          cancelSent = true;
          service.cancel();
        }
      });

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      expect(service.status, DownloadStatus.cancelled);
      // .part file should be cleaned up after cancel
      expect(File('$destPath.part').existsSync(), isFalse);

      service.dispose();
    });

    test('pause during download preserves .part file', () async {
      final testData = createTestData(8192);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 64, // Small chunks for pause timing
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      var pauseSent = false;
      service.progress.listen((_) {
        if (!pauseSent) {
          pauseSent = true;
          service.pause();
        }
      });

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      expect(service.status, DownloadStatus.paused);
      // .part file should exist with partial data
      expect(File('$destPath.part').existsSync(), isTrue);
      final partSize = File('$destPath.part').lengthSync();
      expect(partSize, greaterThan(0));
      expect(partSize, lessThan(testData.bytes.length));
      expect(service.bytesDownloaded, partSize);

      service.dispose();
    });

    test('resume sends Range header and completes download', () async {
      final testData = createTestData(4096);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 64,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      // Phase 1: start and pause
      var pauseSent = false;
      late StreamSubscription<double> sub;
      sub = service.progress.listen((_) {
        if (!pauseSent) {
          pauseSent = true;
          service.pause();
        }
      });

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      expect(service.status, DownloadStatus.paused);
      final bytesAfterPause = service.bytesDownloaded;
      expect(bytesAfterPause, greaterThan(0));

      // Cancel the pause listener before resuming
      await sub.cancel();

      // Phase 2: resume (should send Range header)
      await service.resume();

      expect(service.status, DownloadStatus.completed);
      expect(File(destPath).existsSync(), isTrue);
      expect(File(destPath).readAsBytesSync(), testData.bytes);

      // Verify Range header was sent on the resume request
      expect(adapter.callCount, 2);
      final resumeHeaders = adapter.calls[1].headers;
      expect(resumeHeaders, isNotNull);
      expect(resumeHeaders!['Range'], 'bytes=$bytesAfterPause-');

      service.dispose();
    });

    test('handles HTTP error status codes', () async {
      final adapter = MockHttpClientAdapter(
        fullContent: [],
        overrideStatusCode: 404,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      await expectLater(
        service.download(ModelDownloadConfig(
          url: Uri.parse('https://cdn.example.com/model.gguf'),
          destinationPath: destPath,
        )),
        throwsA(isA<HttpException>()),
      );

      expect(service.status, DownloadStatus.failed);
      expect(service.lastError, contains('404'));

      service.dispose();
    });

    test('handles HTTP 500 server error', () async {
      final adapter = MockHttpClientAdapter(
        fullContent: [],
        overrideStatusCode: 500,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      await expectLater(
        service.download(ModelDownloadConfig(
          url: Uri.parse('https://cdn.example.com/model.gguf'),
          destinationPath: destPath,
        )),
        throwsA(isA<HttpException>()),
      );

      expect(service.status, DownloadStatus.failed);
      expect(service.lastError, contains('500'));

      service.dispose();
    });

    test('resume throws StateError when not paused', () {
      final service = ModelDownloadService();

      expect(
        () => service.resume(),
        throwsStateError,
      );

      service.dispose();
    });

    test('cancel when idle is a no-op', () {
      final service = ModelDownloadService();
      service.cancel(); // Should not throw
      expect(service.status, DownloadStatus.idle);
      service.dispose();
    });

    test('cancel when paused deletes .part file', () async {
      final testData = createTestData(8192);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 64,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      // Pause first
      var pauseSent = false;
      service.progress.listen((_) {
        if (!pauseSent) {
          pauseSent = true;
          service.pause();
        }
      });

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      expect(service.status, DownloadStatus.paused);
      expect(File('$destPath.part').existsSync(), isTrue);

      // Now cancel
      service.cancel();

      expect(service.status, DownloadStatus.cancelled);
      expect(File('$destPath.part').existsSync(), isFalse);
      expect(service.bytesDownloaded, 0);

      service.dispose();
    });

    test('download creates parent directories if missing', () async {
      final testData = createTestData(256);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/nested/deep/dir/model.gguf';

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      expect(service.status, DownloadStatus.completed);
      expect(File(destPath).existsSync(), isTrue);

      service.dispose();
    });

    test('download without SHA-256 skips verification', () async {
      final testData = createTestData(512);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      // Track status transitions
      final statuses = <DownloadStatus>[];
      service.progress.listen((_) {
        if (statuses.isEmpty || statuses.last != service.status) {
          statuses.add(service.status);
        }
      });

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
        // No expectedSha256 — verification should be skipped
      ));

      expect(service.status, DownloadStatus.completed);
      // Should NOT have gone through verifying status
      expect(statuses, isNot(contains(DownloadStatus.verifying)));

      service.dispose();
    });

    test('SHA-256 comparison is case-insensitive', () async {
      final testData = createTestData(256);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      // Provide uppercase hash — should still pass
      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
        expectedSha256: testData.sha256Hash.toUpperCase(),
      ));

      expect(service.status, DownloadStatus.completed);

      service.dispose();
    });

    test('progress stream is broadcast (supports multiple listeners)',
        () async {
      final testData = createTestData(1024);
      final adapter = MockHttpClientAdapter(
        fullContent: testData.bytes,
        chunkSize: 256,
      );
      final service = ModelDownloadService(httpAdapter: adapter);
      final destPath = '${tempDir.path}/model.gguf';

      final values1 = <double>[];
      final values2 = <double>[];
      service.progress.listen(values1.add);
      service.progress.listen(values2.add);

      await service.download(ModelDownloadConfig(
        url: Uri.parse('https://cdn.example.com/model.gguf'),
        destinationPath: destPath,
      ));

      // Both listeners should have received the same values
      expect(values1, isNotEmpty);
      expect(values1, values2);

      service.dispose();
    });

    test('DownloadStatus enum has expected values', () {
      expect(DownloadStatus.values, hasLength(7));
      expect(DownloadStatus.values, contains(DownloadStatus.idle));
      expect(DownloadStatus.values, contains(DownloadStatus.downloading));
      expect(DownloadStatus.values, contains(DownloadStatus.paused));
      expect(DownloadStatus.values, contains(DownloadStatus.verifying));
      expect(DownloadStatus.values, contains(DownloadStatus.completed));
      expect(DownloadStatus.values, contains(DownloadStatus.failed));
      expect(DownloadStatus.values, contains(DownloadStatus.cancelled));
    });
  });
}
