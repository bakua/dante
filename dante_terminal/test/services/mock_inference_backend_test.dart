import 'package:flutter_test/flutter_test.dart';

import 'package:dante_terminal/services/game_session.dart';
import 'package:dante_terminal/services/mock_inference_backend.dart';

void main() {
  group('MockInferenceBackend', () {
    late MockInferenceBackend mock;

    setUp(() {
      mock = MockInferenceBackend();
    });

    test('generate produces valid GBNF-formatted response with 3 suggestions',
        () async {
      final tokens = <String>[];
      await for (final token in mock.generate('test prompt')) {
        tokens.add(token);
      }
      final response = tokens.join('');

      // Parse with GameSession's parser to verify format compliance
      final parsed = GameSession.parseResponse(response);
      expect(parsed.narrative, isNotEmpty);
      expect(parsed.suggestions, hasLength(3));
    });

    test('streams tokens incrementally, not as one chunk', () async {
      int tokenCount = 0;
      await for (final _ in mock.generate('test')) {
        tokenCount++;
      }
      // Should emit multiple small chunks, not one big string
      expect(tokenCount, greaterThan(5));
    });

    test('cycles through different responses on successive calls', () async {
      final responses = <String>[];

      for (var i = 0; i < 3; i++) {
        final tokens = <String>[];
        await for (final token in mock.generate('prompt $i')) {
          tokens.add(token);
        }
        responses.add(tokens.join(''));
      }

      // Each response should be different
      expect(responses[0], isNot(responses[1]));
      expect(responses[1], isNot(responses[2]));
    });

    test('wraps around after exhausting all canned responses', () async {
      // Exhaust all responses
      for (var i = 0; i < kMockResponses.length; i++) {
        await mock.generate('prompt $i').drain<void>();
      }

      // Next response should cycle back to the first
      final tokens = <String>[];
      await for (final token in mock.generate('next')) {
        tokens.add(token);
      }
      final response = tokens.join('');

      // Should match the first canned response
      expect(response, kMockResponses[0]);
    });

    test('reset returns to the first response', () async {
      // Get first response
      final tokens1 = <String>[];
      await for (final t in mock.generate('a')) {
        tokens1.add(t);
      }

      // Get second response (should be different)
      final tokens2 = <String>[];
      await for (final t in mock.generate('b')) {
        tokens2.add(t);
      }
      expect(tokens1.join(''), isNot(tokens2.join('')));

      // Reset and verify first response is returned again
      mock.reset();
      final tokens3 = <String>[];
      await for (final t in mock.generate('c')) {
        tokens3.add(t);
      }
      expect(tokens3.join(''), tokens1.join(''));
    });

    test('all canned responses parse to exactly 3 suggestions', () {
      for (var i = 0; i < kMockResponses.length; i++) {
        final parsed = GameSession.parseResponse(kMockResponses[i]);
        expect(
          parsed.suggestions.length,
          3,
          reason: 'Response $i should have exactly 3 suggestions',
        );
      }
    });

    test('all canned responses have non-empty narrative text', () {
      for (var i = 0; i < kMockResponses.length; i++) {
        final parsed = GameSession.parseResponse(kMockResponses[i]);
        expect(
          parsed.narrative,
          isNotEmpty,
          reason: 'Response $i should have non-empty narrative',
        );
      }
    });

    test('generate accepts optional parameters without error', () async {
      // Should accept all GenerateFunction parameters gracefully
      final tokens = <String>[];
      await for (final token in mock.generate(
        'test',
        maxTokens: 100,
        grammarFilePath: '/path/to/grammar.gbnf',
      )) {
        tokens.add(token);
      }
      expect(tokens.join(''), isNotEmpty);
    });
  });
}
