import 'package:flutter/material.dart';

import 'services/inference_service.dart';

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
  static const _terminalGreen = Color(0xFF00FF41);
  static const _terminalDim = Color(0xFF00AA2A);

  @override
  void initState() {
    super.initState();
    _addLine('DANTE TERMINAL v0.1.0', isHeader: true);
    _addLine('─' * 40);
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
        _addLine('[SYS] Ready. Type a prompt and press Enter.');
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

  void _addLine(String text, {bool isHeader = false}) {
    setState(() {
      _lines.add(_TerminalLine(text, isHeader: isHeader));
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
    final prompt = _inputController.text.trim();
    if (prompt.isEmpty || _isGenerating) return;

    _inputController.clear();
    _addLine('');
    _addLine('> $prompt');

    if (!_inference.isReady) {
      _addLine('[SYS] Model not loaded. Cannot generate response.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final buffer = StringBuffer();
      await for (final token in _inference.generate(prompt)) {
        buffer.write(token);
      }
      _addLine(buffer.toString());
    } catch (e) {
      _addLine('[ERR] Generation failed: $e');
    }

    setState(() => _isGenerating = false);
  }

  @override
  void dispose() {
    _inference.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Type a command...',
                        hintStyle: TextStyle(
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
  const _TerminalLine(this.text, {this.isHeader = false});
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
