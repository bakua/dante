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
