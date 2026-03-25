/// Mock inference backend for CI, desktop development, and demo mode (BL-177).
///
/// Provides a [GenerateFunction]-compatible implementation that returns
/// canned interactive fiction responses without requiring a downloaded
/// GGUF model file. Responses follow the GBNF grammar format: narrative
/// text followed by a double newline and 3 numbered action suggestions.
///
/// Usage:
/// ```dart
/// final mock = MockInferenceBackend();
/// final session = GameSession(
///   systemPrompt: 'You are the Game Master...',
///   generate: mock.generate,
/// );
/// ```
library;

/// Canned interactive fiction responses formatted per the GBNF grammar:
/// narrative text + "\n\n" + "> N. suggestion" × 3.
///
/// Each response is a self-contained scene from a dungeon-crawl adventure,
/// designed to feel authentic when cycled through during mock play.
const List<String> kMockResponses = [
  // Opening scene
  'You awaken on cold, damp stone. The air tastes of dust and ancient '
      'parchment. A flickering oil lamp rests in your hand, its amber glow '
      'revealing crumbling walls covered in faded glyphs. Rubble chokes the '
      'stairway above \u2014 no going back that way.'
      '\n\n'
      '> 1. Examine the glyphs on the walls\n'
      '> 2. Head north through the stone archway\n'
      '> 3. Search the rubble for anything useful',

  // Exploration
  'The corridor stretches ahead, its vaulted ceiling lost in shadow. '
      'Bioluminescent fungus clings to the stones overhead, casting an eerie '
      'blue-green glow that makes your shadow dance. Water drips somewhere '
      'ahead in a steady, hypnotic rhythm.'
      '\n\n'
      '> 1. Follow the sound of dripping water\n'
      '> 2. Examine the luminous fungus closely\n'
      '> 3. Continue cautiously down the corridor',

  // Discovery
  'Your fingers trace the carved stone and find a hidden seam. With a '
      'grinding protest, a section of wall pivots inward, revealing a narrow '
      'alcove. Inside, a brass key gleams atop a dusty leather journal. The '
      'air here smells of cedar and old ink.'
      '\n\n'
      '> 1. Take the brass key\n'
      '> 2. Open the leather journal\n'
      '> 3. Examine the alcove for traps',

  // Encounter
  'A pale figure materializes at the edge of your lamplight \u2014 '
      'translucent, flickering like a candle flame. The ghost of an archivist, '
      'spectacles perched on a nose that barely exists. It regards you with '
      'hollow eyes and speaks in a voice like rustling pages.'
      '\n\n'
      '> 1. Ask the ghost about this place\n'
      '> 2. Show the journal to the apparition\n'
      '> 3. Back away slowly',

  // Tension
  'The water rises to your ankles as you press deeper into the flooded '
      'passage. Something slithers past your leg beneath the black surface. '
      'Your lamp gutters, threatening to die. Ahead, a faint phosphorescent '
      'glow promises dry ground \u2014 if you can reach it.'
      '\n\n'
      '> 1. Wade forward toward the glow\n'
      '> 2. Use the lamp to peer into the water\n'
      '> 3. Retreat to higher ground',

  // Resolution
  'The ancient lock yields to the brass key with a satisfying click. The '
      'vault door swings open on silent hinges, revealing shelves of '
      'crystalline tablets glowing with inner fire. Each one holds a story '
      '\u2014 a memory of a world long drowned. You have found the heart of '
      'the Archive.'
      '\n\n'
      '> 1. Read the nearest crystal tablet\n'
      '> 2. Search for the master codex\n'
      '> 3. Look for another exit from the vault',
];

/// Mock inference backend producing canned interactive fiction responses.
///
/// Designed for running the full game loop without a GGUF model file,
/// enabling CI testing, desktop development, and demo mode. Responses
/// cycle through [kMockResponses] and are streamed in small chunks to
/// simulate real token-by-token inference pacing.
class MockInferenceBackend {
  int _responseIndex = 0;

  /// Generate a response compatible with the `GenerateFunction` typedef.
  ///
  /// Streams small character chunks with short delays to simulate
  /// real inference token generation pacing. Cycles through [kMockResponses].
  ///
  /// The [prompt], [maxTokens], and [grammarFilePath] parameters are accepted
  /// for API compatibility but ignored — the mock always returns the next
  /// canned response in sequence.
  Stream<String> generate(
    String prompt, {
    int maxTokens = 256,
    String? grammarFilePath,
  }) async* {
    // Brief initial delay to simulate model processing latency
    await Future.delayed(const Duration(milliseconds: 20));

    final response = kMockResponses[_responseIndex % kMockResponses.length];
    _responseIndex++;

    // Stream in small chunks to simulate token-by-token generation.
    // Chunk size of 4 chars ≈ 1 token at the ~4 chars/token heuristic.
    const chunkSize = 4;
    for (var i = 0; i < response.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, response.length);
      yield response.substring(i, end);
      await Future.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Reset the response cycle index to the beginning.
  ///
  /// Useful for deterministic testing.
  void reset() {
    _responseIndex = 0;
  }
}
