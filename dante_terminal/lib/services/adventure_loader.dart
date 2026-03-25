import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/adventure_data.dart';

/// Asset path prefix for bundled adventure JSON files.
const kAdventureAssetPrefix = 'assets/adventures/';

/// Loads adventure scenario data from bundled JSON assets.
///
/// Adventure JSON files conform to the schema defined in
/// `assets/adventure_schema.json`. Each file contains a complete adventure
/// scenario with locations, items, NPCs, and puzzles.
///
/// Usage:
/// ```dart
/// final loader = AdventureLoader();
/// final adventure = await loader.load('sunken_archive');
/// final location = adventure.getLocation('antechamber');
/// final item = adventure.getItem('brass_key');
/// final npc = adventure.getNpc('maren');
/// ```
///
/// See also:
/// - BL-044: Starter adventure scenario (The Sunken Archive)
/// - BL-051: Adventure data schema and content loader
class AdventureLoader {
  /// Cache of loaded adventures, keyed by adventure ID.
  final Map<String, AdventureData> _cache = {};

  /// Load an adventure by ID from bundled assets.
  ///
  /// The adventure JSON is expected at `assets/adventures/{id}.json`.
  /// Results are cached after the first load.
  ///
  /// Throws [FlutterError] if the asset is not found.
  /// Throws [FormatException] if the JSON is malformed.
  Future<AdventureData> load(String adventureId) async {
    if (_cache.containsKey(adventureId)) {
      return _cache[adventureId]!;
    }

    final path = '$kAdventureAssetPrefix$adventureId.json';
    final jsonString = await rootBundle.loadString(path);
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final adventure = AdventureData.fromJson(jsonMap);

    _cache[adventureId] = adventure;
    return adventure;
  }

  /// Load an adventure from a raw JSON string.
  ///
  /// Useful for testing or loading from non-asset sources (e.g., downloaded
  /// content). Results are cached by the adventure's ID.
  AdventureData loadFromString(String jsonString) {
    final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    final adventure = AdventureData.fromJson(jsonMap);
    _cache[adventure.id] = adventure;
    return adventure;
  }

  /// Convenience lookup: get a location from a loaded adventure.
  ///
  /// Returns null if the adventure hasn't been loaded or the location
  /// ID doesn't exist.
  Location? getLocation(String adventureId, String locationId) {
    return _cache[adventureId]?.getLocation(locationId);
  }

  /// Convenience lookup: get an item from a loaded adventure.
  ///
  /// Returns null if the adventure hasn't been loaded or the item
  /// ID doesn't exist.
  Item? getItem(String adventureId, String itemId) {
    return _cache[adventureId]?.getItem(itemId);
  }

  /// Convenience lookup: get an NPC from a loaded adventure.
  ///
  /// Returns null if the adventure hasn't been loaded or the NPC
  /// ID doesn't exist.
  Npc? getNpc(String adventureId, String npcId) {
    return _cache[adventureId]?.getNpc(npcId);
  }

  /// Clear all cached adventures.
  void clearCache() {
    _cache.clear();
  }

  /// Check if an adventure has been loaded and cached.
  bool isLoaded(String adventureId) => _cache.containsKey(adventureId);
}
