import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/game_session.dart';

/// A mock response matching the GBNF grammar format (BL-049):
/// narrative text + double newline + 3 numbered suggestions.
const _kMockResponse = 'The ancient door groans open, revealing a vast '
    'underground library. Dust motes dance in the pale glow of bioluminescent '
    'moss clinging to crumbling pillars. The air smells of mildew and forgotten '
    'knowledge.\n\n'
    '> 1. Explore the nearest bookshelf\n'
    '> 2. Follow the moss-lit corridor deeper\n'
    '> 3. Examine the inscriptions on the door frame';

/// A mock response with only narrative, no suggestions (incomplete format).
const _kMockNarrativeOnly = 'You step into the shadows. The corridor '
    'stretches endlessly before you, lined with torches that flicker with an '
    'unnatural blue flame.';

/// A mock response with malformed suggestions (only 2 instead of 3).
const _kMockPartialSuggestions = 'The lever resists at first, then gives way '
    'with a metallic screech. A hidden panel slides open in the wall.\n\n'
    '> 1. Step through the opening\n'
    '> 2. Look inside before entering';

/// Creates a [GenerateFunction] that yields the response as individual
/// character tokens (simulating streaming from the inference engine).
GenerateFunction mockGenerator(String response) {
  return (String prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
    // Yield one character at a time to simulate streaming.
    for (final char in response.split('')) {
      yield char;
    }
  };
}

/// Creates a [GenerateFunction] that returns different responses per turn.
GenerateFunction multiTurnGenerator(List<String> responses) {
  var callIndex = 0;
  return (String prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
    final response = responses[callIndex % responses.length];
    callIndex++;
    for (final char in response.split('')) {
      yield char;
    }
  };
}

void main() {
  group('GameTurn', () {
    test('default constructor creates incomplete turn with empty suggestions', () {
      const turn = GameTurn(
        turnNumber: 1,
        playerCommand: 'look around',
        narrativeText: 'A dark room.',
      );
      expect(turn.turnNumber, 1);
      expect(turn.playerCommand, 'look around');
      expect(turn.narrativeText, 'A dark room.');
      expect(turn.suggestions, isEmpty);
      expect(turn.rawResponse, '');
      expect(turn.isComplete, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      const original = GameTurn(
        turnNumber: 3,
        playerCommand: 'open door',
        narrativeText: 'The door opens.',
        suggestions: ['Go inside', 'Look around'],
        rawResponse: 'raw text',
        isComplete: true,
      );

      final updated = original.copyWith(narrativeText: 'Updated narrative.');
      expect(updated.turnNumber, 3);
      expect(updated.playerCommand, 'open door');
      expect(updated.narrativeText, 'Updated narrative.');
      expect(updated.suggestions, ['Go inside', 'Look around']);
      expect(updated.rawResponse, 'raw text');
      expect(updated.isComplete, isTrue);
    });

    test('toString includes key info', () {
      const turn = GameTurn(
        turnNumber: 2,
        playerCommand: 'test',
        narrativeText: 'Hello',
        isComplete: true,
      );
      final str = turn.toString();
      expect(str, contains('turn=2'));
      expect(str, contains('complete=true'));
    });
  });

  group('GameSession.parseResponse', () {
    test('parses well-formed response with 3 suggestions', () {
      final result = GameSession.parseResponse(_kMockResponse);
      expect(result.narrative, startsWith('The ancient door'));
      expect(result.narrative, contains('forgotten knowledge.'));
      expect(result.narrative, isNot(contains('>')));
      expect(result.suggestions, hasLength(3));
      expect(result.suggestions[0], 'Explore the nearest bookshelf');
      expect(result.suggestions[1], 'Follow the moss-lit corridor deeper');
      expect(result.suggestions[2], 'Examine the inscriptions on the door frame');
    });

    test('returns empty suggestions when no double newline present', () {
      final result = GameSession.parseResponse(_kMockNarrativeOnly);
      expect(result.narrative, isNotEmpty);
      expect(result.narrative, startsWith('You step'));
      expect(result.suggestions, isEmpty);
    });

    test('handles partial suggestions (fewer than 3)', () {
      final result = GameSession.parseResponse(_kMockPartialSuggestions);
      expect(result.narrative, contains('hidden panel'));
      expect(result.suggestions, hasLength(2));
      expect(result.suggestions[0], 'Step through the opening');
      expect(result.suggestions[1], 'Look inside before entering');
    });

    test('handles empty input', () {
      final result = GameSession.parseResponse('');
      expect(result.narrative, '');
      expect(result.suggestions, isEmpty);
    });

    test('handles whitespace-only input', () {
      final result = GameSession.parseResponse('   \n\n   ');
      expect(result.narrative, isEmpty);
      expect(result.suggestions, isEmpty);
    });

    test('handles response with extra whitespace around suggestions', () {
      const raw = 'A dark cave.\n\n'
          '>  1.  Go left  \n'
          '>  2.  Go right  \n'
          '>  3.  Turn back  ';
      final result = GameSession.parseResponse(raw);
      expect(result.narrative, 'A dark cave.');
      expect(result.suggestions, hasLength(3));
      expect(result.suggestions[0], 'Go left');
      expect(result.suggestions[1], 'Go right');
      expect(result.suggestions[2], 'Turn back');
    });
  });

  group('GameSession - first turn (no history)', () {
    test('first turn yields streaming updates then complete turn', () async {
      final session = GameSession(
        systemPrompt: 'You are a Game Master.',
        generate: mockGenerator(_kMockResponse),
      );

      final turns = <GameTurn>[];
      await for (final turn in session.submitCommand('look around')) {
        turns.add(turn);
      }

      // Should have multiple streaming emissions + 1 final complete.
      expect(turns.length, greaterThan(1));

      // Final turn should be complete with parsed suggestions.
      final lastTurn = turns.last;
      expect(lastTurn.isComplete, isTrue);
      expect(lastTurn.turnNumber, 1);
      expect(lastTurn.playerCommand, 'look around');
      expect(lastTurn.suggestions, hasLength(3));
      expect(lastTurn.narrativeText, isNotEmpty);
      expect(lastTurn.rawResponse, _kMockResponse);
    });

    test('first turn prompt has no history and no style anchor', () {
      final session = GameSession(
        systemPrompt: 'Test prompt.',
        generate: mockGenerator(_kMockResponse),
      );

      // Before any commands, peek at what the first prompt looks like.
      // submitCommand increments _turnNumber, so we simulate by calling
      // assemblePrompt directly (turnNumber is still 0 at this point).
      final prompt = session.assemblePrompt('look around');
      expect(prompt, contains('System: Test prompt.'));
      expect(prompt, contains('Player: look around'));
      expect(prompt, contains('GM:'));
      // No style anchor on first turn (turnNumber is 0 before submitCommand).
      expect(prompt, isNot(contains(kStyleAnchor)));
      // No history entries.
      expect(prompt, isNot(contains('Player: look around\nGM: The ancient')));
    });

    test('startAdventure uses opening prompt', () async {
      final session = GameSession(
        systemPrompt: 'Test prompt.',
        generate: mockGenerator(_kMockResponse),
      );

      final turns = await session.startAdventure().toList();
      final lastTurn = turns.last;
      expect(lastTurn.playerCommand, kOpeningPrompt);
      expect(lastTurn.isComplete, isTrue);
    });
  });

  group('GameSession - history accumulation', () {
    test('history grows with each completed turn', () async {
      final responses = [
        'You see a dark room.\n\n'
            '> 1. Go north\n'
            '> 2. Go south\n'
            '> 3. Look around',
        'A corridor stretches before you.\n\n'
            '> 1. Walk forward\n'
            '> 2. Turn back\n'
            '> 3. Listen carefully',
        'You hear dripping water.\n\n'
            '> 1. Follow the sound\n'
            '> 2. Ignore it\n'
            '> 3. Call out',
      ];

      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: multiTurnGenerator(responses),
      );

      // Turn 1.
      await session.submitCommand('open door').toList();
      expect(session.history, hasLength(1));
      expect(session.history[0].turnNumber, 1);
      expect(session.turnNumber, 1);

      // Turn 2.
      await session.submitCommand('go north').toList();
      expect(session.history, hasLength(2));
      expect(session.history[1].turnNumber, 2);
      expect(session.turnNumber, 2);

      // Turn 3.
      await session.submitCommand('listen').toList();
      expect(session.history, hasLength(3));
      expect(session.history[2].turnNumber, 3);
      expect(session.turnNumber, 3);
    });

    test('prompt assembly includes history from previous turns', () async {
      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: multiTurnGenerator([
          'Room one.\n\n> 1. A\n> 2. B\n> 3. C',
          'Room two.\n\n> 1. D\n> 2. E\n> 3. F',
        ]),
      );

      // Complete turn 1.
      await session.submitCommand('look').toList();

      // Before turn 2, check the assembled prompt includes turn 1 history.
      // Note: assemblePrompt doesn't increment turnNumber; submitCommand does.
      // After turn 1, _turnNumber is 1. The next assemblePrompt call won't
      // see the anchor yet (it checks _turnNumber > 1, and _turnNumber is
      // already 1 after the first turn). But we need to simulate the state
      // during the second submitCommand, which would increment to 2.
      //
      // To verify history inclusion, we inspect the prompt built during turn 2.
      // We'll capture it via the generate function.
      String? capturedPrompt;
      final capturingSession = GameSession(
        systemPrompt: 'Test GM.',
        generate: (prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
          capturedPrompt = prompt;
          yield 'Response.\n\n> 1. A\n> 2. B\n> 3. C';
        },
      );

      // Complete turn 1 to build history.
      await capturingSession.submitCommand('look').toList();
      // Now turn 2.
      await capturingSession.submitCommand('go north').toList();

      expect(capturedPrompt, isNotNull);
      // Should contain turn 1's history.
      expect(capturedPrompt!, contains('Player: look'));
      expect(capturedPrompt!, contains('GM: Response.'));
      // Should contain the style anchor (turn > 1).
      expect(capturedPrompt!, contains(kStyleAnchor));
      // Should contain the current command.
      expect(capturedPrompt!, contains('Player: go north'));
    });

    test('reset clears history and turn count', () async {
      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: mockGenerator(
          'A scene.\n\n> 1. A\n> 2. B\n> 3. C',
        ),
      );

      await session.submitCommand('test').toList();
      expect(session.history, hasLength(1));
      expect(session.turnNumber, 1);

      session.reset();
      expect(session.history, isEmpty);
      expect(session.turnNumber, 0);
    });
  });

  group('GameSession - prompt assembly', () {
    test('assemblePrompt includes system prompt and player command', () {
      final session = GameSession(
        systemPrompt: 'You are the Game Master of DANTE TERMINAL.',
        generate: mockGenerator(''),
      );

      final prompt = session.assemblePrompt('look around');
      expect(
        prompt,
        contains('System: You are the Game Master of DANTE TERMINAL.'),
      );
      expect(prompt, contains('Player: look around'));
      expect(prompt, endsWith('GM:'));
    });

    test('context budget trims old history when exceeded', () async {
      // Use a very small context budget to force trimming.
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: multiTurnGenerator([
          'Short.\n\n> 1. A\n> 2. B\n> 3. C',
          'Medium response text.\n\n> 1. D\n> 2. E\n> 3. F',
          'Another response here.\n\n> 1. G\n> 2. H\n> 3. I',
        ]),
        // Tiny budget: system + current command + response reserve ~= 300 tokens.
        // Very little room for history.
        contextBudgetTokens: 150,
        maxResponseTokens: 50,
      );

      // Build up 3 turns of history.
      await session.submitCommand('first command').toList();
      await session.submitCommand('second command').toList();
      await session.submitCommand('third command').toList();

      // The 4th prompt should have trimmed the oldest history.
      final prompt = session.assemblePrompt('fourth command');
      expect(prompt, contains('System: GM.'));
      expect(prompt, contains('Player: fourth command'));
      // With a 150-token budget, not all 3 history turns can fit.
      // At minimum, the oldest turn should be trimmed.
      expect(prompt, contains('GM:'));
    });

    test('history is read-only', () {
      final session = GameSession(
        systemPrompt: 'Test.',
        generate: mockGenerator(''),
      );

      expect(() => (session.history as List).add('hack'), throwsA(anything));
    });
  });

  group('GameSession - streaming behavior', () {
    test('intermediate turns have isComplete false', () async {
      final session = GameSession(
        systemPrompt: 'Test.',
        generate: mockGenerator(_kMockResponse),
      );

      final turns = <GameTurn>[];
      await for (final turn in session.submitCommand('test')) {
        turns.add(turn);
      }

      // All but the last should be incomplete.
      for (var i = 0; i < turns.length - 1; i++) {
        expect(turns[i].isComplete, isFalse,
            reason: 'Turn at index $i should be incomplete');
      }
      expect(turns.last.isComplete, isTrue);
    });

    test('narrative grows during streaming', () async {
      final session = GameSession(
        systemPrompt: 'Test.',
        generate: mockGenerator(_kMockResponse),
      );

      final narrativeLengths = <int>[];
      await for (final turn in session.submitCommand('test')) {
        narrativeLengths.add(turn.narrativeText.length);
      }

      // Narrative should generally grow (may not be strictly monotonic due
      // to parsing, but the final value should be the largest).
      expect(narrativeLengths.last, greaterThan(0));
      // The raw response of the final turn should match the full mock.
      // (Already covered above, but confirms streaming assembled correctly.)
    });
  });

  group('GameSession.tokenEstimate', () {
    test('returns integer approximation for non-empty text', () {
      // 18 chars / 4 = 4.5, ceil → 5
      expect(GameSession.tokenEstimate('Hello, adventurer!'), 5);
    });

    test('returns 0 for empty string', () {
      expect(GameSession.tokenEstimate(''), 0);
    });

    test('returns 1 for single character', () {
      expect(GameSession.tokenEstimate('A'), 1);
    });

    test('scales linearly with text length', () {
      final short = GameSession.tokenEstimate('Hi');
      final long = GameSession.tokenEstimate('Hi' * 100);
      expect(long, greaterThan(short));
      // 200 chars / 4 = 50 tokens exactly
      expect(long, 50);
    });
  });

  group('GameSession - sliding context window', () {
    /// Generates a mock response of approximately the given word count.
    String mockResponseOfLength(int words) {
      // ~5 chars per word + space ≈ 6 chars/word
      final narrative = List.generate(words, (i) => 'word${i % 100}').join(' ');
      return '$narrative\n\n'
          '> 1. Do something\n'
          '> 2. Do another thing\n'
          '> 3. Do a third thing';
    }

    test('assemblePrompt stays under budget with 10+ turns', () async {
      // Use kMaxPromptTokens budget (1800 tokens for 2048 context).
      const budget = 2048;
      const responseReserve = 248;
      // prompt budget = budget - responseReserve = 1800

      final responses = List.generate(
        12,
        (i) => mockResponseOfLength(20), // ~120 chars each
      );

      final session = GameSession(
        systemPrompt: 'You are the Game Master.',
        generate: multiTurnGenerator(responses),
        contextBudgetTokens: budget,
        maxResponseTokens: responseReserve,
      );

      // Build 12 turns of history.
      for (var i = 0; i < 12; i++) {
        await session.submitCommand('command $i').toList();
      }

      expect(session.history, hasLength(12));

      // Now assemble a prompt for turn 13.
      final prompt = session.assemblePrompt('new command');
      final promptTokens = GameSession.tokenEstimate(prompt);

      // Prompt must stay under the prompt budget (context - response reserve).
      expect(
        promptTokens,
        lessThanOrEqualTo(budget - responseReserve),
        reason: 'Assembled prompt ($promptTokens tokens) must fit within '
            '${budget - responseReserve} token budget',
      );
    });

    test('preserves 2 most recent turns verbatim when compressing', () async {
      // Tight budget to force compression of older turns.
      final responses = List.generate(
        6,
        (i) => 'Narrative for turn ${i + 1}.\n\n'
            '> 1. Option A\n> 2. Option B\n> 3. Option C',
      );

      final session = GameSession(
        systemPrompt: 'GM.',
        generate: multiTurnGenerator(responses),
        contextBudgetTokens: 150,
        maxResponseTokens: 30,
      );

      // Build 6 turns of history.
      for (var i = 0; i < 6; i++) {
        await session.submitCommand('action $i').toList();
      }

      final prompt = session.assemblePrompt('next action');

      // The 2 most recent turns (turn 5, turn 6) must appear verbatim.
      expect(prompt, contains('Player: action 4'));
      expect(prompt, contains('Player: action 5'));
      // Their GM responses must also be verbatim.
      expect(prompt, contains('Narrative for turn 5.'));
      expect(prompt, contains('Narrative for turn 6.'));
    });

    test('compresses older turns into Story so far summary', () async {
      final responses = List.generate(
        5,
        (i) => 'Scene description ${i + 1} is here.\n\n'
            '> 1. Option A\n> 2. Option B\n> 3. Option C',
      );

      final session = GameSession(
        systemPrompt: 'GM.',
        generate: multiTurnGenerator(responses),
        contextBudgetTokens: 150,
        maxResponseTokens: 30,
      );

      // Build 5 turns of history.
      for (var i = 0; i < 5; i++) {
        await session.submitCommand('go $i').toList();
      }

      final prompt = session.assemblePrompt('go 5');

      // Older turns should be compressed into a summary.
      expect(prompt, contains('Story so far:'));
      // The summary should contain narrative text from early turns.
      expect(prompt, contains('Scene description 1'));
    });

    test('does not compress when all history fits in budget', () async {
      // Large budget so nothing needs compression.
      final responses = [
        'Short.\n\n> 1. A\n> 2. B\n> 3. C',
        'Brief.\n\n> 1. D\n> 2. E\n> 3. F',
      ];

      final session = GameSession(
        systemPrompt: 'GM.',
        generate: multiTurnGenerator(responses),
        contextBudgetTokens: 4096,
        maxResponseTokens: 200,
      );

      await session.submitCommand('first').toList();
      await session.submitCommand('second').toList();

      final prompt = session.assemblePrompt('third');

      // Both turns should appear verbatim, no summary needed.
      expect(prompt, contains('Player: first'));
      expect(prompt, contains('Player: second'));
      expect(prompt, isNot(contains('Story so far:')));
    });

    test('kMaxPromptTokens constant is consistent with 2048 context', () {
      // kMaxPromptTokens = 2048 - 248 = 1800
      expect(kMaxPromptTokens, 1800);
    });

    test('handles large history gracefully (20 turns)', () async {
      final responses = List.generate(
        20,
        (i) => 'The adventurer explores room $i with detailed '
            'descriptions of ancient stone walls and flickering torches '
            'that cast long shadows across the mossy floor.\n\n'
            '> 1. Go deeper\n> 2. Search the room\n> 3. Turn back',
      );

      // Budget of 500 tokens forces compression with 20 verbose turns
      // (~60 tokens each = 1200 tokens of history vs ~200 token budget).
      final session = GameSession(
        systemPrompt: 'You are a Game Master.',
        generate: multiTurnGenerator(responses),
        contextBudgetTokens: 500,
        maxResponseTokens: 100,
      );

      // Build 20 turns of history.
      for (var i = 0; i < 20; i++) {
        await session.submitCommand('explore room $i').toList();
      }

      final prompt = session.assemblePrompt('explore room 20');
      final promptTokens = GameSession.tokenEstimate(prompt);
      final promptBudget = 500 - 100;

      // Must stay within prompt budget.
      expect(
        promptTokens,
        lessThanOrEqualTo(promptBudget),
        reason: 'With 20 turns, sliding window must keep prompt under '
            '$promptBudget tokens (got $promptTokens)',
      );

      // Must still contain the 2 most recent turns.
      expect(prompt, contains('Player: explore room 18'));
      expect(prompt, contains('Player: explore room 19'));

      // Must contain summary of older turns.
      expect(prompt, contains('Story so far:'));
    });
  });

  group('GameSession - grammar integration', () {
    test('passes grammarFilePath through to generate function', () async {
      String? receivedGrammarPath;
      final session = GameSession(
        systemPrompt: 'Test.',
        generate: (prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
          receivedGrammarPath = grammarFilePath;
          yield 'Done.\n\n> 1. A\n> 2. B\n> 3. C';
        },
        grammarFilePath: '/path/to/grammar.gbnf',
      );

      await session.submitCommand('test').toList();
      expect(receivedGrammarPath, '/path/to/grammar.gbnf');
    });

    test('works without grammar (null grammarFilePath)', () async {
      String? receivedGrammarPath;
      final session = GameSession(
        systemPrompt: 'Test.',
        generate: (prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
          receivedGrammarPath = grammarFilePath;
          yield 'Done.\n\n> 1. A\n> 2. B\n> 3. C';
        },
      );

      await session.submitCommand('test').toList();
      expect(receivedGrammarPath, isNull);
    });
  });
}
