import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/game_session.dart';

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/// A mock [GenerateFunction] that yields [response] one character at a time,
/// simulating token-level streaming from the inference engine without needing
/// a real GGUF model.
GenerateFunction _mockGen(String response) {
  return (String prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
    for (final char in response.split('')) {
      yield char;
    }
  };
}

/// A mock [GenerateFunction] that returns a different response per call,
/// cycling through [responses].
GenerateFunction _multiGen(List<String> responses) {
  var idx = 0;
  return (String prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
    final r = responses[idx % responses.length];
    idx++;
    for (final char in r.split('')) {
      yield char;
    }
  };
}

/// Builds a well-formed GBNF response with [narrative] and 3 suggestions.
String _gbnfResponse(String narrative, List<String> suggestions) {
  assert(suggestions.length == 3);
  return '$narrative\n\n'
      '> 1. ${suggestions[0]}\n'
      '> 2. ${suggestions[1]}\n'
      '> 3. ${suggestions[2]}';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Area 1: Prompt assembly — system-prompt + history + command structure
  // =========================================================================
  group('Prompt assembly', () {
    test('first-turn prompt has System, Player, GM markers and no style anchor',
        () {
      final session = GameSession(
        systemPrompt: 'You are the Game Master of a dark dungeon.',
        generate: _mockGen(''),
      );

      final prompt = session.assemblePrompt('look around');

      // System prompt appears first.
      expect(prompt, startsWith('System: You are the Game Master'));
      // Player command and GM generation marker present.
      expect(prompt, contains('Player: look around'));
      expect(prompt, endsWith('GM:'));
      // No style anchor on the very first turn (turnNumber is 0).
      expect(prompt, isNot(contains(kStyleAnchor)));
      // No history entries.
      expect(prompt, isNot(contains('Story so far:')));
    });

    test('second-turn prompt includes turn-1 history and style anchor', () async {
      final turn1Response = _gbnfResponse(
        'You awaken on cold stone.',
        ['Stand up', 'Look around', 'Call for help'],
      );

      String? capturedPrompt;
      final session = GameSession(
        systemPrompt: 'GM prompt.',
        generate: (prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
          capturedPrompt = prompt;
          for (final c in turn1Response.split('')) {
            yield c;
          }
        },
      );

      // Complete turn 1 to populate history.
      await session.submitCommand('begin').toList();
      // Now submit turn 2 — the generator captures the prompt.
      await session.submitCommand('stand up').toList();

      expect(capturedPrompt, isNotNull);
      // Turn 1 history present as Player/GM pair.
      expect(capturedPrompt!, contains('Player: begin'));
      expect(capturedPrompt!, contains('GM: $turn1Response'));
      // Style anchor injected after first turn.
      expect(capturedPrompt!, contains(kStyleAnchor));
      // Current command present.
      expect(capturedPrompt!, contains('Player: stand up'));
      expect(capturedPrompt!, endsWith('GM:'));
    });

    test('prompt sections are separated by double newlines', () {
      final session = GameSession(
        systemPrompt: 'Test.',
        generate: _mockGen(''),
      );

      final prompt = session.assemblePrompt('go north');
      final sections = prompt.split('\n\n');

      // At minimum: System section + Player/GM section.
      expect(sections.length, greaterThanOrEqualTo(2));
      expect(sections.first, startsWith('System:'));
      expect(sections.last, contains('Player: go north'));
    });
  });

  // =========================================================================
  // Area 2: Sliding context window — compression + recent-turn preservation
  // =========================================================================
  group('Sliding context window', () {
    test(
        'compresses older turns into "Story so far" while preserving 2 most '
        'recent turns verbatim', () async {
      // Each response is ~50-60 chars (~15 tokens). With 8 turns at ~15 tokens
      // each plus Player lines, history is ~300+ tokens. A 200-token budget
      // forces compression.
      final responses = List.generate(
        8,
        (i) => _gbnfResponse(
          'Scene $i unfolds before you.',
          ['Option A$i', 'Option B$i', 'Option C$i'],
        ),
      );

      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _multiGen(responses),
        contextBudgetTokens: 200,
        maxResponseTokens: 40,
      );

      for (var i = 0; i < 8; i++) {
        await session.submitCommand('action $i').toList();
      }

      final prompt = session.assemblePrompt('action 8');

      // The 2 most recent turns (turn 7 and turn 8) must appear verbatim.
      expect(prompt, contains('Player: action 6'));
      expect(prompt, contains('Player: action 7'));
      expect(prompt, contains('Scene 6 unfolds before you.'));
      expect(prompt, contains('Scene 7 unfolds before you.'));

      // Older turns should NOT appear as full Player/GM pairs.
      expect(prompt, isNot(contains('Player: action 0\nGM:')));

      // Compression summary must be present.
      expect(prompt, contains('Story so far:'));
    });

    test('prompt stays within token budget even with 15 verbose turns',
        () async {
      const budget = 4096;
      const responseReserve = 200;
      final verboseNarrative = 'The adventurer walks through an ancient hall '
          'decorated with tapestries depicting forgotten wars and heroes '
          'of ages past. Torches flicker along the stone walls.';

      final responses = List.generate(
        15,
        (i) => _gbnfResponse(
          '$verboseNarrative Room $i.',
          ['Go deeper', 'Search here', 'Turn back'],
        ),
      );

      final session = GameSession(
        systemPrompt: 'You are a Game Master running a dungeon adventure.',
        generate: _multiGen(responses),
        contextBudgetTokens: budget,
        maxResponseTokens: responseReserve,
      );

      for (var i = 0; i < 15; i++) {
        await session.submitCommand('explore room $i').toList();
      }

      final prompt = session.assemblePrompt('explore room 15');
      final tokens = GameSession.tokenEstimate(prompt);

      expect(
        tokens,
        lessThanOrEqualTo(budget - responseReserve),
        reason: 'Prompt ($tokens tokens) must fit within '
            '${budget - responseReserve} token prompt budget',
      );

      // 2 most recent turns still present.
      expect(prompt, contains('Player: explore room 13'));
      expect(prompt, contains('Player: explore room 14'));
    });

    test('no compression needed when history fits within budget', () async {
      final responses = [
        _gbnfResponse('Short.', ['A', 'B', 'C']),
        _gbnfResponse('Brief.', ['D', 'E', 'F']),
      ];

      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _multiGen(responses),
        contextBudgetTokens: 4096,
        maxResponseTokens: 200,
      );

      await session.submitCommand('first').toList();
      await session.submitCommand('second').toList();

      final prompt = session.assemblePrompt('third');

      // Both turns verbatim, no summary.
      expect(prompt, contains('Player: first'));
      expect(prompt, contains('Player: second'));
      expect(prompt, isNot(contains('Story so far:')));
    });
  });

  // =========================================================================
  // Area 3: GBNF-constrained response parsing
  // =========================================================================
  group('GBNF response parsing', () {
    test('extracts narrative and exactly 3 suggestions from well-formed response',
        () {
      const raw = 'The cavern echoes with dripping water. A faint glow '
          'emanates from a crack in the far wall.\n\n'
          '> 1. Investigate the glow\n'
          '> 2. Listen for other sounds\n'
          '> 3. Search the ground near your feet';

      final result = GameSession.parseResponse(raw);

      expect(result.narrative,
          'The cavern echoes with dripping water. A faint glow '
          'emanates from a crack in the far wall.');
      expect(result.suggestions, hasLength(3));
      expect(result.suggestions[0], 'Investigate the glow');
      expect(result.suggestions[1], 'Listen for other sounds');
      expect(result.suggestions[2], 'Search the ground near your feet');
    });

    test('returns empty suggestions during streaming (no double-newline yet)',
        () {
      const partial = 'The cavern echoes with dripping water. A faint glow';
      final result = GameSession.parseResponse(partial);

      expect(result.narrative, partial);
      expect(result.suggestions, isEmpty);
    });

    test('handles empty and whitespace-only input gracefully', () {
      expect(GameSession.parseResponse('').narrative, '');
      expect(GameSession.parseResponse('').suggestions, isEmpty);
      expect(GameSession.parseResponse('   \n\n   ').narrative, isEmpty);
    });

    test('end-to-end: submitCommand yields complete turn with 3 parsed suggestions',
        () async {
      final response = _gbnfResponse(
        'A dragon blocks the bridge.',
        ['Draw your sword', 'Attempt diplomacy', 'Retreat quietly'],
      );

      final session = GameSession(
        systemPrompt: 'Test.',
        generate: _mockGen(response),
      );

      final turns = await session.submitCommand('cross bridge').toList();
      final last = turns.last;

      expect(last.isComplete, isTrue);
      expect(last.narrativeText, 'A dragon blocks the bridge.');
      expect(last.suggestions, hasLength(3));
      expect(last.suggestions[0], 'Draw your sword');
      expect(last.suggestions[1], 'Attempt diplomacy');
      expect(last.suggestions[2], 'Retreat quietly');
      expect(last.rawResponse, response);
    });
  });

  // =========================================================================
  // Area 4: Save-state / restore round-trip with full fidelity
  // =========================================================================
  group('Save-restore round-trip', () {
    late Directory tempDir;
    late String savePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bl147_test_');
      savePath = '${tempDir.path}/dante_save.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'saveState → loadSaveData → restoreFromSaveData preserves turn count, '
        'player commands, narrative text, and suggestions', () async {
      // Build a 4-turn session with distinct content per turn.
      final responses = [
        _gbnfResponse('You awaken in darkness.', [
          'Stand up',
          'Feel around',
          'Call out',
        ]),
        _gbnfResponse('Your hand finds cold stone.', [
          'Push the stone',
          'Follow the wall',
          'Sit and wait',
        ]),
        _gbnfResponse('A door creaks open ahead.', [
          'Step through',
          'Peek inside',
          'Knock first',
        ]),
        _gbnfResponse('Torchlight reveals a vast hall.', [
          'Explore the hall',
          'Grab a torch',
          'Hide in shadows',
        ]),
      ];

      final original = GameSession(
        systemPrompt: 'Game Master.',
        generate: _multiGen(responses),
      );

      await original.submitCommand('wake up').toList();
      await original.submitCommand('feel around').toList();
      await original.submitCommand('go through door').toList();
      await original.submitCommand('look around').toList();

      // Save to disk.
      await original.saveState(savePath, adventureId: 'dungeon_run');

      // Load and restore into a fresh session.
      final saveData = await GameSession.loadSaveData(savePath);
      expect(saveData, isNotNull);
      expect(saveData!['adventureId'], 'dungeon_run');

      final restored = GameSession(
        systemPrompt: 'Game Master.',
        generate: _mockGen(''),
      );
      restored.restoreFromSaveData(saveData);

      // Turn count.
      expect(restored.turnNumber, original.turnNumber);
      expect(restored.turnNumber, 4);

      // History length.
      expect(restored.history.length, original.history.length);
      expect(restored.history.length, 4);

      // Per-turn field fidelity.
      for (var i = 0; i < original.history.length; i++) {
        final orig = original.history[i];
        final rest = restored.history[i];
        expect(rest.turnNumber, orig.turnNumber,
            reason: 'Turn ${i + 1} turnNumber mismatch');
        expect(rest.playerCommand, orig.playerCommand,
            reason: 'Turn ${i + 1} playerCommand mismatch');
        expect(rest.narrativeText, orig.narrativeText,
            reason: 'Turn ${i + 1} narrativeText mismatch');
        expect(rest.suggestions, orig.suggestions,
            reason: 'Turn ${i + 1} suggestions mismatch');
        expect(rest.rawResponse, orig.rawResponse,
            reason: 'Turn ${i + 1} rawResponse mismatch');
        expect(rest.isComplete, orig.isComplete,
            reason: 'Turn ${i + 1} isComplete mismatch');
      }
    });

    test('restored session can continue play with correct turn numbering',
        () async {
      // Build 2-turn session, save, restore, then play turn 3.
      final original = GameSession(
        systemPrompt: 'GM.',
        generate: _multiGen([
          _gbnfResponse('Room one.', ['A', 'B', 'C']),
          _gbnfResponse('Room two.', ['D', 'E', 'F']),
        ]),
      );

      await original.submitCommand('enter').toList();
      await original.submitCommand('go north').toList();
      await original.saveState(savePath, adventureId: 'test');

      final saveData = await GameSession.loadSaveData(savePath);
      final restored = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGen(
          _gbnfResponse('Room three.', ['G', 'H', 'I']),
        ),
      );
      restored.restoreFromSaveData(saveData!);

      // Play one more turn.
      final turns = await restored.submitCommand('go east').toList();
      final last = turns.last;

      expect(last.turnNumber, 3, reason: 'Continues from restored turn count');
      expect(last.isComplete, isTrue);
      expect(last.narrativeText, 'Room three.');
      expect(restored.history.length, 3);
    });

    test('save file is valid JSON with expected schema', () async {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGen(
          _gbnfResponse('A scene.', ['X', 'Y', 'Z']),
        ),
      );

      await session.submitCommand('test').toList();
      await session.saveState(savePath, adventureId: 'schema_check');

      final raw = File(savePath).readAsStringSync();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      // Top-level keys.
      expect(data.containsKey('adventureId'), isTrue);
      expect(data.containsKey('turnNumber'), isTrue);
      expect(data.containsKey('turns'), isTrue);
      expect(data.containsKey('savedAt'), isTrue);

      // Turn entry keys.
      final turn = (data['turns'] as List).first as Map<String, dynamic>;
      expect(turn.containsKey('turnNumber'), isTrue);
      expect(turn.containsKey('playerCommand'), isTrue);
      expect(turn.containsKey('narrativeText'), isTrue);
      expect(turn.containsKey('suggestions'), isTrue);
      expect(turn.containsKey('rawResponse'), isTrue);
      expect(turn.containsKey('isComplete'), isTrue);

      // savedAt is a parseable ISO 8601 timestamp.
      expect(() => DateTime.parse(data['savedAt'] as String), returnsNormally);
    });
  });
}
