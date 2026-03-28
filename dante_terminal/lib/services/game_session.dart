/// Game session service managing turn history, prompt assembly, suggestion
/// parsing, and game state persistence for DANTE TERMINAL.
///
/// This is the 'controller' layer between the UI (BL-039) and the inference
/// engine (BL-038). It consumes player input strings and produces structured
/// [GameTurn] objects containing narrative text and suggestions.
///
/// Persistence (BL-118): [saveState] serializes the session to a JSON file
/// and [restoreFromSaveData] rebuilds it, enabling save-on-exit / resume-on-
/// launch. The actual file path comes from the UI layer (via path_provider).
///
/// Ported from prototype/dante_cli.py's GameSession class. Uses only dart:core,
/// dart:convert, and dart:io for independent unit testing (no Flutter imports).
///
/// See also:
/// - BL-010: GM prompt patterns (system prompt + anchor note strategy)
/// - BL-036: Small-model prompting techniques (recency-bias exploitation)
/// - BL-049: GBNF grammar for structured output enforcement
/// - BL-118: Game state persistence
library;

import 'dart:convert';
import 'dart:io';

import '../models/adventure_data.dart';

/// Style anchor injected near the generation point to exploit recency bias
/// and maintain persona/format compliance (BL-036 section 2.3).
const kStyleAnchor =
    '[Style: sardonic narrator, sensory detail, max 90 words. Exactly 3 suggestions.]';

/// Default opening prompt for the first turn of a new adventure.
const kOpeningPrompt =
    'Begin the adventure. Describe the opening scene where the player awakens.';

/// Approximate characters per token for budget estimation.
/// Matches the ~4 chars/token heuristic used in prototype/dante_cli.py.
const _kCharsPerToken = 4;

/// Default maximum prompt tokens for small on-device models.
///
/// For a 2048-token context window, this reserves 248 tokens for generation
/// output, yielding a 1800-token budget for the assembled prompt (system
/// prompt + history + current command). Adjust via
/// [GameSession.contextBudgetTokens] and [GameSession.maxResponseTokens].
const kMaxPromptTokens = 1800;

/// Number of most-recent turns to always preserve verbatim in the sliding
/// context window. Older turns are compressed into a narrative summary.
const kRecentTurnsToKeep = 2;

/// Maximum token budget for the location context block injected into prompts.
///
/// Designed to accommodate any Sunken Archive location's name, description,
/// exits, items, and NPCs in a single compact line. Descriptions exceeding
/// the budget are truncated at the nearest sentence boundary.
const kLocationContextMaxTokens = 80;

/// Signature for a text generation function.
///
/// Allows injection of [InferenceService.generate] in production or a mock
/// stream in tests. The contract mirrors [InferenceService.generate]:
/// yields individual tokens as strings.
typedef GenerateFunction = Stream<String> Function(
  String prompt, {
  int maxTokens,
  String? grammarFilePath,
});

// ---------------------------------------------------------------------------
// GameTurn model
// ---------------------------------------------------------------------------

/// A single completed (or in-progress) game turn.
///
/// During streaming, intermediate emissions have [isComplete] = false with
/// a growing [narrativeText] and empty [suggestions]. The final emission has
/// [isComplete] = true with parsed suggestions.
class GameTurn {
  /// Sequential turn number (1-indexed).
  final int turnNumber;

  /// The player's command that triggered this turn.
  final String playerCommand;

  /// The narrative text from the Game Master.
  ///
  /// During streaming this grows incrementally; when [isComplete] is true
  /// it contains the final parsed narrative (without the suggestion block).
  final String narrativeText;

  /// The 3 action suggestions parsed from the response.
  ///
  /// Empty during streaming; populated when the turn is complete.
  final List<String> suggestions;

  /// The raw, unparsed AI response (narrative + suggestion block).
  final String rawResponse;

  /// Whether this turn's response is fully generated and parsed.
  final bool isComplete;

  const GameTurn({
    required this.turnNumber,
    required this.playerCommand,
    required this.narrativeText,
    this.suggestions = const [],
    this.rawResponse = '',
    this.isComplete = false,
  });

  /// Create a copy with updated fields.
  GameTurn copyWith({
    String? narrativeText,
    List<String>? suggestions,
    String? rawResponse,
    bool? isComplete,
  }) {
    return GameTurn(
      turnNumber: turnNumber,
      playerCommand: playerCommand,
      narrativeText: narrativeText ?? this.narrativeText,
      suggestions: suggestions ?? this.suggestions,
      rawResponse: rawResponse ?? this.rawResponse,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  /// Serialize this turn to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'turnNumber': turnNumber,
        'playerCommand': playerCommand,
        'narrativeText': narrativeText,
        'suggestions': suggestions,
        'rawResponse': rawResponse,
        'isComplete': isComplete,
      };

  /// Deserialize a turn from a JSON map (produced by [toJson]).
  factory GameTurn.fromJson(Map<String, dynamic> json) => GameTurn(
        turnNumber: json['turnNumber'] as int,
        playerCommand: json['playerCommand'] as String,
        narrativeText: json['narrativeText'] as String,
        suggestions:
            (json['suggestions'] as List<dynamic>).cast<String>().toList(),
        rawResponse: json['rawResponse'] as String? ?? '',
        isComplete: json['isComplete'] as bool? ?? true,
      );

  @override
  String toString() =>
      'GameTurn(turn=$turnNumber, complete=$isComplete, '
      'suggestions=${suggestions.length}, '
      'narrative=${narrativeText.length} chars)';
}

// ---------------------------------------------------------------------------
// GameSession service
// ---------------------------------------------------------------------------

/// Manages the game loop between UI events and the inference service.
///
/// Responsibilities:
/// - Assembles the full prompt from system prompt + turn history + current
///   command, respecting a configurable context token budget.
/// - Parses AI responses to extract narrative text and 3 suggestion strings.
/// - Maintains conversation history as a list of [GameTurn] objects.
/// - Enforces turn structure (style anchor injection after first turn).
///
/// Usage:
/// ```dart
/// final session = GameSession(
///   systemPrompt: await gameAssets.loadSystemPrompt(),
///   generate: inferenceService.generate,
///   grammarFilePath: '/path/to/game_master.gbnf',
/// );
///
/// await for (final turn in session.startAdventure()) {
///   if (turn.isComplete) {
///     showSuggestions(turn.suggestions);
///   } else {
///     appendToScreen(turn.narrativeText);
///   }
/// }
/// ```
class GameSession {
  /// The Game Master system prompt (loaded from assets).
  final String systemPrompt;

  /// Maximum context window budget in tokens.
  ///
  /// Prompt assembly will trim oldest history turns to stay within this limit.
  /// Default is 4096, matching common small-model context sizes.
  final int contextBudgetTokens;

  /// Maximum tokens allocated for response generation.
  ///
  /// Defaults to 200, matching the BL-036 section 4.4 recommendation.
  final int maxResponseTokens;

  /// Optional path to GBNF grammar file for structured output (BL-049).
  final String? grammarFilePath;

  final GenerateFunction _generate;
  final List<GameTurn> _history = [];
  int _turnNumber = 0;
  Location? _currentLocation;

  /// Creates a new game session.
  ///
  /// [systemPrompt] is the Game Master prompt (from [GameAssets.loadSystemPrompt]).
  /// [generate] is the text generation function (typically [InferenceService.generate]).
  /// [contextBudgetTokens] is the total context window budget.
  /// [maxResponseTokens] caps generation length per turn.
  /// [grammarFilePath] optionally constrains output format via GBNF.
  GameSession({
    required this.systemPrompt,
    required GenerateFunction generate,
    this.contextBudgetTokens = 4096,
    this.maxResponseTokens = 200,
    this.grammarFilePath,
  }) : _generate = generate;

  /// Read-only access to completed turn history.
  List<GameTurn> get history => List.unmodifiable(_history);

  /// Current turn number (0 before any turns).
  int get turnNumber => _turnNumber;

  /// The currently set location, or null if no location has been set.
  Location? get currentLocation => _currentLocation;

  /// Set the current location for prompt context injection.
  ///
  /// When set, [assemblePrompt] injects a compact `CURRENT LOCATION:` block
  /// between the system prompt and conversation history, grounding the model's
  /// responses in the actual room data (name, description, exits, items, NPCs).
  ///
  /// Call this when the player moves to a new location or at adventure start.
  void setLocation(Location location) {
    _currentLocation = location;
  }

  /// Build a compact location context block for prompt injection.
  ///
  /// Format: `CURRENT LOCATION: [name]. [description]. Exits: [list].
  /// Items: [list]. NPCs: [list].`
  ///
  /// Enforces [kLocationContextMaxTokens] budget by truncating the description
  /// at the nearest sentence boundary when the full block would exceed it.
  ///
  /// Returns an empty string if [location] is null.
  static String buildLocationContext(Location location) {
    final prefix = 'CURRENT LOCATION: ${location.name}.';

    // Build structured suffix (exits, items, NPCs).
    final suffixParts = <String>[];
    final exitDirs = location.exits.map((e) => e.direction).join(', ');
    if (exitDirs.isNotEmpty) suffixParts.add('Exits: $exitDirs.');
    if (location.itemIds.isNotEmpty) {
      suffixParts.add('Items: ${location.itemIds.join(", ")}.');
    }
    if (location.npcIds.isNotEmpty) {
      suffixParts.add('NPCs: ${location.npcIds.join(", ")}.');
    }
    final suffix = suffixParts.isNotEmpty ? ' ${suffixParts.join(" ")}' : '';

    // Calculate remaining token budget for description.
    final prefixTokens = tokenEstimate(prefix);
    final suffixTokens = tokenEstimate(suffix);
    final descBudget = kLocationContextMaxTokens - prefixTokens - suffixTokens;

    var desc = location.description;
    if (descBudget <= 0) {
      // No room for description — return prefix + suffix only.
      return '$prefix$suffix';
    }

    if (tokenEstimate(desc) > descBudget) {
      // Truncate at nearest sentence boundary to fit budget.
      final maxChars = descBudget * _kCharsPerToken;
      if (desc.length > maxChars) {
        desc = desc.substring(0, maxChars);
        final lastPeriod = desc.lastIndexOf('.');
        if (lastPeriod > maxChars ~/ 2) {
          desc = desc.substring(0, lastPeriod + 1);
        }
      }
    }

    return '$prefix $desc$suffix';
  }

  /// Submit a player command and receive a stream of [GameTurn] updates.
  ///
  /// During generation, yields partial [GameTurn] objects with growing
  /// [narrativeText] and empty [suggestions]. The final emission has
  /// [isComplete] = true with parsed suggestions.
  ///
  /// The completed turn is automatically added to [history].
  Stream<GameTurn> submitCommand(String command) async* {
    _turnNumber++;
    final prompt = assemblePrompt(command);

    final buffer = StringBuffer();
    var currentTurn = GameTurn(
      turnNumber: _turnNumber,
      playerCommand: command,
      narrativeText: '',
    );

    await for (final token in _generate(
      prompt,
      maxTokens: maxResponseTokens,
      grammarFilePath: grammarFilePath,
    )) {
      buffer.write(token);
      final rawSoFar = buffer.toString();

      // During streaming, show narrative portion (before suggestion block).
      final parsed = parseResponse(rawSoFar);
      currentTurn = currentTurn.copyWith(
        narrativeText: parsed.narrative,
        rawResponse: rawSoFar,
      );
      yield currentTurn;
    }

    // Final parse with complete response.
    final rawResponse = buffer.toString();
    final parsed = parseResponse(rawResponse);
    final completeTurn = currentTurn.copyWith(
      narrativeText: parsed.narrative,
      suggestions: parsed.suggestions,
      rawResponse: rawResponse,
      isComplete: true,
    );

    _history.add(completeTurn);
    yield completeTurn;
  }

  /// Start the adventure with the default opening scene.
  ///
  /// Convenience wrapper around [submitCommand] using [kOpeningPrompt].
  Stream<GameTurn> startAdventure() {
    return submitCommand(kOpeningPrompt);
  }

  /// Assemble the full prompt from system prompt + history + current command.
  ///
  /// Respects [contextBudgetTokens] by trimming oldest turns when the
  /// assembled prompt would exceed the budget minus [maxResponseTokens].
  ///
  /// Prompt structure:
  /// ```
  /// System: [system prompt]
  ///
  /// CURRENT LOCATION: [name]. [description]. Exits: [...]. Items: [...]. NPCs: [...].
  ///
  /// Player: [past command]
  /// GM: [past response]
  ///
  /// [style anchor, after first turn]
  /// Player: [current command]
  /// GM:
  /// ```
  ///
  /// Exposed as a public method for testing.
  String assemblePrompt(String currentCommand) {
    final sections = <String>[];

    // System prompt always first.
    sections.add('System: $systemPrompt');

    // Location context block (BL-162): inject between system prompt and
    // history to ground model responses in the current room's actual data.
    if (_currentLocation != null) {
      sections.add(buildLocationContext(_currentLocation!));
    }

    // Build history entries as Player/GM pairs.
    final historyEntries = <String>[];
    for (final turn in _history) {
      historyEntries.add('Player: ${turn.playerCommand}\nGM: ${turn.rawResponse}');
    }

    // Calculate token budget for history (sliding context window).
    final systemTokens = tokenEstimate(sections.first);
    final locationTokens = _currentLocation != null
        ? tokenEstimate(buildLocationContext(_currentLocation!))
        : 0;
    final currentTurnText = _turnNumber > 1
        ? '$kStyleAnchor\nPlayer: $currentCommand\nGM:'
        : 'Player: $currentCommand\nGM:';
    final currentTokens = tokenEstimate(currentTurnText);
    // Reserve tokens for \n\n separators between sections. Worst case:
    // system + location + summary + 2 recent + anchor + current = 7 → 6 seps.
    const separatorOverhead = 6;
    final historyBudget = contextBudgetTokens -
        systemTokens -
        locationTokens -
        currentTokens -
        maxResponseTokens -
        separatorOverhead;

    // Build sliding context window: keep recent turns verbatim,
    // compress older turns into a narrative summary when over budget.
    final windowEntries = _buildHistoryWindow(historyEntries, historyBudget);
    sections.addAll(windowEntries);

    // Style anchor after first turn (BL-036 section 2.3: recency-bias).
    if (_turnNumber > 1) {
      sections.add(kStyleAnchor);
    }

    // Current player command + GM prompt marker.
    sections.add('Player: $currentCommand\nGM:');

    return sections.join('\n\n');
  }

  /// Parse a raw AI response into narrative text and suggestion strings.
  ///
  /// Expects format per the GBNF grammar (BL-049):
  /// ```
  /// [narrative text, may span lines but no double newlines]
  ///
  /// > 1. [suggestion]
  /// > 2. [suggestion]
  /// > 3. [suggestion]
  /// ```
  ///
  /// If suggestions cannot be parsed (e.g. during streaming, or the model
  /// didn't produce them), returns an empty suggestions list.
  ///
  /// This is a static method for easy standalone testing.
  static ({String narrative, List<String> suggestions}) parseResponse(
    String raw,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (narrative: '', suggestions: <String>[]);
    }

    // The GBNF grammar mandates a double newline between narrative and
    // suggestions. Split on the first occurrence.
    final splitIndex = trimmed.indexOf('\n\n');
    if (splitIndex < 0) {
      // No double newline yet — still streaming narrative.
      return (narrative: trimmed, suggestions: <String>[]);
    }

    final narrative = trimmed.substring(0, splitIndex).trim();
    final remainder = trimmed.substring(splitIndex + 2);

    // Parse suggestion lines: "> N. text"
    final pattern = RegExp(r'>\s*(\d+)\.\s*(.+)');
    final suggestions = pattern
        .allMatches(remainder)
        .map((m) => m.group(2)!.trim())
        .toList();

    // When structured suggestions were successfully parsed from the
    // suggestion block, strip any duplicate numbered-action lines that the
    // model leaked into the narrative (BL-274 / BL-277).
    final cleanedNarrative = suggestions.isNotEmpty
        ? _stripNumberedActions(narrative)
        : narrative;

    return (narrative: cleanedNarrative, suggestions: suggestions);
  }

  /// Remove numbered-action lines that duplicate the structured suggestion
  /// block from the narrative text.
  ///
  /// Matches lines starting with optional whitespace followed by a digit and
  /// either `)` or `.` — e.g. `1. Explore the cave` or `2) Go north`.
  /// This catches the common LLM failure mode of listing actions both inline
  /// in the narrative AND in the structured suggestion block.
  ///
  /// **Safety fallback:** if stripping would remove ALL lines (meaning the
  /// entire narrative is numbered items — likely intentional prose such as a
  /// list of clues), the original narrative is returned unchanged.
  static String _stripNumberedActions(String narrative) {
    final pattern = RegExp(r'^\s*\d+[.)]\s');
    final lines = narrative.split('\n');
    final filtered = lines.where((line) => !pattern.hasMatch(line)).toList();

    // Safety: if every line matched, the "numbered" content is probably
    // intentional prose (e.g. "3 torches line the wall"). Preserve it.
    if (filtered.isEmpty) {
      return narrative;
    }

    return filtered.join('\n').trim();
  }

  /// Reset the session, clearing all history and turn count.
  void reset() {
    _history.clear();
    _turnNumber = 0;
  }

  // ─── Persistence (BL-118) ────────────────────────────────────────────────

  /// Serialize and write the current session state to [filePath].
  ///
  /// The JSON contains the adventure ID (for matching on restore), turn
  /// count, full turn history, and a UTC timestamp. Called automatically
  /// after each completed turn and when the app enters background.
  Future<void> saveState(String filePath, {String? adventureId}) async {
    final data = <String, dynamic>{
      'adventureId': adventureId,
      'turnNumber': _turnNumber,
      'turns': _history.map((t) => t.toJson()).toList(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  /// Read and parse save data from [filePath].
  ///
  /// Returns `null` if the file does not exist or is corrupted. The caller
  /// should inspect `adventureId` to decide whether to offer 'Continue'.
  static Future<Map<String, dynamic>?> loadSaveData(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      if (json is Map<String, dynamic>) return json;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Restore internal state from save data produced by [saveState].
  ///
  /// Replaces current history and turn counter. Call on a freshly
  /// constructed [GameSession] before the first [submitCommand].
  void restoreFromSaveData(Map<String, dynamic> data) {
    _turnNumber = data['turnNumber'] as int? ?? 0;
    final turnsList = data['turns'] as List<dynamic>? ?? [];
    _history.clear();
    for (final entry in turnsList) {
      _history.add(GameTurn.fromJson(entry as Map<String, dynamic>));
    }
  }

  /// Delete the save file at [filePath], if it exists.
  static Future<void> deleteSave(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // ─── Public helpers ──────────────────────────────────────────────────────

  /// Estimate token count for a given text string.
  ///
  /// Uses a chars-per-token ratio (~4 chars/token for English text,
  /// calibrated against typical LLM tokenizers). Returns an integer
  /// approximation suitable for context budget calculations on
  /// resource-constrained devices.
  ///
  /// Example:
  /// ```dart
  /// final tokens = GameSession.tokenEstimate('Hello, adventurer!');
  /// // tokens ≈ 5
  /// ```
  static int tokenEstimate(String text) =>
      text.isEmpty ? 0 : (text.length / _kCharsPerToken).ceil();

  // ─── Private helpers ─────────────────────────────────────────────────────

  /// Build the history section for prompt assembly with a sliding context
  /// window.
  ///
  /// Always preserves the [kRecentTurnsToKeep] most recent entries verbatim
  /// (Player/GM pairs). When older entries would exceed the remaining token
  /// budget, compresses them into a single "Story so far: ..." summary line
  /// by concatenating their narrative text, truncated to fit.
  ///
  /// This prevents context overflow on small on-device models (2048–4096
  /// tokens) during long play sessions while preserving the most relevant
  /// recent context for coherent AI responses.
  List<String> _buildHistoryWindow(
    List<String> entries,
    int budgetTokens,
  ) {
    if (entries.isEmpty || budgetTokens <= 0) return [];

    // Determine how many recent turns to keep verbatim.
    final recentCount = entries.length < kRecentTurnsToKeep
        ? entries.length
        : kRecentTurnsToKeep;
    final recentEntries = entries.sublist(entries.length - recentCount);

    // Calculate tokens needed for recent entries.
    var recentTokens = 0;
    for (final entry in recentEntries) {
      recentTokens += tokenEstimate(entry);
    }

    // If even recent entries exceed budget, keep only what fits from newest.
    if (recentTokens > budgetTokens) {
      final result = <String>[];
      var used = 0;
      for (var i = recentEntries.length - 1; i >= 0; i--) {
        final tokens = tokenEstimate(recentEntries[i]);
        if (used + tokens > budgetTokens) break;
        result.insert(0, recentEntries[i]);
        used += tokens;
      }
      return result;
    }

    // If no older entries exist, return recent.
    if (entries.length <= recentCount) return recentEntries;

    final olderEntries = entries.sublist(0, entries.length - recentCount);

    // Check if all history fits within budget.
    var olderTokens = 0;
    for (final entry in olderEntries) {
      olderTokens += tokenEstimate(entry);
    }
    if (recentTokens + olderTokens <= budgetTokens) return entries;

    // ── Compression: summarize older turns ──
    final remainingBudget = budgetTokens - recentTokens;
    if (remainingBudget <= 0) return recentEntries;

    // Extract narrative text from older GameTurn objects.
    final olderTurnCount = _history.length - recentCount;
    final narratives = <String>[];
    for (var i = 0; i < olderTurnCount && i < _history.length; i++) {
      final narrative = _history[i].narrativeText;
      if (narrative.isNotEmpty) {
        narratives.add(narrative);
      }
    }

    if (narratives.isEmpty) return recentEntries;

    const summaryPrefix = 'Story so far: ';
    final fullSummary = '$summaryPrefix${narratives.join(' ')}';

    // Truncate summary to fit remaining token budget.
    final maxChars = remainingBudget * _kCharsPerToken;
    final summary = fullSummary.length > maxChars
        ? fullSummary.substring(0, maxChars)
        : fullSummary;

    return [summary, ...recentEntries];
  }
}
