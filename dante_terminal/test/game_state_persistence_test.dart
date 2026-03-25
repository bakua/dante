import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/services/game_session.dart';

/// Creates a [GenerateFunction] that yields the response as individual
/// character tokens (simulating streaming from the inference engine).
GenerateFunction _mockGenerator(String response) {
  return (String prompt, {int maxTokens = 256, String? grammarFilePath}) async* {
    for (final char in response.split('')) {
      yield char;
    }
  };
}

/// Creates a [GenerateFunction] that returns different responses per turn.
GenerateFunction _multiTurnGenerator(List<String> responses) {
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
  late Directory tempDir;
  late String saveFilePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dante_test_');
    saveFilePath = '${tempDir.path}/dante_save.json';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('GameTurn serialization', () {
    test('toJson produces expected keys', () {
      const turn = GameTurn(
        turnNumber: 1,
        playerCommand: 'look around',
        narrativeText: 'A dark room.',
        suggestions: ['Go north', 'Go south', 'Look closer'],
        rawResponse: 'A dark room.\n\n> 1. Go north\n> 2. Go south\n> 3. Look closer',
        isComplete: true,
      );

      final json = turn.toJson();
      expect(json['turnNumber'], 1);
      expect(json['playerCommand'], 'look around');
      expect(json['narrativeText'], 'A dark room.');
      expect(json['suggestions'], ['Go north', 'Go south', 'Look closer']);
      expect(json['rawResponse'], contains('> 1. Go north'));
      expect(json['isComplete'], true);
    });

    test('fromJson reconstructs a GameTurn correctly', () {
      final json = {
        'turnNumber': 3,
        'playerCommand': 'open chest',
        'narrativeText': 'The chest creaks open.',
        'suggestions': ['Take the gem', 'Close it', 'Examine contents'],
        'rawResponse': 'The chest creaks open.\n\n> 1. Take the gem\n> 2. Close it\n> 3. Examine contents',
        'isComplete': true,
      };

      final turn = GameTurn.fromJson(json);
      expect(turn.turnNumber, 3);
      expect(turn.playerCommand, 'open chest');
      expect(turn.narrativeText, 'The chest creaks open.');
      expect(turn.suggestions, hasLength(3));
      expect(turn.suggestions[0], 'Take the gem');
      expect(turn.rawResponse, contains('> 1. Take the gem'));
      expect(turn.isComplete, true);
    });

    test('toJson → fromJson round-trips faithfully', () {
      const original = GameTurn(
        turnNumber: 5,
        playerCommand: 'cast spell',
        narrativeText: 'Lightning crackles from your fingers.',
        suggestions: ['Aim at door', 'Aim at wall', 'Stop casting'],
        rawResponse: 'Lightning crackles from your fingers.\n\n'
            '> 1. Aim at door\n> 2. Aim at wall\n> 3. Stop casting',
        isComplete: true,
      );

      final restored = GameTurn.fromJson(original.toJson());
      expect(restored.turnNumber, original.turnNumber);
      expect(restored.playerCommand, original.playerCommand);
      expect(restored.narrativeText, original.narrativeText);
      expect(restored.suggestions, original.suggestions);
      expect(restored.rawResponse, original.rawResponse);
      expect(restored.isComplete, original.isComplete);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'turnNumber': 1,
        'playerCommand': 'look',
        'narrativeText': 'You see nothing.',
        'suggestions': <dynamic>[],
      };

      final turn = GameTurn.fromJson(json);
      expect(turn.rawResponse, '');
      expect(turn.isComplete, true);
    });
  });

  group('GameSession.saveState', () {
    test('writes JSON file with adventure ID, turns, and turn count', () async {
      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: _mockGenerator(
          'A dark room.\n\n> 1. Go north\n> 2. Go south\n> 3. Look',
        ),
      );

      await session.submitCommand('look around').toList();
      await session.saveState(saveFilePath, adventureId: 'sunken_archive');

      final file = File(saveFilePath);
      expect(file.existsSync(), isTrue);

      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(data['adventureId'], 'sunken_archive');
      expect(data['turnNumber'], 1);
      expect(data['turns'], isList);
      expect((data['turns'] as List).length, 1);
      expect(data['savedAt'], isNotNull);
    });

    test('saves multiple turns', () async {
      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: _multiTurnGenerator([
          'Room one.\n\n> 1. A\n> 2. B\n> 3. C',
          'Room two.\n\n> 1. D\n> 2. E\n> 3. F',
          'Room three.\n\n> 1. G\n> 2. H\n> 3. I',
        ]),
      );

      await session.submitCommand('first').toList();
      await session.submitCommand('second').toList();
      await session.submitCommand('third').toList();
      await session.saveState(saveFilePath, adventureId: 'test');

      final data = jsonDecode(File(saveFilePath).readAsStringSync())
          as Map<String, dynamic>;
      expect(data['turnNumber'], 3);
      expect((data['turns'] as List).length, 3);
    });

    test('creates parent directories if they do not exist', () async {
      final nestedPath = '${tempDir.path}/sub/dir/save.json';
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGenerator(
          'Scene.\n\n> 1. A\n> 2. B\n> 3. C',
        ),
      );

      await session.submitCommand('test').toList();
      await session.saveState(nestedPath, adventureId: 'test');
      expect(File(nestedPath).existsSync(), isTrue);
    });
  });

  group('GameSession.loadSaveData', () {
    test('returns null when file does not exist', () async {
      final result = await GameSession.loadSaveData(
        '${tempDir.path}/nonexistent.json',
      );
      expect(result, isNull);
    });

    test('returns parsed data when file exists', () async {
      final data = {
        'adventureId': 'sunken_archive',
        'turnNumber': 2,
        'turns': <dynamic>[],
      };
      File(saveFilePath).writeAsStringSync(jsonEncode(data));

      final loaded = await GameSession.loadSaveData(saveFilePath);
      expect(loaded, isNotNull);
      expect(loaded!['adventureId'], 'sunken_archive');
      expect(loaded['turnNumber'], 2);
    });

    test('returns null for corrupted file', () async {
      File(saveFilePath).writeAsStringSync('not valid json {{{');

      final result = await GameSession.loadSaveData(saveFilePath);
      expect(result, isNull);
    });
  });

  group('GameSession.restoreFromSaveData', () {
    test('restores turn history and turn counter', () {
      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: _mockGenerator(''),
      );

      final saveData = {
        'turnNumber': 3,
        'turns': [
          {
            'turnNumber': 1,
            'playerCommand': 'look',
            'narrativeText': 'A dark room.',
            'suggestions': ['Go north', 'Go south', 'Look closer'],
            'rawResponse': 'A dark room.\n\n> 1. Go north',
            'isComplete': true,
          },
          {
            'turnNumber': 2,
            'playerCommand': 'go north',
            'narrativeText': 'A corridor.',
            'suggestions': ['Walk', 'Run', 'Stop'],
            'rawResponse': 'A corridor.\n\n> 1. Walk',
            'isComplete': true,
          },
          {
            'turnNumber': 3,
            'playerCommand': 'walk',
            'narrativeText': 'You reach a door.',
            'suggestions': ['Open', 'Knock', 'Turn back'],
            'rawResponse': 'You reach a door.\n\n> 1. Open',
            'isComplete': true,
          },
        ],
      };

      session.restoreFromSaveData(saveData);

      expect(session.turnNumber, 3);
      expect(session.history, hasLength(3));
      expect(session.history[0].playerCommand, 'look');
      expect(session.history[1].playerCommand, 'go north');
      expect(session.history[2].playerCommand, 'walk');
      expect(session.history[2].narrativeText, 'You reach a door.');
    });

    test('restored session can continue with new turns', () async {
      final session = GameSession(
        systemPrompt: 'Test GM.',
        generate: _mockGenerator(
          'New scene.\n\n> 1. Option A\n> 2. Option B\n> 3. Option C',
        ),
      );

      session.restoreFromSaveData({
        'turnNumber': 2,
        'turns': [
          {
            'turnNumber': 1,
            'playerCommand': 'look',
            'narrativeText': 'Old scene.',
            'suggestions': <dynamic>['A', 'B', 'C'],
            'rawResponse': 'Old scene.',
            'isComplete': true,
          },
          {
            'turnNumber': 2,
            'playerCommand': 'go',
            'narrativeText': 'Another scene.',
            'suggestions': <dynamic>['D', 'E', 'F'],
            'rawResponse': 'Another scene.',
            'isComplete': true,
          },
        ],
      });

      // Submit a new command after restore.
      final turns = await session.submitCommand('explore').toList();
      final lastTurn = turns.last;

      expect(lastTurn.isComplete, isTrue);
      expect(lastTurn.turnNumber, 3); // Continues from restored state
      expect(session.history, hasLength(3));
    });
  });

  group('GameSession save → restore round-trip', () {
    test('full round-trip preserves all state', () async {
      // Build a 3-turn session.
      final original = GameSession(
        systemPrompt: 'Test Game Master.',
        generate: _multiTurnGenerator([
          'You enter a dark cave.\n\n'
              '> 1. Light a torch\n> 2. Feel the walls\n> 3. Turn back',
          'The torch reveals ancient paintings.\n\n'
              '> 1. Examine paintings\n> 2. Go deeper\n> 3. Rest',
          'The paintings depict a great battle.\n\n'
              '> 1. Touch them\n> 2. Read inscriptions\n> 3. Move on',
        ]),
      );

      await original.submitCommand('enter cave').toList();
      await original.submitCommand('light torch').toList();
      await original.submitCommand('examine paintings').toList();

      // Save.
      await original.saveState(saveFilePath, adventureId: 'sunken_archive');

      // Restore into a new session.
      final saveData = await GameSession.loadSaveData(saveFilePath);
      expect(saveData, isNotNull);

      final restored = GameSession(
        systemPrompt: 'Test Game Master.',
        generate: _mockGenerator(''),
      );
      restored.restoreFromSaveData(saveData!);

      // Verify state matches.
      expect(restored.turnNumber, original.turnNumber);
      expect(restored.history.length, original.history.length);

      for (var i = 0; i < original.history.length; i++) {
        final orig = original.history[i];
        final rest = restored.history[i];
        expect(rest.turnNumber, orig.turnNumber);
        expect(rest.playerCommand, orig.playerCommand);
        expect(rest.narrativeText, orig.narrativeText);
        expect(rest.suggestions, orig.suggestions);
        expect(rest.rawResponse, orig.rawResponse);
        expect(rest.isComplete, orig.isComplete);
      }
    });

    test('round-trip preserves adventureId', () async {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _mockGenerator(
          'Scene.\n\n> 1. A\n> 2. B\n> 3. C',
        ),
      );

      await session.submitCommand('start').toList();
      await session.saveState(saveFilePath, adventureId: 'sunken_archive');

      final data = await GameSession.loadSaveData(saveFilePath);
      expect(data!['adventureId'], 'sunken_archive');
    });

    test('overwriting save replaces old data', () async {
      final session = GameSession(
        systemPrompt: 'GM.',
        generate: _multiTurnGenerator([
          'Turn 1.\n\n> 1. A\n> 2. B\n> 3. C',
          'Turn 2.\n\n> 1. D\n> 2. E\n> 3. F',
        ]),
      );

      await session.submitCommand('first').toList();
      await session.saveState(saveFilePath, adventureId: 'test');

      var data = await GameSession.loadSaveData(saveFilePath);
      expect(data!['turnNumber'], 1);

      await session.submitCommand('second').toList();
      await session.saveState(saveFilePath, adventureId: 'test');

      data = await GameSession.loadSaveData(saveFilePath);
      expect(data!['turnNumber'], 2);
      expect((data['turns'] as List).length, 2);
    });
  });

  group('GameSession.deleteSave', () {
    test('deletes existing save file', () async {
      File(saveFilePath).writeAsStringSync('{}');
      expect(File(saveFilePath).existsSync(), isTrue);

      await GameSession.deleteSave(saveFilePath);
      expect(File(saveFilePath).existsSync(), isFalse);
    });

    test('does nothing when file does not exist', () async {
      // Should not throw.
      await GameSession.deleteSave('${tempDir.path}/nonexistent.json');
    });
  });
}
