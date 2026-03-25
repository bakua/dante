import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/config/model_config.dart';

void main() {
  group('ModelConfig', () {
    test('downloadUrl is a valid HuggingFace direct-download URL ending in .gguf', () {
      final uri = Uri.parse(ModelConfig.downloadUrl);

      // Must be a valid parseable URI
      expect(uri.hasScheme, isTrue);
      expect(uri.scheme, 'https');

      // Must be hosted on HuggingFace
      expect(uri.host, 'huggingface.co');

      // Must use the /resolve/ path pattern (direct download)
      expect(uri.path, contains('/resolve/'));

      // Must end with .gguf
      expect(ModelConfig.downloadUrl, endsWith('.gguf'));
    });

    test('sha256 is a valid 64-character lowercase hex string', () {
      expect(ModelConfig.sha256.length, 64);
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(ModelConfig.sha256),
        isTrue,
        reason: 'SHA-256 must be 64 lowercase hex characters',
      );
    });

    test('expectedFileSize is a positive value consistent with ~986 MB', () {
      // Must be positive
      expect(ModelConfig.expectedFileSize, greaterThan(0));

      // Qwen2-1.5B Q4_K_M is ~986 MB; sanity-check range 900-1100 MB
      const mb900 = 900 * 1024 * 1024;
      const mb1100 = 1100 * 1024 * 1024;
      expect(ModelConfig.expectedFileSize, greaterThan(mb900));
      expect(ModelConfig.expectedFileSize, lessThan(mb1100));
    });

    test('fileName ends with .gguf', () {
      expect(ModelConfig.fileName, endsWith('.gguf'));
    });
  });
}
