import 'package:flutter/services.dart' show rootBundle;

/// Asset paths for bundled Game Master resources.
const kGameMasterPromptAsset = 'assets/game_master_prompt.txt';
const kGameMasterGrammarAsset = 'assets/game_master.gbnf';

/// Loads bundled Game Master assets from the Flutter asset bundle.
///
/// These files originate from the prototype/ directory (BL-043, BL-049) and
/// are bundled into the app so that [GameSession] and [InferenceService] can
/// access them without filesystem paths or network fetches.
class GameAssets {
  String? _cachedPrompt;
  String? _cachedGrammar;

  /// Load the Game Master system prompt from bundled assets.
  ///
  /// Returns the contents of `assets/game_master_prompt.txt`.
  /// Caches the result after the first load.
  Future<String> loadSystemPrompt() async {
    _cachedPrompt ??= await rootBundle.loadString(kGameMasterPromptAsset);
    return _cachedPrompt!;
  }

  /// Load the GBNF grammar for structured Game Master output.
  ///
  /// Returns the contents of `assets/game_master.gbnf`.
  /// Caches the result after the first load.
  Future<String> loadGrammar() async {
    _cachedGrammar ??= await rootBundle.loadString(kGameMasterGrammarAsset);
    return _cachedGrammar!;
  }

  /// Load both assets and return them as a record.
  ///
  /// Convenience method for callers that need both at once (e.g. GameSession).
  Future<({String prompt, String grammar})> loadAll() async {
    final results = await Future.wait([loadSystemPrompt(), loadGrammar()]);
    return (prompt: results[0], grammar: results[1]);
  }

  /// Clear cached assets (useful for testing or hot-reload scenarios).
  void clearCache() {
    _cachedPrompt = null;
    _cachedGrammar = null;
  }
}
