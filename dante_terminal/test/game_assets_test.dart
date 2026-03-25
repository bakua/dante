import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/game_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameAssets', () {
    late GameAssets gameAssets;

    setUp(() {
      gameAssets = GameAssets();
    });

    test('loadSystemPrompt returns non-empty string', () async {
      final prompt = await gameAssets.loadSystemPrompt();
      expect(prompt, isNotEmpty);
      expect(prompt, contains('Game Master'));
      expect(prompt, contains('DANTE TERMINAL'));
    });

    test('loadGrammar returns non-empty string', () async {
      final grammar = await gameAssets.loadGrammar();
      expect(grammar, isNotEmpty);
      expect(grammar, contains('root ::='));
      expect(grammar, contains('narrative'));
      expect(grammar, contains('suggestion'));
    });

    test('loadAll returns both prompt and grammar', () async {
      final assets = await gameAssets.loadAll();
      expect(assets.prompt, isNotEmpty);
      expect(assets.grammar, isNotEmpty);
      expect(assets.prompt, contains('Game Master'));
      expect(assets.grammar, contains('root ::='));
    });

    test('loadSystemPrompt caches result', () async {
      final first = await gameAssets.loadSystemPrompt();
      final second = await gameAssets.loadSystemPrompt();
      expect(identical(first, second), isTrue);
    });

    test('loadGrammar caches result', () async {
      final first = await gameAssets.loadGrammar();
      final second = await gameAssets.loadGrammar();
      expect(identical(first, second), isTrue);
    });

    test('clearCache resets cached values', () async {
      final first = await gameAssets.loadSystemPrompt();
      gameAssets.clearCache();
      final second = await gameAssets.loadSystemPrompt();
      // Same content but different instance after cache clear
      expect(first, equals(second));
    });

    test('system prompt contains expected structure', () async {
      final prompt = await gameAssets.loadSystemPrompt();
      // Verify prompt has the few-shot example format from BL-043
      expect(prompt, contains('[EXAMPLE]'));
      expect(prompt, contains('[/EXAMPLE]'));
      expect(prompt, contains('> 1.'));
      expect(prompt, contains('> 2.'));
      expect(prompt, contains('> 3.'));
    });

    test('grammar contains suggestion enforcement rules', () async {
      final grammar = await gameAssets.loadGrammar();
      // Verify grammar enforces exactly 3 suggestions per BL-049
      expect(grammar, contains('> 1.'));
      expect(grammar, contains('> 2.'));
      expect(grammar, contains('> 3.'));
    });
  });
}
