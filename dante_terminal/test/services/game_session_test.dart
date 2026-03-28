import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/models/adventure_data.dart';
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
  // Area 3b: Duplicate action stripping (BL-274 / BL-277)
  // =========================================================================
  group('Duplicate action stripping', () {
    test('strips numbered actions from narrative when suggestions are parsed',
        () {
      // Model duplicated actions in both narrative and suggestion block.
      const raw = 'The cavern opens into a vast underground lake.\n'
          '1. Swim across the lake\n'
          '2. Search the shoreline\n'
          '3. Call out into the darkness\n\n'
          '> 1. Swim across the lake\n'
          '> 2. Search the shoreline\n'
          '> 3. Call out into the darkness';

      final result = GameSession.parseResponse(raw);

      // Narrative should have duplicates stripped.
      expect(result.narrative,
          'The cavern opens into a vast underground lake.');
      // Suggestions should be parsed normally.
      expect(result.suggestions, hasLength(3));
      expect(result.suggestions[0], 'Swim across the lake');
      expect(result.suggestions[1], 'Search the shoreline');
      expect(result.suggestions[2], 'Call out into the darkness');
    });

    test('leaves narrative unchanged when no duplicate actions present', () {
      const raw = 'The ancient door groans open, revealing a vast '
          'underground library. Dust motes dance in pale glow.\n\n'
          '> 1. Explore the nearest bookshelf\n'
          '> 2. Follow the moss-lit corridor deeper\n'
          '> 3. Examine the inscriptions on the door frame';

      final result = GameSession.parseResponse(raw);

      expect(result.narrative,
          'The ancient door groans open, revealing a vast '
          'underground library. Dust motes dance in pale glow.');
      expect(result.suggestions, hasLength(3));
    });

    test('preserves numbered prose content that is not an action list', () {
      // Numbered items that are NOT duplicated actions — e.g. a clue list.
      // When no suggestions are parsed, stripping should NOT apply.
      const raw = 'The scroll reads:\n'
          '1. The key lies beneath the third stone\n'
          '2. Beware the guardian of the gate\n'
          '3. Only the worthy may pass';

      final result = GameSession.parseResponse(raw);

      // No suggestions parsed (no suggestion block), so narrative is untouched.
      expect(result.narrative, raw.trim());
      expect(result.suggestions, isEmpty);
    });

    test('handles parenthetical numbered formats like 1) 2) 3)', () {
      const raw = 'A fork in the tunnel.\n'
          '1) Take the left passage\n'
          '2) Take the right passage\n'
          '3) Go back the way you came\n\n'
          '> 1. Take the left passage\n'
          '> 2. Take the right passage\n'
          '> 3. Go back the way you came';

      final result = GameSession.parseResponse(raw);

      expect(result.narrative, 'A fork in the tunnel.');
      expect(result.suggestions, hasLength(3));
      expect(result.suggestions[0], 'Take the left passage');
    });

    test('preserves all-numbered narrative via safety fallback', () {
      // When EVERY line of the narrative is numbered, it is likely intentional
      // prose (e.g. a riddle or numbered clue list). The safety fallback
      // should preserve the original narrative even when suggestions exist.
      const raw = '1. The first seal is broken\n'
          '2. The second seal crumbles\n'
          '3. The third seal holds fast\n\n'
          '> 1. Touch the third seal\n'
          '> 2. Read the inscription\n'
          '> 3. Step back';

      final result = GameSession.parseResponse(raw);

      // Safety fallback: all lines matched the pattern, so narrative preserved.
      expect(result.narrative,
          '1. The first seal is broken\n'
          '2. The second seal crumbles\n'
          '3. The third seal holds fast');
      expect(result.suggestions, hasLength(3));
      expect(result.suggestions[0], 'Touch the third seal');
    });

    test('strips actions with leading whitespace', () {
      const raw = 'The corridor splits ahead.\n'
          '  1. Go left\n'
          '  2. Go right\n'
          '  3. Wait here\n\n'
          '> 1. Go left\n'
          '> 2. Go right\n'
          '> 3. Wait here';

      final result = GameSession.parseResponse(raw);

      expect(result.narrative, 'The corridor splits ahead.');
      expect(result.suggestions, hasLength(3));
    });

    test('does not strip during streaming (no suggestions yet)', () {
      // During streaming, no double-newline yet — narrative returned as-is.
      const partial = 'The cavern opens.\n1. Swim across the lake\n2. Search';
      final result = GameSession.parseResponse(partial);

      expect(result.narrative, partial);
      expect(result.suggestions, isEmpty);
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

  // =========================================================================
  // Area 5: Location context injection (BL-162)
  // =========================================================================
  group('Location context injection', () {
    /// Helper: create a Location for testing.
    Location makeLocation({
      String id = 'antechamber',
      String name = 'The Antechamber',
      String description = 'Collapsed stairway, rubble blocks exit. '
          'Floor mosaic: open book in chains. Water seeps through debris.',
      List<Exit>? exits,
      List<String> itemIds = const [],
      List<String> npcIds = const [],
    }) {
      return Location(
        id: id,
        name: name,
        description: description,
        keywords: const ['test'],
        exits: exits ??
            [
              const Exit(direction: 'north', targetLocationId: 'main_hall'),
            ],
        itemIds: itemIds,
        npcIds: npcIds,
      );
    }

    test('setLocation updates currentLocation state', () {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGen(''),
      );

      expect(session.currentLocation, isNull);

      final loc = makeLocation();
      session.setLocation(loc);

      expect(session.currentLocation, same(loc));
    });

    test('assemblePrompt includes CURRENT LOCATION block when location is set',
        () {
      final session = GameSession(
        systemPrompt: 'You are the Game Master.',
        generate: _mockGen(''),
      );

      final loc = makeLocation();
      session.setLocation(loc);

      final prompt = session.assemblePrompt('look around');

      // Location context block is present.
      expect(prompt, contains('CURRENT LOCATION: The Antechamber.'));
      // Description content is present.
      expect(prompt, contains('Collapsed stairway'));
      // Exits are listed.
      expect(prompt, contains('Exits: north.'));
      // Block appears between system prompt and player command.
      final sysIdx = prompt.indexOf('System:');
      final locIdx = prompt.indexOf('CURRENT LOCATION:');
      final playerIdx = prompt.indexOf('Player:');
      expect(locIdx, greaterThan(sysIdx));
      expect(locIdx, lessThan(playerIdx));
    });

    test('assemblePrompt omits location block when no location is set', () {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGen(''),
      );

      final prompt = session.assemblePrompt('look around');

      expect(prompt, isNot(contains('CURRENT LOCATION:')));
    });

    test('location context updates when setLocation called with different location',
        () {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGen(''),
      );

      // Set first location.
      session.setLocation(makeLocation(
        id: 'antechamber',
        name: 'The Antechamber',
        description: 'Cold stone room.',
      ));

      final prompt1 = session.assemblePrompt('look');
      expect(prompt1, contains('CURRENT LOCATION: The Antechamber.'));
      expect(prompt1, contains('Cold stone room.'));

      // Change location.
      session.setLocation(makeLocation(
        id: 'main_hall',
        name: 'The Main Hall',
        description: 'Vaulted corridor with fungus.',
        exits: [
          const Exit(direction: 'south', targetLocationId: 'antechamber'),
          const Exit(direction: 'east', targetLocationId: 'east_wing'),
        ],
      ));

      final prompt2 = session.assemblePrompt('look');
      expect(prompt2, contains('CURRENT LOCATION: The Main Hall.'));
      expect(prompt2, contains('Vaulted corridor with fungus.'));
      expect(prompt2, contains('Exits: south, east.'));
      // Old location no longer present.
      expect(prompt2, isNot(contains('The Antechamber')));
    });

    test('location context includes items and NPCs when present', () {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGen(''),
      );

      session.setLocation(makeLocation(
        name: 'The Circulation Desk',
        description: 'Hexagonal chamber.',
        itemIds: ['brass_key', 'oil_lamp'],
        npcIds: ['the_cataloger'],
      ));

      final prompt = session.assemblePrompt('look');
      expect(prompt, contains('Items: brass_key, oil_lamp.'));
      expect(prompt, contains('NPCs: the_cataloger.'));
    });

    test('buildLocationContext fits within 80 tokens for compact locations', () {
      // A typical Sunken Archive location with moderate content.
      final loc = makeLocation(
        name: 'The Antechamber',
        description: 'Collapsed stairway, rubble blocks exit. '
            'Floor mosaic: open book in chains. Water seeps through debris.',
        exits: [
          const Exit(direction: 'north', targetLocationId: 'main_hall'),
          const Exit(
            direction: 'up',
            targetLocationId: 'surface',
            blocked: true,
          ),
        ],
      );

      final context = GameSession.buildLocationContext(loc);
      final tokens = GameSession.tokenEstimate(context);

      expect(
        tokens,
        lessThanOrEqualTo(kLocationContextMaxTokens),
        reason: 'Location context ($tokens tokens) must fit within '
            '$kLocationContextMaxTokens token budget',
      );
    });

    test('buildLocationContext truncates long descriptions to fit 80 tokens',
        () {
      // Deliberately long description that would exceed 80 tokens.
      final loc = makeLocation(
        name: 'The Restricted Section',
        description:
            'Carved from bedrock. Books chained to shelves, spines inward. '
            'Air thick and warm. Darkness unnaturally dense. Low hum from '
            'below. One scorched shelf — Codex Umbra original location. '
            'The Warden manifests near spiral staircase.',
        exits: [
          const Exit(direction: 'south', targetLocationId: 'circulation_desk'),
          const Exit(
            direction: 'down',
            targetLocationId: 'vault_of_the_codex',
            blocked: true,
          ),
        ],
        npcIds: ['the_warden'],
      );

      final context = GameSession.buildLocationContext(loc);
      final tokens = GameSession.tokenEstimate(context);

      expect(
        tokens,
        lessThanOrEqualTo(kLocationContextMaxTokens),
        reason: 'Truncated context ($tokens tokens) must fit within '
            '$kLocationContextMaxTokens token budget',
      );
      // Still starts with the location header.
      expect(context, startsWith('CURRENT LOCATION: The Restricted Section.'));
      // Still has structured data.
      expect(context, contains('Exits:'));
    });

    test('all sunken_archive locations produce ≤80 token context blocks', () {
      // Reproduce all 9 Sunken Archive locations from the adventure JSON
      // to verify the 80-token budget holds for every room.
      final locations = <Location>[
        const Location(
          id: 'antechamber',
          name: 'The Antechamber',
          description:
              'Collapsed stairway, rubble blocks exit upward. Floor mosaic: '
              'open book in chains. Water seeps through debris. One corridor '
              'leads north to Main Hall. The Codex Umbra can unseal the '
              'stairway exit.',
          keywords: ['antechamber'],
          exits: [Exit(direction: 'north', targetLocationId: 'main_hall'),
                  Exit(direction: 'up', targetLocationId: 'surface', blocked: true)],
        ),
        const Location(
          id: 'east_wing',
          name: 'The East Wing',
          description:
              'Ankle-deep dark water. Leaning bookshelves, waterlogged books. '
              'Collapsed reading desk with metallic glint underneath. Water '
              'flows north. One readable shelf mentions the Cipher for '
              'Restricted texts. Exits: west to Main Hall, north to Flooded Passage.',
          keywords: ['east wing'],
          exits: [Exit(direction: 'west', targetLocationId: 'main_hall'),
                  Exit(direction: 'north', targetLocationId: 'flooded_passage')],
          itemIds: ['brass_key'],
        ),
        const Location(
          id: 'main_hall',
          name: 'The Main Hall',
          description:
              'Central vaulted corridor. Bioluminescent fungus on ceiling '
              'casts blue-green glow, reacts to loud sounds. Floor mosaic '
              'shows robed figures carrying books into a spiral. Water '
              'stream flows south. Exits: south, east, west, north.',
          keywords: ['main hall'],
          exits: [Exit(direction: 'south', targetLocationId: 'antechamber'),
                  Exit(direction: 'east', targetLocationId: 'east_wing'),
                  Exit(direction: 'west', targetLocationId: 'west_wing'),
                  Exit(direction: 'north', targetLocationId: 'circulation_desk')],
        ),
        const Location(
          id: 'west_wing',
          name: 'The West Wing',
          description:
              'Bone-dry, warm air. Glass display cases, most shattered. '
              'One intact case with wax seal holds the Archivist\'s Journal. '
              'Cabinet drawer contains glass vial of solvent. Ceiling timbers '
              'creak. Exit: east to Main Hall.',
          keywords: ['west wing'],
          exits: [Exit(direction: 'east', targetLocationId: 'main_hall')],
          itemIds: ['archivists_journal', 'glass_vial_solvent'],
        ),
        const Location(
          id: 'flooded_passage',
          name: 'The Flooded Passage',
          description:
              'Waist-deep black water, narrow walls, low ceiling. Sound '
              'distorts. Waterproof satchel on peg above water. Submerged '
              'shelf holds sealed lamp oil. Visible high-water mark above '
              'current level. Exits: south to East Wing, west to Circulation Desk.',
          keywords: ['flooded passage'],
          exits: [Exit(direction: 'south', targetLocationId: 'east_wing'),
                  Exit(direction: 'west', targetLocationId: 'circulation_desk')],
          itemIds: ['waterproof_satchel'],
        ),
        const Location(
          id: 'circulation_desk',
          name: 'The Circulation Desk',
          description:
              'Hexagonal chamber with massive stone desk. Chained leather '
              'ledger. Polished brass bell summons the Cataloger. Iron gate '
              'north to Restricted Section needs brass key. Exits: south, '
              'east, west, north (locked).',
          keywords: ['circulation desk'],
          exits: [Exit(direction: 'south', targetLocationId: 'main_hall'),
                  Exit(direction: 'east', targetLocationId: 'flooded_passage'),
                  Exit(direction: 'west', targetLocationId: 'reading_room'),
                  Exit(direction: 'north', targetLocationId: 'restricted_section', blocked: true)],
          npcIds: ['the_cataloger'],
        ),
        const Location(
          id: 'reading_room',
          name: 'The Reading Room',
          description:
              'Large domed chamber. Star map mural — constellations subtly '
              'wrong. Collapsed tables and chairs. Cold stone fire pit with '
              'oversized scorch marks forming Archive seal. Cipher Wheel '
              'hidden in hollowed book near fire pit. Exits: east, south.',
          keywords: ['reading room'],
          exits: [Exit(direction: 'east', targetLocationId: 'circulation_desk'),
                  Exit(direction: 'south', targetLocationId: 'west_wing')],
          itemIds: ['cipher_wheel'],
          npcIds: ['maren'],
        ),
        const Location(
          id: 'restricted_section',
          name: 'The Restricted Section',
          description:
              'Carved from bedrock. Books chained to shelves, spines inward. '
              'Air thick and warm. Darkness unnaturally dense. Low hum from '
              'below. One scorched shelf — Codex Umbra\'s original location. '
              'The Warden manifests near spiral staircase. Exits: south, '
              'down (after Warden).',
          keywords: ['restricted section'],
          exits: [Exit(direction: 'south', targetLocationId: 'circulation_desk'),
                  Exit(direction: 'down', targetLocationId: 'vault_of_the_codex', blocked: true)],
          npcIds: ['the_warden'],
        ),
        const Location(
          id: 'vault_of_the_codex',
          name: 'The Vault of the Codex',
          description:
              'Circular obsidian chamber. Stone pedestal holds Codex Umbra — '
              'black leather book absorbing light. Five-disc combination lock '
              'with star-map symbols. Taking Codex triggers flooding. '
              'Pedestal engraving matches Antechamber seal. Exit: up to '
              'Restricted Section.',
          keywords: ['vault'],
          exits: [Exit(direction: 'up', targetLocationId: 'restricted_section')],
        ),
      ];

      for (final loc in locations) {
        final context = GameSession.buildLocationContext(loc);
        final tokens = GameSession.tokenEstimate(context);

        expect(
          tokens,
          lessThanOrEqualTo(kLocationContextMaxTokens),
          reason: '${loc.name} context ($tokens tokens, ${context.length} chars) '
              'exceeds $kLocationContextMaxTokens token budget.\n'
              'Content: $context',
        );
      }
    });
  });
}
