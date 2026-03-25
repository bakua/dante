import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'models/adventure_data.dart';
import 'screens/benchmark_screen.dart';
import 'services/adventure_loader.dart';
import 'services/game_assets.dart';
import 'services/game_session.dart';
import 'services/inference_service.dart';
import 'services/performance_metrics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DanteTerminalApp());
}

class DanteTerminalApp extends StatelessWidget {
  const DanteTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DANTE TERMINAL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00FF41),
          surface: const Color(0xFF0A0A0A),
        ),
      ),
      home: const TerminalScreen(),
    );
  }
}

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  final InferenceService _inference = InferenceService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_TerminalLine> _lines = [];
  bool _isGenerating = false;
  InferenceMetrics? _lastMetrics;

  // Game services (initialized after model load)
  final AdventureLoader _adventureLoader = AdventureLoader();
  final GameAssets _gameAssets = GameAssets();
  GameSession? _gameSession;
  AdventureData? _adventure;
  List<String> _currentSuggestions = [];
  String? _grammarTempPath;

  /// Path to the save file in app documents directory (BL-118).
  String? _saveFilePath;

  /// Adventure ID used for save/restore matching.
  String? _adventureId;

  /// True while waiting for user to choose Continue vs New Adventure.
  bool _awaitingResumeChoice = false;

  /// Cached save data when offering the resume choice.
  Map<String, dynamic>? _pendingSaveData;

  static const _terminalGreen = Color(0xFF00FF41);
  static const _terminalDim = Color(0xFF00AA2A);
  static const _metricsColor = Color(0xFF00886A);
  static const _suggestionColor = Color(0xFF00CC55);

  /// Save file name within app documents directory.
  static const _kSaveFileName = 'dante_save.json';

  /// Typewriter pacing: milliseconds between each displayed character.
  static const _typewriterDelayMs = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addLine('DANTE TERMINAL v0.2.0', isHeader: true);
    _addLine('\u2500' * 40);
    _addLine('> AI-powered text adventure');
    _addLine('> Powered by on-device LLM');
    _addLine('> Runs entirely offline');
    _addLine('');
    _initEngine();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _autoSave();
    }
  }

  /// Persist current game state to disk (BL-118).
  Future<void> _autoSave() async {
    final session = _gameSession;
    final path = _saveFilePath;
    if (session == null || path == null) return;
    if (session.history.isEmpty) return;
    try {
      await session.saveState(path, adventureId: _adventureId);
    } catch (_) {
      // Best-effort save; don't crash the app.
    }
  }

  Future<void> _initEngine() async {
    // Resolve save file path early (BL-118).
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      _saveFilePath = '${docsDir.path}/$_kSaveFileName';
    } catch (_) {
      // path_provider may fail in test harnesses; continue without save.
    }

    _addLine('[SYS] Initializing inference engine...');
    try {
      await _inference.initialize();
      _addLine('[SYS] Backend ready.');

      // Try to auto-load a model
      _addLine('[SYS] Searching for model file...');
      try {
        final modelPath = await _inference.loadModel();
        _addLine('[SYS] Model loaded: ${modelPath.split('/').last}');

        // Check for saved game before starting fresh (BL-118).
        await _checkForSavedGame();

        setState(() {});
      } catch (e) {
        final modelDir = await _inference.getModelDirectory();
        _addLine('[SYS] No model found. Copy a .gguf file to:');
        _addLine('      $modelDir/model.gguf');
        _addLine('[SYS] Engine initialized but model not loaded.');
      }
    } catch (e) {
      _addLine('[ERR] Engine initialization failed: $e');
    }
  }

  /// Check for an existing save file and offer resume or new game (BL-118).
  Future<void> _checkForSavedGame() async {
    final path = _saveFilePath;
    if (path == null) {
      await _initGameSession();
      return;
    }

    final saveData = await GameSession.loadSaveData(path);
    if (saveData != null) {
      final turnCount = saveData['turnNumber'] as int? ?? 0;
      final savedAdventure = saveData['adventureId'] as String? ?? 'unknown';
      _addLine('');
      _addLine('[SYS] Saved game found: $savedAdventure (Turn $turnCount)');
      _addLine('');
      _addLine('  1. Continue adventure');
      _addLine('  2. New adventure');
      _addLine('');
      _addLine('[SYS] Type 1 or 2 to choose.');
      _pendingSaveData = saveData;
      setState(() => _awaitingResumeChoice = true);
    } else {
      await _initGameSession();
    }
  }

  /// Restore a GameSession from saved data (BL-118).
  Future<void> _restoreGameSession(Map<String, dynamic> saveData) async {
    try {
      _addLine('[SYS] Restoring saved game...');

      final savedAdventureId = saveData['adventureId'] as String? ?? 'sunken_archive';
      _adventureId = savedAdventureId;

      // Load adventure and assets (same as _initGameSession)
      _adventure = await _adventureLoader.load(savedAdventureId);
      final assets = await _gameAssets.loadAll();

      final docsDir = await getApplicationDocumentsDirectory();
      _grammarTempPath = '${docsDir.path}/game_master.gbnf';
      await File(_grammarTempPath!).writeAsString(assets.grammar);

      final systemPrompt = _buildSystemPrompt(assets.prompt, _adventure!);

      _gameSession = GameSession(
        systemPrompt: systemPrompt,
        generate: _inference.generate,
        grammarFilePath: _grammarTempPath,
      );

      // Restore turn history into the session.
      _gameSession!.restoreFromSaveData(saveData);

      // Display adventure header
      _addLine('');
      _addLine('\u2550' * 40);
      _addLine('  ${_adventure!.title.toUpperCase()}');
      _addLine('\u2550' * 40);
      _addLine('');

      // Show the last turn's narrative and suggestions so the player
      // has context for what was happening.
      final history = _gameSession!.history;
      if (history.isNotEmpty) {
        final lastTurn = history.last;
        _addLine(lastTurn.narrativeText);
        _displaySuggestions(lastTurn.suggestions);
        _addLine('');
        _addLine('[SYS] Game restored at turn ${lastTurn.turnNumber}. '
            'What do you do?');
      }
    } catch (e) {
      _addLine('[ERR] Restore failed: $e');
      _addLine('[SYS] Starting new adventure instead...');
      await _initGameSession();
    }
  }

  /// Load adventure data and assets, create [GameSession], generate opening.
  Future<void> _initGameSession() async {
    try {
      _addLine('[SYS] Loading adventure...');

      // Load adventure scenario data from bundled JSON
      _adventureId = 'sunken_archive';
      _adventure = await _adventureLoader.load(_adventureId!);
      _addLine('[SYS] Adventure: ${_adventure!.title}');

      // Load system prompt and grammar from bundled assets
      final assets = await _gameAssets.loadAll();

      // Write grammar to filesystem for InferenceService (needs file path)
      final docsDir = await getApplicationDocumentsDirectory();
      _grammarTempPath = '${docsDir.path}/game_master.gbnf';
      await File(_grammarTempPath!).writeAsString(assets.grammar);

      // Build enriched system prompt with adventure context
      final systemPrompt = _buildSystemPrompt(assets.prompt, _adventure!);

      // Create GameSession wired to InferenceService.generate
      _gameSession = GameSession(
        systemPrompt: systemPrompt,
        generate: _inference.generate,
        grammarFilePath: _grammarTempPath,
      );

      // Display adventure header
      _addLine('');
      _addLine('\u2550' * 40);
      _addLine('  ${_adventure!.title.toUpperCase()}');
      _addLine('\u2550' * 40);
      _addLine('');

      // Auto-generate opening scene without waiting for user input
      await _generateOpeningScene();
    } catch (e) {
      _addLine('[ERR] Game session init failed: $e');
      _addLine('[SYS] Ready in raw prompt mode. Type a prompt and press Enter.');
    }
  }

  /// Build system prompt enriched with adventure context.
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

  /// Generate the opening scene via [GameSession] with typewriter animation.
  Future<void> _generateOpeningScene() async {
    setState(() {
      _isGenerating = true;
      _currentSuggestions = [];
    });

    try {
      // Use the adventure's opening narrative as context for the LLM
      final openingCommand = _adventure?.openingNarrative != null
          ? 'Begin the adventure. ${_adventure!.openingNarrative} '
              'Describe what the player sees and suggest 3 actions.'
          : kOpeningPrompt;

      final result = await _typewriteGameResponse(
        _gameSession!.submitCommand(openingCommand),
      );

      if (result.turn != null && result.turn!.isComplete) {
        _displaySuggestions(result.turn!.suggestions);
        _captureMetrics(
          ttftMs: result.ttftMs,
          tokenCount: result.tokenCount,
          totalTimeMs: result.totalTimeMs,
          rawResponse: result.turn!.rawResponse,
        );
      }
    } catch (e) {
      _addLine('[ERR] Opening scene generation failed: $e');
      _addLine('[SYS] Type a command to try again.');
    }

    setState(() => _isGenerating = false);
  }

  /// Display parsed suggestions in the terminal and as interactive chips.
  void _displaySuggestions(List<String> suggestions) {
    if (suggestions.isNotEmpty) {
      _addLine('');
      for (var i = 0; i < suggestions.length; i++) {
        _addLine('  ${i + 1}. ${suggestions[i]}', isSuggestion: true);
      }
    }
    setState(() {
      _currentSuggestions = suggestions;
    });
  }

  /// Submit a suggestion as a player command.
  void _onSuggestionTap(String suggestion) {
    _inputController.text = suggestion;
    _onSubmit();
  }

  /// Capture performance metrics for /metrics command.
  void _captureMetrics({
    int? ttftMs,
    required int tokenCount,
    required int totalTimeMs,
    required String rawResponse,
  }) {
    final metrics = InferenceMetrics(
      modelName: _inference.loadedModelPath?.split('/').last ?? 'unknown',
      ttftMs: ttftMs ?? totalTimeMs,
      tokenCount: tokenCount,
      totalTimeMs: totalTimeMs,
      peakMemoryMB: null,
      responseText: rawResponse,
    );
    _lastMetrics = metrics;

    if (tokenCount > 0) {
      _addLine(
        '[PERF] TTFT: ${metrics.ttftSeconds.toStringAsFixed(2)}s | '
        '${metrics.tokensPerSecond.toStringAsFixed(1)} tok/s | '
        '$tokenCount tokens in ${totalTimeMs}ms',
        isMetric: true,
      );
    }
  }

  /// Scroll the terminal output to the bottom after the next frame renders.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addLine(
    String text, {
    bool isHeader = false,
    bool isMetric = false,
    bool isSuggestion = false,
  }) {
    setState(() {
      _lines.add(_TerminalLine(
        text,
        isHeader: isHeader,
        isMetric: isMetric,
        isSuggestion: isSuggestion,
      ));
    });
    _scrollToBottom();
  }

  /// Stream a [GameSession] response with concurrent typewriter animation.
  ///
  /// A producer task collects tokens from the stream at inference speed while
  /// a consumer task displays characters one-by-one at [_typewriterDelayMs]
  /// pacing. This allows the LLM to generate at full speed while the terminal
  /// reveals text with an authentic typewriter feel.
  Future<({GameTurn? turn, int tokenCount, int? ttftMs, int totalTimeMs})>
      _typewriteGameResponse(Stream<GameTurn> turns) async {
    final pendingChars = <String>[];
    var producerDone = false;
    GameTurn? completeTurn;
    int tokenCount = 0;
    int? ttftMs;
    int lastNarrLen = 0;
    final stopwatch = Stopwatch()..start();
    Object? producerError;

    // Add empty line that will be progressively filled
    final lineIdx = _lines.length;
    setState(() => _lines.add(_TerminalLine('')));

    // Producer: collect tokens from the GameSession stream at full speed
    final producerFuture = () async {
      try {
        await for (final turn in turns) {
          final narr = turn.narrativeText;
          if (narr.length > lastNarrLen) {
            pendingChars.addAll(narr.substring(lastNarrLen).split(''));
            lastNarrLen = narr.length;
          }
          if (turn.isComplete) {
            completeTurn = turn;
          } else {
            ttftMs ??= stopwatch.elapsedMilliseconds;
            tokenCount++;
          }
        }
      } catch (e) {
        producerError = e;
      }
      stopwatch.stop();
      producerDone = true;
    }();

    // Consumer: reveal characters at typewriter pace
    final displayBuf = StringBuffer();
    while (!producerDone || pendingChars.isNotEmpty) {
      if (!mounted || producerError != null) break;
      if (pendingChars.isNotEmpty) {
        displayBuf.write(pendingChars.removeAt(0));
        setState(() {
          _lines[lineIdx] = _TerminalLine(displayBuf.toString());
        });
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: _typewriterDelayMs));
      } else {
        // Yield to event loop while waiting for more characters
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    await producerFuture;
    if (producerError != null) throw producerError!;

    return (
      turn: completeTurn,
      tokenCount: tokenCount,
      ttftMs: ttftMs,
      totalTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Stream raw inference tokens with typewriter animation (fallback path).
  ///
  /// Used when no [GameSession] is available — renders raw
  /// [InferenceService.generate] output with the same typewriter pacing.
  Future<
      ({
        String response,
        int tokenCount,
        int? ttftMs,
        int totalTimeMs,
        double? peakMem,
      })> _typewriteRawResponse(Stream<String> tokenStream) async {
    final pendingChars = <String>[];
    var producerDone = false;
    int tokenCount = 0;
    int? ttftMs;
    double? peakMem = getCurrentMemoryMB();
    final stopwatch = Stopwatch()..start();
    Object? producerError;

    // Add empty line for streaming text
    final lineIdx = _lines.length;
    setState(() => _lines.add(_TerminalLine('')));

    // Producer: collect raw tokens at inference speed
    final producerFuture = () async {
      try {
        await for (final token in tokenStream) {
          ttftMs ??= stopwatch.elapsedMilliseconds;
          pendingChars.addAll(token.split(''));
          tokenCount++;
          if (tokenCount % 20 == 0) {
            final mem = getCurrentMemoryMB();
            final peak = peakMem;
            if (mem != null && (peak == null || mem > peak)) {
              peakMem = mem;
            }
          }
        }
      } catch (e) {
        producerError = e;
      }
      stopwatch.stop();
      producerDone = true;
    }();

    // Consumer: display at typewriter pace
    final displayBuf = StringBuffer();
    while (!producerDone || pendingChars.isNotEmpty) {
      if (!mounted || producerError != null) break;
      if (pendingChars.isNotEmpty) {
        displayBuf.write(pendingChars.removeAt(0));
        setState(() {
          _lines[lineIdx] = _TerminalLine(displayBuf.toString());
        });
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: _typewriterDelayMs));
      } else {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    await producerFuture;
    if (producerError != null) throw producerError!;

    return (
      response: displayBuf.toString(),
      tokenCount: tokenCount,
      ttftMs: ttftMs,
      totalTimeMs: stopwatch.elapsedMilliseconds,
      peakMem: peakMem,
    );
  }

  Future<void> _onSubmit() async {
    final command = _inputController.text.trim();
    if (command.isEmpty || _isGenerating) return;

    _inputController.clear();
    _addLine('');
    _addLine('> $command');

    // ── Handle Continue vs New Adventure choice (BL-118) ──
    if (_awaitingResumeChoice) {
      await _handleResumeChoice(command);
      return;
    }

    // Handle system commands
    if (command == '/benchmark') {
      _openBenchmark();
      return;
    }

    if (command == '/metrics') {
      _showLastMetrics();
      return;
    }

    if (!_inference.isReady) {
      _addLine('[SYS] Model not loaded. Cannot generate response.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _currentSuggestions = [];
    });

    try {
      if (_gameSession != null) {
        // ── GameSession path: typewriter-streamed with suggestion parsing ──
        final result = await _typewriteGameResponse(
          _gameSession!.submitCommand(command),
        );

        if (result.turn != null && result.turn!.isComplete) {
          _displaySuggestions(result.turn!.suggestions);
          _captureMetrics(
            ttftMs: result.ttftMs,
            tokenCount: result.tokenCount,
            totalTimeMs: result.totalTimeMs,
            rawResponse: result.turn!.rawResponse,
          );
          // Auto-save after each completed turn (BL-118).
          await _autoSave();
        }
      } else {
        // ── Fallback: raw InferenceService with typewriter animation ──
        final result = await _typewriteRawResponse(
          _inference.generate(command, maxTokens: 150),
        );

        final metrics = InferenceMetrics(
          modelName:
              _inference.loadedModelPath?.split('/').last ?? 'unknown',
          ttftMs: result.ttftMs ?? result.totalTimeMs,
          tokenCount: result.tokenCount,
          totalTimeMs: result.totalTimeMs,
          peakMemoryMB: result.peakMem,
          responseText: result.response,
        );

        _lastMetrics = metrics;
        _addLine(
          '[PERF] TTFT: ${metrics.ttftSeconds.toStringAsFixed(2)}s | '
          '${metrics.tokensPerSecond.toStringAsFixed(1)} tok/s | '
          '${result.tokenCount} tokens in ${result.totalTimeMs}ms',
          isMetric: true,
        );
      }
    } catch (e) {
      _addLine('[ERR] Generation failed: $e');
    }

    setState(() => _isGenerating = false);
  }

  /// Handle the user's choice between Continue and New Adventure (BL-118).
  Future<void> _handleResumeChoice(String command) async {
    final choice = command.trim().toLowerCase();
    setState(() => _awaitingResumeChoice = false);

    if (choice == '1' || choice == 'continue') {
      final saveData = _pendingSaveData;
      _pendingSaveData = null;
      if (saveData != null) {
        await _restoreGameSession(saveData);
      } else {
        await _initGameSession();
      }
    } else if (choice == '2' || choice == 'new') {
      _pendingSaveData = null;
      // Delete old save before starting fresh.
      if (_saveFilePath != null) {
        await GameSession.deleteSave(_saveFilePath!);
      }
      await _initGameSession();
    } else {
      _addLine('[SYS] Please type 1 (continue) or 2 (new adventure).');
      setState(() => _awaitingResumeChoice = true);
    }
  }

  void _showLastMetrics() {
    if (_lastMetrics == null) {
      _addLine('[SYS] No metrics yet. Generate a response first.');
      return;
    }
    for (final line in _lastMetrics!.toSummary().split('\n')) {
      if (line.isNotEmpty) _addLine('[PERF] $line', isMetric: true);
    }
  }

  void _openBenchmark() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BenchmarkScreen()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inference.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildSuggestionChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _currentSuggestions.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final suggestion = entry.value;
          return GestureDetector(
            onTap: _isGenerating ? null : () => _onSuggestionTap(suggestion),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _suggestionColor.withAlpha(153),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$index. $suggestion',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _suggestionColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Terminal output area
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    return Text(
                      line.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: line.isHeader ? 22 : 14,
                        fontWeight:
                            line.isHeader ? FontWeight.bold : FontWeight.normal,
                        color: line.text.startsWith('[ERR]')
                            ? Colors.red
                            : line.isMetric
                                ? _metricsColor
                                : line.isSuggestion
                                    ? _suggestionColor
                                    : line.text.startsWith('[SYS]')
                                        ? _terminalDim
                                        : _terminalGreen,
                        letterSpacing: line.isHeader ? 4 : 0,
                        height: 1.4,
                      ),
                    );
                  },
                ),
              ),
              // Suggestion chips (interactive, shown when available)
              if (_currentSuggestions.isNotEmpty) _buildSuggestionChips(),
              const SizedBox(height: 8),
              // Input area
              Row(
                children: [
                  Text(
                    '> ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      color: _terminalGreen,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (_) => _onSubmit(),
                      enabled: !_isGenerating,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: Color(0xFF00FF41),
                      ),
                      cursorColor: _terminalGreen,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: _gameSession != null
                            ? 'What do you do?'
                            : 'Type a command...',
                        hintStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          color: Color(0xFF004D15),
                        ),
                      ),
                    ),
                  ),
                  if (_isGenerating)
                    _BlinkingCursor()
                  else
                    IconButton(
                      icon: Icon(Icons.send, color: _terminalGreen, size: 20),
                      onPressed: _onSubmit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const Divider(color: Color(0xFF00FF41), thickness: 1, height: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single line in the terminal output.
class _TerminalLine {
  final String text;
  final bool isHeader;
  final bool isMetric;
  final bool isSuggestion;
  const _TerminalLine(
    this.text, {
    this.isHeader = false,
    this.isMetric = false,
    this.isSuggestion = false,
  });
}

/// A simple blinking cursor to indicate generation in progress.
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        '_',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          color: Color(0xFF00FF41),
        ),
      ),
    );
  }
}
