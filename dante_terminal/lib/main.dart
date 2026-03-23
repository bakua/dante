import 'package:flutter/material.dart';

void main() {
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

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'DANTE TERMINAL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF41),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'v0.1.0',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFF00FF41),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFF00FF41), thickness: 1),
              const SizedBox(height: 32),
              const Text(
                '> AI-powered text adventure',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  color: Color(0xFF00FF41),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '> Powered by on-device LLM',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  color: Color(0xFF00FF41),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '> Runs entirely offline',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  color: Color(0xFF00FF41),
                ),
              ),
              const Spacer(),
              _BlinkingCursor(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple blinking cursor to give the terminal feel.
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
        '> _',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          color: Color(0xFF00FF41),
        ),
      ),
    );
  }
}
