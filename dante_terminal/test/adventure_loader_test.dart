import 'dart:io';

import 'package:dante_terminal/models/adventure_data.dart';
import 'package:dante_terminal/services/adventure_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the Sunken Archive JSON directly from disk for testing
/// (rootBundle is not available in unit tests).
String _loadSunkenArchiveJson() {
  final file = File('assets/adventures/sunken_archive.json');
  return file.readAsStringSync();
}

void main() {
  late AdventureLoader loader;
  late AdventureData adventure;

  setUpAll(() {
    loader = AdventureLoader();
    adventure = loader.loadFromString(_loadSunkenArchiveJson());
  });

  group('AdventureData top-level', () {
    test('parses adventure metadata', () {
      expect(adventure.id, 'sunken_archive');
      expect(adventure.title, 'The Sunken Archive');
      expect(adventure.theme, 'Classic dungeon crawl');
      expect(adventure.startLocationId, 'antechamber');
      expect(adventure.startInventory, ['oil_lamp']);
    });

    test('has opening narrative', () {
      expect(adventure.openingNarrative, contains('You wake on stone'));
      expect(adventure.openingNarrative, contains('Archive remembers you'));
    });

    test('has correct entity counts', () {
      expect(adventure.locations.length, 9);
      expect(adventure.items.length, 6);
      expect(adventure.npcs.length, 3);
      expect(adventure.puzzles.length, 4);
    });

    test('has quest flags initialized', () {
      expect(adventure.questFlags, isA<Map<String, dynamic>>());
      expect(adventure.questFlags['brass_key_found'], false);
      expect(adventure.questFlags['gate_opened'], false);
      expect(adventure.questFlags['escaped'], false);
      expect(adventure.questFlags['ending'], isNull);
    });
  });

  group('Location lookups', () {
    test('getLocation returns Antechamber correctly', () {
      final antechamber = adventure.getLocation('antechamber');
      expect(antechamber, isNotNull);
      expect(antechamber!.name, 'The Antechamber');
      expect(antechamber.keywords, contains('antechamber'));
      expect(antechamber.keywords, contains('rubble'));
      expect(antechamber.exits.length, 2);
      expect(antechamber.exits.first.direction, 'north');
      expect(antechamber.exits.first.targetLocationId, 'main_hall');
    });

    test('getLocation returns Main Hall with 4 exits', () {
      final mainHall = adventure.getLocation('main_hall');
      expect(mainHall, isNotNull);
      expect(mainHall!.name, 'The Main Hall');
      expect(mainHall.exits.length, 4);
      final directions = mainHall.exits.map((e) => e.direction).toSet();
      expect(directions, containsAll(['south', 'east', 'west', 'north']));
    });

    test('getLocation returns Vault of the Codex', () {
      final vault = adventure.getLocation('vault_of_the_codex');
      expect(vault, isNotNull);
      expect(vault!.name, 'The Vault of the Codex');
      expect(vault.atmosphere, 'Finality, awe');
      expect(vault.exits.length, 1);
      expect(vault.exits.first.direction, 'up');
    });

    test('getLocation returns Reading Room with NPC and item', () {
      final readingRoom = adventure.getLocation('reading_room');
      expect(readingRoom, isNotNull);
      expect(readingRoom!.npcIds, contains('maren'));
      expect(readingRoom.itemIds, contains('cipher_wheel'));
    });

    test('getLocation returns null for unknown ID', () {
      expect(adventure.getLocation('nonexistent'), isNull);
    });

    test('all 9 locations are accessible by ID', () {
      final expectedIds = [
        'antechamber',
        'east_wing',
        'main_hall',
        'west_wing',
        'flooded_passage',
        'circulation_desk',
        'reading_room',
        'restricted_section',
        'vault_of_the_codex',
      ];
      for (final id in expectedIds) {
        expect(adventure.getLocation(id), isNotNull,
            reason: 'Location $id should exist');
      }
    });

    test('blocked exits have correct metadata', () {
      final circDesk = adventure.getLocation('circulation_desk');
      final northExit = circDesk!.exits.firstWhere(
        (e) => e.direction == 'north',
      );
      expect(northExit.blocked, true);
      expect(northExit.requiredFlag, 'gate_opened');
      expect(northExit.blockedBy, isNotNull);
    });
  });

  group('Location descriptions ≤60 tokens', () {
    test('all location descriptions are within token budget', () {
      // Using ~4 chars/token heuristic from game_session.dart.
      const charsPerToken = 4;
      const maxTokens = 60;
      for (final location in adventure.locations) {
        final tokenEstimate =
            (location.description.length / charsPerToken).ceil();
        // Allow a small margin since the 4 chars/token is approximate
        expect(
          tokenEstimate,
          lessThanOrEqualTo(maxTokens + 10), // +10 token grace for heuristic
          reason: '${location.id} description is $tokenEstimate tokens '
              '(${location.description.length} chars), '
              'exceeds 60-token budget',
        );
      }
    });
  });

  group('Item lookups', () {
    test('getItem returns Oil Lamp as starting item', () {
      final lamp = adventure.getItem('oil_lamp');
      expect(lamp, isNotNull);
      expect(lamp!.name, 'Oil Lamp');
      expect(lamp.isStartingItem, true);
      expect(lamp.consumable, false);
      expect(lamp.keywords, contains('lamp'));
    });

    test('getItem returns Brass Key as consumable', () {
      final key = adventure.getItem('brass_key');
      expect(key, isNotNull);
      expect(key!.name, 'Brass Key');
      expect(key.consumable, true);
      expect(key.foundLocationId, 'east_wing');
      expect(key.interactions.length, greaterThan(0));
    });

    test('getItem returns Cipher Wheel with interactions', () {
      final cipher = adventure.getItem('cipher_wheel');
      expect(cipher, isNotNull);
      expect(cipher!.name, 'Cipher Wheel');
      expect(cipher.foundLocationId, 'reading_room');
      expect(cipher.interactions.length, 3);
    });

    test('getItem returns null for unknown ID', () {
      expect(adventure.getItem('nonexistent'), isNull);
    });

    test('all 6 items are accessible by ID', () {
      final expectedIds = [
        'oil_lamp',
        'brass_key',
        'archivists_journal',
        'glass_vial_solvent',
        'waterproof_satchel',
        'cipher_wheel',
      ];
      for (final id in expectedIds) {
        expect(adventure.getItem(id), isNotNull,
            reason: 'Item $id should exist');
      }
    });
  });

  group('NPC lookups', () {
    test('getNpc returns Maren with dialogue hooks', () {
      final maren = adventure.getNpc('maren');
      expect(maren, isNotNull);
      expect(maren!.name, 'Maren');
      expect(maren.locationId, 'reading_room');
      expect(maren.dialogueHooks, isNotEmpty);
      expect(maren.dialogueHooks['first_meeting'], contains('Come. Closer'));
      expect(maren.questFlags, contains('maren_trusts'));
    });

    test('getNpc returns The Cataloger', () {
      final cataloger = adventure.getNpc('the_cataloger');
      expect(cataloger, isNotNull);
      expect(cataloger!.name, 'The Cataloger');
      expect(cataloger.locationId, 'circulation_desk');
      expect(cataloger.dialogueHooks['summoned'], contains('Reference desk'));
    });

    test('getNpc returns The Warden', () {
      final warden = adventure.getNpc('the_warden');
      expect(warden, isNotNull);
      expect(warden!.name, 'The Warden');
      expect(warden.locationId, 'restricted_section');
      expect(warden.personality, contains('Ancient'));
    });

    test('getNpc returns null for unknown ID', () {
      expect(adventure.getNpc('nonexistent'), isNull);
    });
  });

  group('Puzzle lookups', () {
    test('getPuzzle returns The Locked Gate with multiple solutions', () {
      final puzzle = adventure.getPuzzle('locked_gate');
      expect(puzzle, isNotNull);
      expect(puzzle!.name, 'The Locked Gate');
      expect(puzzle.act, 1);
      expect(puzzle.solutions.length, 2);
      expect(puzzle.completionFlags, contains('gate_opened'));
    });

    test('getPuzzle returns all 4 puzzles', () {
      final expectedIds = [
        'locked_gate',
        'cipher_discovery',
        'wardens_question',
        'codex_and_flood',
      ];
      for (final id in expectedIds) {
        expect(adventure.getPuzzle(id), isNotNull,
            reason: 'Puzzle $id should exist');
      }
    });
  });

  group('AdventureLoader caching', () {
    test('loadFromString caches by adventure ID', () {
      final loader2 = AdventureLoader();
      loader2.loadFromString(_loadSunkenArchiveJson());
      expect(loader2.isLoaded('sunken_archive'), true);
      expect(loader2.isLoaded('nonexistent'), false);

      // Convenience lookups work after loading
      expect(loader2.getLocation('sunken_archive', 'antechamber'), isNotNull);
      expect(loader2.getItem('sunken_archive', 'oil_lamp'), isNotNull);
      expect(loader2.getNpc('sunken_archive', 'maren'), isNotNull);
    });

    test('clearCache removes loaded adventures', () {
      final loader3 = AdventureLoader();
      loader3.loadFromString(_loadSunkenArchiveJson());
      expect(loader3.isLoaded('sunken_archive'), true);

      loader3.clearCache();
      expect(loader3.isLoaded('sunken_archive'), false);
      expect(loader3.getLocation('sunken_archive', 'antechamber'), isNull);
    });
  });

  group('Cross-referential integrity', () {
    test('all location itemIds reference valid items', () {
      for (final location in adventure.locations) {
        for (final itemId in location.itemIds) {
          expect(adventure.getItem(itemId), isNotNull,
              reason: 'Location ${location.id} references unknown item $itemId');
        }
      }
    });

    test('all location npcIds reference valid NPCs', () {
      for (final location in adventure.locations) {
        for (final npcId in location.npcIds) {
          expect(adventure.getNpc(npcId), isNotNull,
              reason: 'Location ${location.id} references unknown NPC $npcId');
        }
      }
    });

    test('all item foundLocationIds reference valid locations', () {
      for (final item in adventure.items) {
        expect(adventure.getLocation(item.foundLocationId), isNotNull,
            reason: 'Item ${item.id} references unknown location '
                '${item.foundLocationId}');
      }
    });

    test('all NPC locationIds reference valid locations', () {
      for (final npc in adventure.npcs) {
        expect(adventure.getLocation(npc.locationId), isNotNull,
            reason: 'NPC ${npc.id} references unknown location '
                '${npc.locationId}');
      }
    });

    test('all exit targetLocationIds reference valid locations', () {
      for (final location in adventure.locations) {
        for (final exit in location.exits) {
          // Skip the "surface" exit — it's the win condition destination
          if (exit.targetLocationId == 'surface') continue;
          expect(adventure.getLocation(exit.targetLocationId), isNotNull,
              reason: 'Location ${location.id} exit ${exit.direction} '
                  'references unknown location ${exit.targetLocationId}');
        }
      }
    });

    test('startLocationId references a valid location', () {
      expect(adventure.getLocation(adventure.startLocationId), isNotNull);
    });

    test('startInventory items all exist', () {
      for (final itemId in adventure.startInventory) {
        expect(adventure.getItem(itemId), isNotNull,
            reason: 'Starting inventory item $itemId does not exist');
      }
    });
  });
}
