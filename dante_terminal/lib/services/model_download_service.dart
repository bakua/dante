/// HTTP model download service with progress reporting, pause/resume via
/// Range headers, and SHA-256 integrity verification.
///
/// Implements the first-launch model delivery flow designed in BL-087.
/// The app currently shows "Copy a .gguf file to: [path]" on fresh install —
/// this service replaces that developer workflow with programmatic downloads.
///
/// Uses only dart:async, dart:io, and package:crypto for independent unit
/// testing (no Flutter imports). HTTP operations are abstracted behind
/// [HttpClientAdapter] for dependency injection in tests.
///
/// See also:
/// - BL-087: Model delivery strategy (hosting, download flow, size budgets)
/// - BL-123: Model selection matrix (Qwen2 1.5B Q4_K_M primary candidate)
/// - [InferenceService.getModelDirectory]: destination path source
/// - [InferenceService._findModelInDocuments]: model discovery logic
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

// ---------------------------------------------------------------------------
// Download status
// ---------------------------------------------------------------------------

/// Status of a model download operation.
enum DownloadStatus {
  /// No download in progress or pending.
  idle,

  /// Actively downloading bytes from the server.
  downloading,

  /// Download paused by user; .part file preserved for resume.
  paused,

  /// Download complete; computing SHA-256 checksum.
  verifying,

  /// Download and optional verification completed successfully.
  completed,

  /// Download failed due to an error.
  failed,

  /// Download cancelled by user; .part file deleted.
  cancelled,
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for a model download.
class ModelDownloadConfig {
  /// The URL to download the model from.
  final Uri url;

  /// Local filesystem path for the final downloaded file.
  ///
  /// During download, data is written to `$destinationPath.part` and
  /// renamed on successful completion.
  final String destinationPath;

  /// Expected lowercase hex SHA-256 hash of the complete file.
  ///
  /// When non-null, verification runs after download completes and
  /// throws [ChecksumMismatchException] on mismatch.
  final String? expectedSha256;

  const ModelDownloadConfig({
    required this.url,
    required this.destinationPath,
    this.expectedSha256,
  });
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Exception thrown when SHA-256 checksum verification fails after download.
class ChecksumMismatchException implements Exception {
  /// The expected hash from [ModelDownloadConfig.expectedSha256].
  final String expected;

  /// The actual hash computed from the downloaded file.
  final String actual;

  ChecksumMismatchException({required this.expected, required this.actual});

  @override
  String toString() =>
      'ChecksumMismatchException: expected $expected, got $actual';
}

// ---------------------------------------------------------------------------
// HTTP abstraction (for testability)
// ---------------------------------------------------------------------------

/// Minimal HTTP abstraction for dependency injection and testing.
///
/// Wraps the essentials of an HTTP GET with optional headers, producing
/// a [DownloadHttpResponse] whose body is a byte stream.
abstract class HttpClientAdapter {
  /// Perform an HTTP GET request to [url] with optional [headers].
  Future<DownloadHttpResponse> get(Uri url, {Map<String, String>? headers});

  /// Close underlying connections.
  void close();
}

/// Represents an HTTP response with status code, content length, and body.
class DownloadHttpResponse {
  final int statusCode;

  /// Length of the body in bytes. May be -1 if unknown.
  final int contentLength;

  /// Byte stream of the response body.
  final Stream<List<int>> bodyStream;

  DownloadHttpResponse({
    required this.statusCode,
    required this.contentLength,
    required this.bodyStream,
  });
}

/// Default [HttpClientAdapter] using dart:io's [HttpClient].
///
/// Creates a fresh [HttpClient] for each request to support the
/// close-and-reconnect pattern required by pause/resume.
class DartHttpClientAdapter implements HttpClientAdapter {
  HttpClient? _client;

  @override
  Future<DownloadHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    _client = HttpClient();
    final request = await _client!.getUrl(url);
    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });
    final response = await request.close();
    return DownloadHttpResponse(
      statusCode: response.statusCode,
      contentLength: response.contentLength,
      bodyStream: response,
    );
  }

  @override
  void close() {
    _client?.close(force: true);
    _client = null;
  }
}

// ---------------------------------------------------------------------------
// ModelDownloadService
// ---------------------------------------------------------------------------

/// Downloads GGUF model files with progress reporting, pause/resume via
/// HTTP Range headers, and optional SHA-256 integrity verification.
///
/// Designed for first-launch onboarding where the app downloads a 1–2 GB
/// model file from a CDN. Follows the delivery architecture from BL-087.
///
/// Usage:
/// ```dart
/// final service = ModelDownloadService();
/// service.progress.listen((p) => print('${(p * 100).toInt()}%'));
///
/// await service.download(ModelDownloadConfig(
///   url: Uri.parse('https://cdn.example.com/model.gguf'),
///   destinationPath: '${docsDir.path}/model.gguf',
///   expectedSha256: 'abc123...',
/// ));
/// ```
class ModelDownloadService {
  final HttpClientAdapter _httpAdapter;
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  DownloadStatus _status = DownloadStatus.idle;
  String? _lastError;
  int _bytesDownloaded = 0;
  int _totalBytes = 0;
  ModelDownloadConfig? _config;
  bool _cancelRequested = false;
  bool _pauseRequested = false;

  /// Creates a download service with an optional [httpAdapter] for testing.
  ///
  /// In production, omit [httpAdapter] to use the default dart:io client.
  ModelDownloadService({HttpClientAdapter? httpAdapter})
      : _httpAdapter = httpAdapter ?? DartHttpClientAdapter();

  /// Current download status.
  DownloadStatus get status => _status;

  /// Last error message, if [status] is [DownloadStatus.failed].
  String? get lastError => _lastError;

  /// Bytes downloaded so far in the current (or last) download.
  int get bytesDownloaded => _bytesDownloaded;

  /// Total bytes expected for the download (0 if unknown).
  int get totalBytes => _totalBytes;

  /// Stream of download progress values from 0.0 to 1.0.
  ///
  /// Emits on each received chunk. Broadcast stream — multiple
  /// listeners are supported (e.g. progress bar + logging).
  Stream<double> get progress => _progressController.stream;

  /// Start downloading a model file.
  ///
  /// Automatically resumes from a `.part` file if one exists at
  /// `config.destinationPath + '.part'`. When [config.expectedSha256]
  /// is provided, verifies the completed file and throws
  /// [ChecksumMismatchException] on mismatch.
  ///
  /// Throws [StateError] if a download is already in progress.
  Future<void> download(ModelDownloadConfig config) async {
    if (_status == DownloadStatus.downloading) {
      throw StateError('Download already in progress');
    }

    _config = config;
    _cancelRequested = false;
    _pauseRequested = false;
    _lastError = null;

    await _executeDownload();
  }

  /// Pause the current download.
  ///
  /// The partial file is preserved for later [resume]. No-op if not
  /// currently downloading.
  void pause() {
    if (_status != DownloadStatus.downloading) return;
    _pauseRequested = true;
  }

  /// Resume a paused download using HTTP Range headers.
  ///
  /// Sends `Range: bytes=N-` where N is the size of the existing
  /// `.part` file, continuing from where the download left off.
  ///
  /// Throws [StateError] if the download was not previously paused or
  /// if no download config is available.
  Future<void> resume() async {
    if (_status != DownloadStatus.paused) {
      throw StateError('Cannot resume: status is $_status');
    }
    if (_config == null) {
      throw StateError('Cannot resume: no download config');
    }

    _pauseRequested = false;
    _cancelRequested = false;

    await _executeDownload();
  }

  /// Cancel the current or paused download.
  ///
  /// Deletes the `.part` file and resets byte counters. No-op if idle
  /// or already completed.
  void cancel() {
    if (_status == DownloadStatus.idle ||
        _status == DownloadStatus.completed) {
      return;
    }

    _cancelRequested = true;

    // If paused, clean up immediately since no active download loop
    if (_status == DownloadStatus.paused && _config != null) {
      final partFile = File('${_config!.destinationPath}.part');
      if (partFile.existsSync()) {
        partFile.deleteSync();
      }
      _status = DownloadStatus.cancelled;
      _bytesDownloaded = 0;
    }
  }

  /// Release resources. Must be called when the service is no longer needed.
  void dispose() {
    _progressController.close();
    _httpAdapter.close();
  }

  // ─── Private implementation ──────────────────────────────────────────────

  Future<void> _executeDownload() async {
    final config = _config!;
    _status = DownloadStatus.downloading;

    try {
      final partFilePath = '${config.destinationPath}.part';
      final partFile = File(partFilePath);

      // Ensure parent directory exists
      await partFile.parent.create(recursive: true);

      // Determine resume offset from existing .part file
      _bytesDownloaded = partFile.existsSync() ? partFile.lengthSync() : 0;

      // Build request headers (Range for resume)
      final headers = <String, String>{};
      if (_bytesDownloaded > 0) {
        headers['Range'] = 'bytes=$_bytesDownloaded-';
      }

      final response = await _httpAdapter.get(config.url, headers: headers);

      // Interpret response status
      if (response.statusCode == 200) {
        // Full content — server ignored Range or fresh download
        _bytesDownloaded = 0;
        _totalBytes = response.contentLength;
      } else if (response.statusCode == 206) {
        // Partial content — resuming
        _totalBytes = _bytesDownloaded + response.contentLength;
      } else {
        throw HttpException(
          'Unexpected HTTP status: ${response.statusCode}',
        );
      }

      // Open file for writing (append if resuming with 206)
      final sink = partFile.openWrite(
        mode: _bytesDownloaded > 0 && response.statusCode == 206
            ? FileMode.append
            : FileMode.write,
      );

      try {
        await for (final chunk in response.bodyStream) {
          // Check cancel flag
          if (_cancelRequested) {
            await sink.flush();
            await sink.close();
            if (partFile.existsSync()) {
              await partFile.delete();
            }
            _status = DownloadStatus.cancelled;
            _bytesDownloaded = 0;
            return;
          }

          // Check pause flag
          if (_pauseRequested) {
            await sink.flush();
            await sink.close();
            _httpAdapter.close();
            _status = DownloadStatus.paused;
            return;
          }

          sink.add(chunk);
          _bytesDownloaded += chunk.length;

          if (_totalBytes > 0) {
            final progress =
                (_bytesDownloaded / _totalBytes).clamp(0.0, 1.0);
            _progressController.add(progress);
          }
        }

        await sink.flush();
        await sink.close();
      } catch (e) {
        // Ensure sink is closed on error before rethrowing
        try {
          await sink.close();
        } catch (_) {
          // Best-effort cleanup
        }
        rethrow;
      }

      // ── Checksum verification ──
      if (config.expectedSha256 != null) {
        _status = DownloadStatus.verifying;
        _progressController.add(1.0);

        final actualHash = await _computeSha256(partFile);
        if (actualHash != config.expectedSha256!.toLowerCase()) {
          // Delete corrupted file
          if (partFile.existsSync()) {
            await partFile.delete();
          }
          throw ChecksumMismatchException(
            expected: config.expectedSha256!.toLowerCase(),
            actual: actualHash,
          );
        }
      }

      // Rename .part → final destination
      await partFile.rename(config.destinationPath);

      _status = DownloadStatus.completed;
      _progressController.add(1.0);
    } catch (e) {
      if (_status != DownloadStatus.cancelled &&
          _status != DownloadStatus.paused) {
        _status = DownloadStatus.failed;
        _lastError = e.toString();
      }
      // Only rethrow if not a controlled exit (cancel/pause)
      if (_status == DownloadStatus.cancelled ||
          _status == DownloadStatus.paused) {
        return;
      }
      rethrow;
    } finally {
      _httpAdapter.close();
    }
  }

  /// Compute SHA-256 hash of a file using streaming reads.
  ///
  /// Processes the file in chunks to avoid loading the entire 1–2 GB
  /// model into memory at once.
  Future<String> _computeSha256(File file) async {
    final digestSink = _SingleDigestSink();
    final byteSink = sha256.startChunkedConversion(digestSink);

    await for (final chunk in file.openRead()) {
      byteSink.add(chunk);
    }
    byteSink.close();

    return digestSink.digest.toString();
  }
}

/// Collects a single [Digest] from a chunked hash conversion.
///
/// Used by [ModelDownloadService._computeSha256] to avoid depending on
/// `package:convert`'s AccumulatorSink.
class _SingleDigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get digest {
    if (_digest == null) throw StateError('No digest computed');
    return _digest!;
  }

  @override
  void add(Digest data) => _digest = data;

  @override
  void close() {}
}
