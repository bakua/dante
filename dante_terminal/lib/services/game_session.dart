/// Game session service managing turn history, prompt assembly, and suggestion
/// parsing for DANTE TERMINAL.
///
/// This is the 'controller' layer between the UI (BL-039) and the inference
/// engine (BL-038). It consumes player input strings and produces structured
/// [GameTurn] objects containing narrative text and suggestions.
///
/// Ported from prototype/dante_cli.py's GameSession class. Designed as a pure
/// Dart class with no Flutter UI dependencies for independent unit testing.
///
/// See also:
/// - BL-010: GM prompt patterns (system prompt + anchor note strategy)
/// - BL-036: Small-model prompting techniques (recency-bias exploitation)
/// - BL-049: GBNF grammar for structured output enforcement
library;

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

    // Build history entries as Player/GM pairs.
    final historyEntries = <String>[];
    for (final turn in _history) {
      historyEntries.add('Player: ${turn.playerCommand}\nGM: ${turn.rawResponse}');
    }

    // Calculate token budget for history.
    final systemTokens = _estimateTokens(sections.first);
    final currentTurnText = _turnNumber > 1
        ? '$kStyleAnchor\nPlayer: $currentCommand\nGM:'
        : 'Player: $currentCommand\nGM:';
    final currentTokens = _estimateTokens(currentTurnText);
    final historyBudget =
        contextBudgetTokens - systemTokens - currentTokens - maxResponseTokens;

    // Add history from most recent, trimming oldest if over budget.
    final trimmedHistory = _trimHistory(historyEntries, historyBudget);
    sections.addAll(trimmedHistory);

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

    return (narrative: narrative, suggestions: suggestions);
  }

  /// Reset the session, clearing all history and turn count.
  void reset() {
    _history.clear();
    _turnNumber = 0;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /// Estimate token count from text length (~4 chars per token).
  static int _estimateTokens(String text) =>
      (text.length / _kCharsPerToken).ceil();

  /// Select history entries that fit within a token budget.
  ///
  /// Keeps the most recent entries, trimming from the oldest.
  /// Each entry is a "Player: ...\nGM: ..." pair.
  List<String> _trimHistory(List<String> entries, int budgetTokens) {
    if (entries.isEmpty || budgetTokens <= 0) return [];

    final result = <String>[];
    var usedTokens = 0;

    // Walk backwards from most recent to oldest.
    for (var i = entries.length - 1; i >= 0; i--) {
      final entryTokens = _estimateTokens(entries[i]);
      if (usedTokens + entryTokens > budgetTokens) break;
      result.insert(0, entries[i]);
      usedTokens += entryTokens;
    }

    return result;
  }
}
