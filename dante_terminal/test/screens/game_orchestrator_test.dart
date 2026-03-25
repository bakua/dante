import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dante_terminal/screens/game_orchestrator.dart';
import 'package:dante_terminal/screens/terminal_game_screen.dart';

void main() {
  group('GameOrchestrator', () {
    // A generate function that never emits — avoids asset-loading issues
    // in the test environment (rootBundle doesn't have adventure JSON).
    Stream<String> neverGenerate(
      String prompt, {
      int maxTokens = 256,
      String? grammarFilePath,
    }) {
      return const Stream<String>.empty();
    }

    testWidgets('renders TerminalGameScreen with initial messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOrchestrator(
            generateFunction: neverGenerate,
          ),
        ),
      );

      // Should contain a TerminalGameScreen
      expect(find.byType(TerminalGameScreen), findsOneWidget);

      // Initial messages should be rendered
      expect(find.text('DANTE TERMINAL v0.2.0'), findsOneWidget);
      expect(find.text('AI-powered text adventure'), findsOneWidget);
      expect(find.text('Powered by on-device LLM'), findsOneWidget);
      expect(find.text('Loading adventure...'), findsOneWidget);
    });

    testWidgets('renders CRT scanline overlay from TerminalGameScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOrchestrator(
            generateFunction: neverGenerate,
          ),
        ),
      );

      // CRT overlay from TerminalGameScreen should be present
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );
      final hasCrtPainter = customPaints.any(
        (cp) => cp.painter is CrtScanlinePainter,
      );
      expect(hasCrtPainter, isTrue);
    });

    testWidgets('has text input field for player commands',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOrchestrator(
            generateFunction: neverGenerate,
          ),
        ),
      );

      // Input field should exist
      expect(find.byType(TextField), findsOneWidget);

      // "> " prompt should be visible
      expect(find.text('> '), findsOneWidget);
    });

    testWidgets('accepts custom adventureId parameter',
        (WidgetTester tester) async {
      // Should not crash with a different adventure ID
      // (will fail to load in test but handles gracefully)
      await tester.pumpWidget(
        MaterialApp(
          home: GameOrchestrator(
            generateFunction: neverGenerate,
            adventureId: 'custom_adventure',
          ),
        ),
      );

      expect(find.byType(TerminalGameScreen), findsOneWidget);
    });

    testWidgets('survives asset loading failure without crashing',
        (WidgetTester tester) async {
      // The test environment lacks bundled adventure assets, so _initialize
      // will fail. The orchestrator should handle this gracefully — no
      // unhandled exceptions and the widget tree remains intact.
      await tester.pumpWidget(
        MaterialApp(
          home: GameOrchestrator(
            generateFunction: neverGenerate,
          ),
        ),
      );

      // Pump several frames to allow async _initialize to attempt.
      // Using pump() instead of pumpAndSettle() because the blinking cursor
      // animation in TerminalGameScreen prevents settling.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Widget tree should still be intact — no crash
      expect(find.byType(TerminalGameScreen), findsOneWidget);
      expect(find.text('DANTE TERMINAL v0.2.0'), findsOneWidget);

      // No unhandled exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
