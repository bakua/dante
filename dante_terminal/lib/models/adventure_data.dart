/// Data models for adventure scenario content.
///
/// These types represent the structured adventure data loaded from JSON files
/// by [AdventureLoader]. They are consumed by [GameSession] for prompt assembly
/// and by the game engine for state management.
///
/// Designed for BL-044's Sunken Archive scenario and constrained by L-012
/// token budgets (≤60 tokens per location description, ≤55 tokens per NPC).
///
/// See also:
/// - BL-044: Starter adventure scenario design document
/// - BL-010: Keyword-triggered lore entry pattern
/// - BL-013: Game design one-pager (quest flag system)
library;

// ---------------------------------------------------------------------------
// Exit
// ---------------------------------------------------------------------------

/// A directional connection between two locations.
class Exit {
  /// Compass direction or spatial label (north, south, east, west, up, down).
  final String direction;

  /// ID of the destination location.
  final String targetLocationId;

  /// Whether this exit is initially impassable.
  final bool blocked;

  /// Description of what blocks the exit (for GM narration).
  final String? blockedBy;

  /// Quest flag that must be true to use this exit.
  final String? requiredFlag;

  const Exit({
    required this.direction,
    required this.targetLocationId,
    this.blocked = false,
    this.blockedBy,
    this.requiredFlag,
  });

  factory Exit.fromJson(Map<String, dynamic> json) {
    return Exit(
      direction: json['direction'] as String,
      targetLocationId: json['targetLocationId'] as String,
      blocked: json['blocked'] as bool? ?? false,
      blockedBy: json['blockedBy'] as String?,
      requiredFlag: json['requiredFlag'] as String?,
    );
  }

  @override
  String toString() => 'Exit($direction → $targetLocationId'
      '${blocked ? ", blocked" : ""})';
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

/// An explorable location in an adventure.
class Location {
  /// Unique location identifier (snake_case).
  final String id;

  /// Display name for the location.
  final String name;

  /// Lore entry for GM prompt injection (≤60 tokens).
  final String description;

  /// Trigger words that activate this location's lore entry.
  final List<String> keywords;

  /// Short mood/tone descriptor for GM voice calibration.
  final String? atmosphere;

  /// Available movement directions from this location.
  final List<Exit> exits;

  /// IDs of items discoverable in this location.
  final List<String> itemIds;

  /// IDs of NPCs present in this location.
  final List<String> npcIds;

  const Location({
    required this.id,
    required this.name,
    required this.description,
    required this.keywords,
    this.atmosphere,
    required this.exits,
    this.itemIds = const [],
    this.npcIds = const [],
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      atmosphere: json['atmosphere'] as String?,
      exits: (json['exits'] as List<dynamic>)
          .map((e) => Exit.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemIds: (json['itemIds'] as List<dynamic>?)?.cast<String>() ?? [],
      npcIds: (json['npcIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  String toString() => 'Location($id: $name)';
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

/// A context-specific use behavior for an item.
class Interaction {
  /// What the item is used on (location ID, item ID, NPC ID, or 'passive').
  final String target;

  /// Narrative description of what happens.
  final String effect;

  /// Quest flag set to true when this interaction occurs.
  final String? setsFlag;

  /// Whether this interaction destroys the item.
  final bool consumesItem;

  const Interaction({
    required this.target,
    required this.effect,
    this.setsFlag,
    this.consumesItem = false,
  });

  factory Interaction.fromJson(Map<String, dynamic> json) {
    return Interaction(
      target: json['target'] as String,
      effect: json['effect'] as String,
      setsFlag: json['setsFlag'] as String?,
      consumesItem: json['consumesItem'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Item
// ---------------------------------------------------------------------------

/// A collectible or interactive item in an adventure.
class Item {
  /// Unique item identifier (snake_case).
  final String id;

  /// Display name for the item.
  final String name;

  /// Lore entry for prompt injection (≤50 tokens).
  final String description;

  /// Trigger words that activate this item's lore entry.
  final List<String> keywords;

  /// Location ID where this item is first discoverable.
  final String foundLocationId;

  /// Whether the player begins with this item.
  final bool isStartingItem;

  /// Whether the item is destroyed on use.
  final bool consumable;

  /// Context-specific use behaviors.
  final List<Interaction> interactions;

  const Item({
    required this.id,
    required this.name,
    required this.description,
    required this.keywords,
    required this.foundLocationId,
    this.isStartingItem = false,
    this.consumable = false,
    this.interactions = const [],
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      foundLocationId: json['foundLocationId'] as String,
      isStartingItem: json['isStartingItem'] as bool? ?? false,
      consumable: json['consumable'] as bool? ?? false,
      interactions: (json['interactions'] as List<dynamic>?)
              ?.map((e) => Interaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  String toString() => 'Item($id: $name)';
}

// ---------------------------------------------------------------------------
// NPC
// ---------------------------------------------------------------------------

/// A non-player character in an adventure.
class Npc {
  /// Unique NPC identifier (snake_case).
  final String id;

  /// Display name for the NPC.
  final String name;

  /// Lore entry for prompt injection (≤55 tokens).
  final String description;

  /// Trigger words that activate this NPC's lore entry.
  final List<String> keywords;

  /// Location ID where this NPC is found.
  final String locationId;

  /// Brief personality sketch for GM voice calibration.
  final String personality;

  /// Named dialogue triggers mapping context keys to sample dialogue.
  final Map<String, String> dialogueHooks;

  /// Quest flags this NPC can set through interaction.
  final List<String> questFlags;

  const Npc({
    required this.id,
    required this.name,
    required this.description,
    required this.keywords,
    required this.locationId,
    required this.personality,
    this.dialogueHooks = const {},
    this.questFlags = const [],
  });

  factory Npc.fromJson(Map<String, dynamic> json) {
    return Npc(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      locationId: json['locationId'] as String,
      personality: json['personality'] as String,
      dialogueHooks:
          (json['dialogueHooks'] as Map<String, dynamic>?)?.cast<String, String>() ??
              {},
      questFlags:
          (json['questFlags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  String toString() => 'Npc($id: $name)';
}

// ---------------------------------------------------------------------------
// Solution
// ---------------------------------------------------------------------------

/// A solution path for a puzzle.
class Solution {
  /// Solution path name (e.g., 'Primary', 'Alternative').
  final String name;

  /// Item IDs needed for this solution.
  final List<String> requiredItems;

  /// Quest flags that must be set for this solution.
  final List<String> requiredFlags;

  /// Ordered steps the player takes.
  final List<String> steps;

  /// Quest flags set by completing this solution path.
  final List<String> setsFlags;

  const Solution({
    required this.name,
    this.requiredItems = const [],
    this.requiredFlags = const [],
    required this.steps,
    this.setsFlags = const [],
  });

  factory Solution.fromJson(Map<String, dynamic> json) {
    return Solution(
      name: json['name'] as String,
      requiredItems:
          (json['requiredItems'] as List<dynamic>?)?.cast<String>() ?? [],
      requiredFlags:
          (json['requiredFlags'] as List<dynamic>?)?.cast<String>() ?? [],
      steps: (json['steps'] as List<dynamic>).cast<String>(),
      setsFlags:
          (json['setsFlags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

// ---------------------------------------------------------------------------
// Puzzle
// ---------------------------------------------------------------------------

/// A puzzle in an adventure's progression chain.
class Puzzle {
  /// Unique puzzle identifier (snake_case).
  final String id;

  /// Display name for the puzzle.
  final String name;

  /// Which act this puzzle belongs to (1=Orientation, 2=Escalation, 3=Resolution).
  final int act;

  /// What the puzzle requires the player to accomplish.
  final String description;

  /// Primary location where this puzzle is encountered.
  final String? locationId;

  /// Multiple solution paths (wide paths, narrow gates per BL-013).
  final List<Solution> solutions;

  /// Quest flags set when the puzzle is solved.
  final List<String> completionFlags;

  /// Expected turn range to solve (e.g., '3-6').
  final String? turnBudget;

  const Puzzle({
    required this.id,
    required this.name,
    required this.act,
    required this.description,
    this.locationId,
    required this.solutions,
    this.completionFlags = const [],
    this.turnBudget,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      name: json['name'] as String,
      act: json['act'] as int,
      description: json['description'] as String,
      locationId: json['locationId'] as String?,
      solutions: (json['solutions'] as List<dynamic>)
          .map((e) => Solution.fromJson(e as Map<String, dynamic>))
          .toList(),
      completionFlags:
          (json['completionFlags'] as List<dynamic>?)?.cast<String>() ?? [],
      turnBudget: json['turnBudget'] as String?,
    );
  }

  @override
  String toString() => 'Puzzle($id: $name, act=$act)';
}

// ---------------------------------------------------------------------------
// AdventureData (top-level)
// ---------------------------------------------------------------------------

/// Complete adventure scenario data parsed from JSON.
///
/// This is the top-level model returned by [AdventureLoader.load].
class AdventureData {
  /// Unique adventure identifier.
  final String id;

  /// Human-readable adventure title.
  final String title;

  /// Adventure genre/theme tag.
  final String theme;

  /// Cold-open narrative shown on adventure start.
  final String openingNarrative;

  /// ID of the starting location.
  final String startLocationId;

  /// Item IDs the player starts with.
  final List<String> startInventory;

  /// All locations indexed by ID.
  final Map<String, Location> _locations;

  /// All items indexed by ID.
  final Map<String, Item> _items;

  /// All NPCs indexed by ID.
  final Map<String, Npc> _npcs;

  /// All puzzles indexed by ID.
  final Map<String, Puzzle> _puzzles;

  /// Initial quest flag state.
  final Map<String, dynamic> questFlags;

  AdventureData({
    required this.id,
    required this.title,
    required this.theme,
    required this.openingNarrative,
    required this.startLocationId,
    required this.startInventory,
    required List<Location> locations,
    required List<Item> items,
    required List<Npc> npcs,
    required List<Puzzle> puzzles,
    required this.questFlags,
  })  : _locations = {for (final l in locations) l.id: l},
        _items = {for (final i in items) i.id: i},
        _npcs = {for (final n in npcs) n.id: n},
        _puzzles = {for (final p in puzzles) p.id: p};

  /// All locations as an unmodifiable list.
  List<Location> get locations => _locations.values.toList();

  /// All items as an unmodifiable list.
  List<Item> get items => _items.values.toList();

  /// All NPCs as an unmodifiable list.
  List<Npc> get npcs => _npcs.values.toList();

  /// All puzzles as an unmodifiable list.
  List<Puzzle> get puzzles => _puzzles.values.toList();

  /// Look up a location by ID. Returns null if not found.
  Location? getLocation(String id) => _locations[id];

  /// Look up an item by ID. Returns null if not found.
  Item? getItem(String id) => _items[id];

  /// Look up an NPC by ID. Returns null if not found.
  Npc? getNpc(String id) => _npcs[id];

  /// Look up a puzzle by ID. Returns null if not found.
  Puzzle? getPuzzle(String id) => _puzzles[id];

  /// Parse adventure data from a decoded JSON map.
  factory AdventureData.fromJson(Map<String, dynamic> json) {
    return AdventureData(
      id: json['id'] as String,
      title: json['title'] as String,
      theme: json['theme'] as String,
      openingNarrative: json['openingNarrative'] as String,
      startLocationId: json['startLocationId'] as String,
      startInventory:
          (json['startInventory'] as List<dynamic>).cast<String>(),
      locations: (json['locations'] as List<dynamic>)
          .map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List<dynamic>)
          .map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList(),
      npcs: (json['npcs'] as List<dynamic>)
          .map((e) => Npc.fromJson(e as Map<String, dynamic>))
          .toList(),
      puzzles: (json['puzzles'] as List<dynamic>)
          .map((e) => Puzzle.fromJson(e as Map<String, dynamic>))
          .toList(),
      questFlags: Map<String, dynamic>.from(
          json['questFlags'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() =>
      'AdventureData($id: $title, '
      '${_locations.length} locations, '
      '${_items.length} items, '
      '${_npcs.length} npcs, '
      '${_puzzles.length} puzzles)';
}
