/// Production model download configuration for DANTE TERMINAL (BL-132).
///
/// Central source of truth for the on-device AI model's download URL,
/// integrity checksum, and expected file size. All values correspond to
/// the **Qwen2-1.5B-Instruct Q4_K_M** GGUF file selected in BL-123.
///
/// This config is consumed by [ModelDownloadScreen] (via [_AppLauncher])
/// and [ModelDownloadService] to drive the first-run download flow.
///
/// See also:
/// - BL-123: Model selection matrix (primary pick rationale)
/// - BL-126: ModelDownloadService (download + verification logic)
/// - BL-129: ModelDownloadScreen (terminal-styled download UI)
library;

/// Constants for the production model download.
///
/// All fields are compile-time constants so they can be referenced from
/// const constructors and widget trees without allocation overhead.
abstract final class ModelConfig {
  /// Direct-download URL for the Qwen2-1.5B-Instruct Q4_K_M GGUF file
  /// hosted on HuggingFace.
  ///
  /// Uses the `/resolve/main/` path which returns a redirect to the
  /// CDN-backed blob storage, enabling fast global downloads.
  static const String downloadUrl =
      'https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/'
      'qwen2-1_5b-instruct-q4_k_m.gguf';

  /// Expected lowercase hex SHA-256 hash of the complete GGUF file.
  ///
  /// Used by [ModelDownloadService] for post-download integrity
  /// verification. Sourced from the HuggingFace LFS object store.
  static const String sha256 =
      'f521a15453fd7f820e8467f4a307c99e44f5ab9cc24273d2fe67cd7cb1288f05';

  /// Expected file size in bytes (986,045,824 bytes = ~986 MB).
  ///
  /// Used for pre-download storage checks and progress display.
  static const int expectedFileSize = 986045824;

  /// Filename stored in the app documents directory.
  ///
  /// Matches [InferenceService._findModelInDocuments]'s preferred-name
  /// list so the model is auto-discovered on subsequent launches.
  static const String fileName = 'model.gguf';
}
