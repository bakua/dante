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

class _TerminalScreenState extends State<TerminalScreen> {
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

  static const _terminalGreen = Color(0xFF00FF41);
  static const _terminalDim = Color(0xFF00AA2A);
  static const _metricsColor = Color(0xFF00886A);
  static const _suggestionColor = Color(0xFF00CC55);

  @override
  void initState() {
    super.initState();
    _addLine('DANTE TERMINAL v0.2.0', isHeader: true);
    _addLine('\u2500' * 40);
    _addLine('> AI-powered text adventure');
    _addLine('> Powered by on-device LLM');
    _addLine('> Runs entirely offline');
    _addLine('');
    _initEngine();
  }

  Future<void> _initEngine() async {
    _addLine('[SYS] Initializing inference engine...');
    try {
      await _inference.initialize();
      _addLine('[SYS] Backend ready.');

      // Try to auto-load a model
      _addLine('[SYS] Searching for model file...');
      try {
        final modelPath = await _inference.loadModel();
        _addLine('[SYS] Model loaded: ${modelPath.split('/').last}');

        // Initialize game session with adventure data and auto-generate opening
        await _initGameSession();

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

  /// Load adventure data and assets, create [GameSession], generate opening.
  Future<void> _initGameSession() async {
    try {
      _addLine('[SYS] Loading adventure...');

      // Load adventure scenario data from bundled JSON
      _adventure = await _adventureLoader.load('sunken_archive');
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

  /// Generate the opening scene via [GameSession] on model load.
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

      final stopwatch = Stopwatch()..start();
      int? ttftMs;
      int tokenCount = 0;
      GameTurn? lastTurn;

      await for (final turn in _gameSession!.submitCommand(openingCommand)) {
        lastTurn = turn;
        if (!turn.isComplete) {
          ttftMs ??= stopwatch.elapsedMilliseconds;
          tokenCount++;
        }
      }

      stopwatch.stop();

      if (lastTurn != null && lastTurn.isComplete) {
        _addLine(lastTurn.narrativeText);
        _displaySuggestions(lastTurn.suggestions);

        _captureMetrics(
          ttftMs: ttftMs,
          tokenCount: tokenCount,
          totalTimeMs: stopwatch.elapsedMilliseconds,
          rawResponse: lastTurn.rawResponse,
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
    // Scroll to bottom after frame renders
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

  Future<void> _onSubmit() async {
    final command = _inputController.text.trim();
    if (command.isEmpty || _isGenerating) return;

    _inputController.clear();
    _addLine('');
    _addLine('> $command');

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
        // ── GameSession path: full prompt assembly + suggestion parsing ──
        final stopwatch = Stopwatch()..start();
        int? ttftMs;
        int tokenCount = 0;
        GameTurn? lastTurn;

        await for (final turn in _gameSession!.submitCommand(command)) {
          lastTurn = turn;
          if (!turn.isComplete) {
            ttftMs ??= stopwatch.elapsedMilliseconds;
            tokenCount++;
          }
        }

        stopwatch.stop();

        if (lastTurn != null && lastTurn.isComplete) {
          // Display narrative text
          _addLine(lastTurn.narrativeText);

          // Display parsed suggestions
          _displaySuggestions(lastTurn.suggestions);

          // Capture and display performance metrics
          _captureMetrics(
            ttftMs: ttftMs,
            tokenCount: tokenCount,
            totalTimeMs: stopwatch.elapsedMilliseconds,
            rawResponse: lastTurn.rawResponse,
          );
        }
      } else {
        // ── Fallback: raw InferenceService (no GameSession available) ──
        final stopwatch = Stopwatch()..start();
        int? ttftMs;
        int tokenCount = 0;
        final responseBuffer = StringBuffer();
        double? peakMem = getCurrentMemoryMB();

        await for (final token
            in _inference.generate(command, maxTokens: 150)) {
          ttftMs ??= stopwatch.elapsedMilliseconds;
          responseBuffer.write(token);
          tokenCount++;

          if (tokenCount % 20 == 0) {
            final mem = getCurrentMemoryMB();
            if (mem != null && (peakMem == null || mem > peakMem)) {
              peakMem = mem;
            }
          }
        }

        stopwatch.stop();
        _addLine(responseBuffer.toString());

        final metrics = InferenceMetrics(
          modelName:
              _inference.loadedModelPath?.split('/').last ?? 'unknown',
          ttftMs: ttftMs ?? stopwatch.elapsedMilliseconds,
          tokenCount: tokenCount,
          totalTimeMs: stopwatch.elapsedMilliseconds,
          peakMemoryMB: peakMem,
          responseText: responseBuffer.toString(),
        );

        _lastMetrics = metrics;
        _addLine(
          '[PERF] TTFT: ${metrics.ttftSeconds.toStringAsFixed(2)}s | '
          '${metrics.tokensPerSecond.toStringAsFixed(1)} tok/s | '
          '$tokenCount tokens in ${stopwatch.elapsedMilliseconds}ms',
          isMetric: true,
        );
      }
    } catch (e) {
      _addLine('[ERR] Generation failed: $e');
    }

    setState(() => _isGenerating = false);
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
