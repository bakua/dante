/// Orchestrator widget wiring [TerminalGameScreen] (BL-160) to [GameSession]
/// (BL-147) with configurable inference backend (BL-177).
///
/// This is the integration layer connecting individually-tested components
/// into a playable game loop:
/// - Player types command → [GameSession.submitCommand] → AI generates response
/// - Response streams through typewriter animation in [TerminalGameScreen]
/// - Suggestions extracted from completed turns → displayed as tappable chips
///
/// Supports both real on-device inference and mock backends via the
/// [generateFunction] parameter.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/adventure_data.dart';
import '../screens/terminal_game_screen.dart';
import '../services/adventure_loader.dart';
import '../services/game_assets.dart';
import '../services/game_session.dart';

/// Widget that orchestrates the connection between game logic and display.
///
/// Accepts a [GenerateFunction] for the inference backend (real or mock)
/// and wires it through [GameSession] to [TerminalGameScreen].
///
/// Usage:
/// ```dart
/// // Mock backend (desktop / CI / demo)
/// GameOrchestrator(
///   generateFunction: MockInferenceBackend().generate,
/// )
///
/// // Real backend (device with model loaded)
/// GameOrchestrator(
///   generateFunction: inferenceService.generate,
/// )
/// ```
class GameOrchestrator extends StatefulWidget {
  /// The text generation function — real [InferenceService.generate] or
  /// [MockInferenceBackend.generate].
  final GenerateFunction generateFunction;

  /// Adventure ID to load from bundled assets.
  final String adventureId;

  const GameOrchestrator({
    super.key,
    required this.generateFunction,
    this.adventureId = 'sunken_archive',
  });

  @override
  State<GameOrchestrator> createState() => GameOrchestratorState();
}

/// State for [GameOrchestrator].
///
/// Exposed as a public type so integration tests can access [gameSession]
/// and verify game state.
class GameOrchestratorState extends State<GameOrchestrator> {
  final _screenKey = GlobalKey<TerminalGameScreenState>();
  final AdventureLoader _adventureLoader = AdventureLoader();
  final GameAssets _gameAssets = GameAssets();

  GameSession? _gameSession;
  AdventureData? _adventure;
  Stream<String>? _currentResponseStream;
  List<String> _suggestions = [];
  bool _isProcessing = false;

  /// The active game session, or null if not yet initialized.
  ///
  /// Exposed for testing.
  GameSession? get gameSession => _gameSession;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Load adventure data and game assets, create game session, and
  /// auto-generate the opening scene.
  Future<void> _initialize() async {
    try {
      // Load adventure scenario and game master assets
      _adventure = await _adventureLoader.load(widget.adventureId);
      final assets = await _gameAssets.loadAll();

      // Build enriched system prompt with adventure context
      final systemPrompt = _buildSystemPrompt(assets.prompt, _adventure!);

      // Create GameSession wired to the provided generate function
      _gameSession = GameSession(
        systemPrompt: systemPrompt,
        generate: widget.generateFunction,
      );

      // Set starting location for context injection (BL-162)
      final startLoc = _adventure!.getLocation(_adventure!.startLocationId);
      if (startLoc != null) {
        _gameSession!.setLocation(startLoc);
      }

      // Notify the display of adventure info
      _screenKey.currentState?.addMessage(
        TerminalMessage(
          _adventure!.title.toUpperCase(),
          isSystem: true,
        ),
      );
      _screenKey.currentState?.addMessage(
        const TerminalMessage('', isSystem: true),
      );

      // Auto-generate opening scene
      _startAdventure();
    } catch (e) {
      _screenKey.currentState?.addMessage(
        TerminalMessage('[ERR] Failed to load adventure: $e', isSystem: true),
      );
    }
  }

  /// Generate the opening scene via [GameSession.startAdventure].
  void _startAdventure() {
    if (_gameSession == null) return;
    final turnStream = _gameSession!.startAdventure();
    _setResponseStream(turnStream);
  }

  /// Transform a [GameTurn] stream into a [String] token stream for display.
  ///
  /// Each [GameTurn] emission contains a growing [GameTurn.narrativeText].
  /// This method computes the delta (new characters since last emission) and
  /// forwards them to a [StreamController] that [TerminalGameScreen] consumes
  /// for its typewriter animation.
  ///
  /// When a turn is complete ([GameTurn.isComplete]), suggestions are
  /// extracted and set via [setState], which triggers a rebuild that passes
  /// them to [TerminalGameScreen.suggestions].
  void _setResponseStream(Stream<GameTurn> turnStream) {
    final controller = StreamController<String>();
    int lastNarrLen = 0;

    final sub = turnStream.listen(
      (turn) {
        // Emit only the delta text (new characters since last emission)
        final narr = turn.narrativeText;
        if (narr.length > lastNarrLen) {
          controller.add(narr.substring(lastNarrLen));
          lastNarrLen = narr.length;
        }

        // When turn completes, extract suggestions for display
        if (turn.isComplete && mounted) {
          setState(() {
            _suggestions = List.unmodifiable(turn.suggestions);
            _isProcessing = false;
          });
        }
      },
      onDone: () => controller.close(),
      onError: (Object e) {
        controller.addError(e);
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      },
    );

    // Cancel upstream subscription when downstream is cancelled
    controller.onCancel = () => sub.cancel();

    setState(() {
      _currentResponseStream = controller.stream;
      _suggestions = [];
      _isProcessing = true;
    });
  }

  /// Handle player command: forward to [GameSession] and wire response stream.
  void _onCommand(String command) {
    if (_gameSession == null || _isProcessing) return;

    final turnStream = _gameSession!.submitCommand(command);
    _setResponseStream(turnStream);
  }

  /// Build system prompt enriched with adventure context.
  ///
  /// Mirrors the logic from the existing [TerminalScreen._buildSystemPrompt]
  /// for consistency across both code paths.
  String _buildSystemPrompt(String basePrompt, AdventureData adventure) {
    final startLocation = adventure.getLocation(adventure.startLocationId);
    final buffer = StringBuffer(basePrompt);
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('ADVENTURE: ${adventure.title}');
    buffer.writeln('SETTING: ${adventure.theme}');
    if (startLocation != null) {
      buffer.writeln(
        'CURRENT LOCATION: ${startLocation.name} \u2014 '
        '${startLocation.description}',
      );
    }
    if (adventure.startInventory.isNotEmpty) {
      final itemNames = adventure.startInventory
          .map((id) => adventure.getItem(id)?.name ?? id)
          .join(', ');
      buffer.writeln('PLAYER INVENTORY: $itemNames');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalGameScreen(
      key: _screenKey,
      responseStream: _currentResponseStream,
      onCommand: _onCommand,
      suggestions: _suggestions,
      initialMessages: const [
        TerminalMessage('DANTE TERMINAL v0.2.0', isSystem: true),
        TerminalMessage(
          '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501'
          '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501'
          '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501'
          '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501',
          isSystem: true,
        ),
        TerminalMessage('AI-powered text adventure', isSystem: true),
        TerminalMessage('Powered by on-device LLM', isSystem: true),
        TerminalMessage('', isSystem: true),
        TerminalMessage('Loading adventure...', isSystem: true),
      ],
    );
  }
}
