/// Retro terminal gameplay screen with CRT shader, typewriter animation,
/// and suggestion chips (BL-160).
///
/// This is the **display layer only** — it consumes a [Stream<String>] for AI
/// response tokens and exposes an [onCommand] callback for player input.
/// Game logic integration is handled separately.
///
/// Features:
/// - Green-on-black color scheme (#00FF41 on #0D0208)
/// - Monospace font (platform default monospace)
/// - CRT scanline overlay via [CrtScanlinePainter]
/// - Typewriter character-by-character text animation
/// - 3 tappable suggestion chips
/// - Blinking cursor on input field
library;

import 'dart:async';

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════
// Public types
// ═════════════════════════════════════════════════════════════════════

/// A single message in the terminal history.
class TerminalMessage {
  /// The text content.
  final String text;

  /// Whether this is a player command (rendered with "> " prefix).
  final bool isPlayer;

  /// Whether this is a system/status message (rendered dimmed).
  final bool isSystem;

  const TerminalMessage(
    this.text, {
    this.isPlayer = false,
    this.isSystem = false,
  });
}

// ═════════════════════════════════════════════════════════════════════
// Theme constants
// ═════════════════════════════════════════════════════════════════════

/// Canonical DANTE TERMINAL phosphor green.
const kTerminalGreen = Color(0xFF00FF41);

/// Terminal background: near-black with slight warmth per spec (#0D0208).
const kTerminalBackground = Color(0xFF0D0208);

/// Dimmed green for system messages.
const kTerminalDim = Color(0xFF00AA2A);

/// Suggestion chip accent color.
const kSuggestionColor = Color(0xFF00CC55);

// ═════════════════════════════════════════════════════════════════════
// CRT Scanline Overlay
// ═════════════════════════════════════════════════════════════════════

/// Paints faint horizontal scanlines across the entire widget area,
/// simulating a CRT monitor effect.
///
/// Drawn as an overlay on top of all content via [IgnorePointer] so it
/// doesn't interfere with touch input.
class CrtScanlinePainter extends CustomPainter {
  /// Vertical spacing between scanlines in logical pixels.
  final double lineSpacing;

  /// Alpha of each scanline (0–255).
  final int alpha;

  const CrtScanlinePainter({
    this.lineSpacing = 3.0,
    this.alpha = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromARGB(alpha, 0, 0, 0)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CrtScanlinePainter oldDelegate) =>
      lineSpacing != oldDelegate.lineSpacing || alpha != oldDelegate.alpha;
}

// ═════════════════════════════════════════════════════════════════════
// TerminalGameScreen
// ═════════════════════════════════════════════════════════════════════

/// Retro terminal display widget for the text adventure gameplay experience.
///
/// Layout (top to bottom):
/// 1. Scrollable message history
/// 2. Tappable suggestion chips (when available and not animating)
/// 3. Text input row with blinking cursor and "> " prompt
/// 4. CRT scanline overlay across the entire surface
///
/// ## Usage
/// ```dart
/// TerminalGameScreen(
///   responseStream: aiTokenStream,
///   onCommand: (cmd) => gameSession.submitCommand(cmd),
///   suggestions: ['Look around', 'Open door', 'Check inventory'],
/// )
/// ```
class TerminalGameScreen extends StatefulWidget {
  /// Stream of AI response token strings. Each emission is appended to the
  /// current response and revealed character-by-character with typewriter
  /// animation. When the stream closes, the response is finalized into the
  /// message history.
  final Stream<String>? responseStream;

  /// Callback fired when the player submits a command, either by pressing
  /// Enter in the text field or tapping a suggestion chip.
  final ValueChanged<String>? onCommand;

  /// Suggestion chips to display above the input field.
  final List<String> suggestions;

  /// Messages to prepopulate in the terminal history on first build.
  final List<TerminalMessage> initialMessages;

  const TerminalGameScreen({
    super.key,
    this.responseStream,
    this.onCommand,
    this.suggestions = const [],
    this.initialMessages = const [],
  });

  @override
  State<TerminalGameScreen> createState() => TerminalGameScreenState();
}

/// State for [TerminalGameScreen].
///
/// Exposed as public type so integration tests can use [addMessage].
class TerminalGameScreenState extends State<TerminalGameScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TerminalMessage> _messages = [];

  // ─── Typewriter state ───────────────────────────────────────────
  String _typewriterBuffer = '';
  final List<String> _pendingChars = [];
  bool _isAnimating = false;
  bool _streamDone = false;
  StreamSubscription<String>? _streamSub;
  Timer? _typewriterTimer;

  /// Typewriter pacing: milliseconds between each character reveal.
  static const _kTypewriterDelayMs = 18;

  // ═══════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _messages.addAll(widget.initialMessages);
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(TerminalGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.responseStream != oldWidget.responseStream) {
      _finishCurrentAnimation();
      _subscribeToStream();
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _typewriterTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════

  /// Add a message to the terminal history programmatically.
  void addMessage(TerminalMessage message) {
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  /// Whether a typewriter animation is currently in progress.
  bool get isAnimating => _isAnimating;

  // ═══════════════════════════════════════════════════════════════════
  // Stream / typewriter
  // ═══════════════════════════════════════════════════════════════════

  void _subscribeToStream() {
    final stream = widget.responseStream;
    if (stream == null) return;

    setState(() {
      _isAnimating = true;
      _typewriterBuffer = '';
      _pendingChars.clear();
      _streamDone = false;
    });

    _streamSub = stream.listen(
      (token) {
        _pendingChars.addAll(token.split(''));
        _ensureTypewriterRunning();
      },
      onDone: () {
        _streamDone = true;
        // If no pending chars remain, finalize immediately.
        if (_pendingChars.isEmpty && _typewriterTimer?.isActive != true) {
          _finalizeResponse();
        }
      },
      onError: (Object e) {
        _typewriterTimer?.cancel();
        setState(() {
          _isAnimating = false;
          _messages.add(TerminalMessage('[ERR] $e', isSystem: true));
        });
      },
    );
  }

  /// Instantly flush any in-progress animation before switching streams.
  void _finishCurrentAnimation() {
    _streamSub?.cancel();
    _streamSub = null;
    _typewriterTimer?.cancel();
    _typewriterTimer = null;

    if (_typewriterBuffer.isNotEmpty || _pendingChars.isNotEmpty) {
      final fullText = _typewriterBuffer + _pendingChars.join('');
      _pendingChars.clear();
      setState(() {
        _messages.add(TerminalMessage(fullText));
        _typewriterBuffer = '';
        _isAnimating = false;
        _streamDone = false;
      });
    } else {
      setState(() {
        _isAnimating = false;
        _streamDone = false;
      });
    }
  }

  void _ensureTypewriterRunning() {
    if (_typewriterTimer?.isActive == true) return;
    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: _kTypewriterDelayMs),
      (_) => _revealNextChar(),
    );
  }

  void _revealNextChar() {
    if (_pendingChars.isEmpty) {
      _typewriterTimer?.cancel();
      if (_streamDone) {
        _finalizeResponse();
      }
      return;
    }

    setState(() {
      _typewriterBuffer += _pendingChars.removeAt(0);
    });
    _scrollToBottom();
  }

  void _finalizeResponse() {
    if (_typewriterBuffer.isNotEmpty) {
      setState(() {
        _messages.add(TerminalMessage(_typewriterBuffer));
        _typewriterBuffer = '';
        _isAnimating = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isAnimating = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Input handling
  // ═══════════════════════════════════════════════════════════════════

  void _onSubmit() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isAnimating) return;

    _inputController.clear();
    setState(() {
      _messages.add(TerminalMessage(text, isPlayer: true));
    });
    _scrollToBottom();
    widget.onCommand?.call(text);
  }

  void _onSuggestionTap(String suggestion) {
    if (_isAnimating) return;
    setState(() {
      _messages.add(TerminalMessage(suggestion, isPlayer: true));
    });
    _scrollToBottom();
    widget.onCommand?.call(suggestion);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Scroll
  // ═══════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════
  // Widget builders
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMessageLine(TerminalMessage msg) {
    final Color color;
    final String prefix;

    if (msg.isPlayer) {
      color = kTerminalGreen;
      prefix = '> ';
    } else if (msg.isSystem) {
      color = kTerminalDim;
      prefix = '';
    } else {
      color = kTerminalGreen;
      prefix = '';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$prefix${msg.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: color,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildTypewriterLine() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        _typewriterBuffer,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: kTerminalGreen,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    if (widget.suggestions.isEmpty || _isAnimating) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: widget.suggestions.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final text = entry.value;
          return GestureDetector(
            onTap: () => _onSuggestionTap(text),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: kSuggestionColor.withAlpha(153),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$idx. $text',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: kSuggestionColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        const Text(
          '> ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: kTerminalGreen,
          ),
        ),
        Expanded(
          child: TextField(
            controller: _inputController,
            onSubmitted: (_) => _onSubmit(),
            enabled: !_isAnimating,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              color: kTerminalGreen,
            ),
            cursorColor: kTerminalGreen,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'What do you do?',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                color: Color(0xFF004D15),
              ),
            ),
          ),
        ),
        if (_isAnimating)
          const _BlinkingTerminalCursor()
        else
          IconButton(
            icon: const Icon(Icons.send, color: kTerminalGreen, size: 20),
            onPressed: _onSubmit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Main build
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final itemCount = _messages.length + (_isAnimating ? 1 : 0);

    return Scaffold(
      backgroundColor: kTerminalBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main content ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Scrollable message history
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index < _messages.length) {
                          return _buildMessageLine(_messages[index]);
                        }
                        return _buildTypewriterLine();
                      },
                    ),
                  ),
                  // Suggestion chips
                  _buildSuggestionChips(),
                  // Input row
                  _buildInputRow(),
                  const Divider(
                    color: kTerminalGreen,
                    thickness: 1,
                    height: 1,
                  ),
                ],
              ),
            ),
            // ── CRT scanline overlay ──────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: const CrtScanlinePainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Blinking cursor
// ═════════════════════════════════════════════════════════════════════

/// A blinking block cursor shown while the AI is generating a response.
class _BlinkingTerminalCursor extends StatefulWidget {
  const _BlinkingTerminalCursor();

  @override
  State<_BlinkingTerminalCursor> createState() =>
      _BlinkingTerminalCursorState();
}

class _BlinkingTerminalCursorState extends State<_BlinkingTerminalCursor>
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
        '\u2588', // Full block character for authentic terminal cursor
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          color: kTerminalGreen,
        ),
      ),
    );
  }
}
