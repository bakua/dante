import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dante_terminal/screens/terminal_game_screen.dart';

void main() {
  group('TerminalGameScreen', () {
    // ─── AC1: Green-on-black theme + monospace font ─────────────────

    testWidgets('renders with green-on-black theme and monospace font',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TerminalGameScreen(),
        ),
      );

      // Scaffold background should be the spec-mandated terminal black.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, kTerminalBackground);
      expect(scaffold.backgroundColor, const Color(0xFF0D0208));

      // The "> " prompt should be visible in green monospace.
      final promptFinder = find.text('> ');
      expect(promptFinder, findsOneWidget);
      final promptWidget = tester.widget<Text>(promptFinder);
      expect(promptWidget.style?.fontFamily, 'monospace');
      expect(promptWidget.style?.color, kTerminalGreen);

      // Input hint text should be present.
      expect(find.text('What do you do?'), findsOneWidget);
    });

    testWidgets('displays initial messages with correct styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TerminalGameScreen(
            initialMessages: [
              TerminalMessage('DANTE TERMINAL v1.0'),
              TerminalMessage('System ready.', isSystem: true),
              TerminalMessage('look around', isPlayer: true),
            ],
          ),
        ),
      );

      // AI/narrative message in terminal green
      expect(find.text('DANTE TERMINAL v1.0'), findsOneWidget);

      // System message (dimmed)
      expect(find.text('System ready.'), findsOneWidget);
      final sysText = tester.widget<Text>(find.text('System ready.'));
      expect(sysText.style?.color, kTerminalDim);

      // Player command with "> " prefix
      expect(find.text('> look around'), findsOneWidget);
    });

    // ─── AC2: Typewriter animation from Stream<String> ──────────────

    testWidgets('typewriter animation reveals text character-by-character',
        (WidgetTester tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            responseStream: controller.stream,
          ),
        ),
      );

      // Emit tokens into the stream.
      controller.add('Hel');
      controller.add('lo');
      await tester.pump(); // Process microtasks / stream events.

      // Advance enough ticks for several characters to appear.
      // Each char takes ~18ms. 5 chars × 18ms = 90ms.
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 18));
      }

      // At least partial text should be visible (typewriter in progress).
      expect(find.textContaining('He'), findsOneWidget);

      // Close the stream to complete the response.
      await controller.close();

      // Pump enough time for all remaining chars + finalization.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 18));
      }

      // Full text "Hello" should now be in the history.
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('stream error adds error message to history',
        (WidgetTester tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            responseStream: controller.stream,
          ),
        ),
      );

      controller.addError('Network timeout');
      await tester.pump();

      expect(find.textContaining('[ERR]'), findsOneWidget);
    });

    // ─── AC3: Suggestion chips tappable → onCommand ─────────────────

    testWidgets('three suggestion chips are displayed and tappable',
        (WidgetTester tester) async {
      String? lastCommand;

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            suggestions: const [
              'Look around',
              'Open door',
              'Check inventory',
            ],
            onCommand: (cmd) => lastCommand = cmd,
          ),
        ),
      );

      // All 3 chips should be visible with numbered prefixes.
      expect(find.text('1. Look around'), findsOneWidget);
      expect(find.text('2. Open door'), findsOneWidget);
      expect(find.text('3. Check inventory'), findsOneWidget);

      // Tap second chip.
      await tester.tap(find.text('2. Open door'));
      await tester.pump();

      expect(lastCommand, 'Open door');

      // The tapped suggestion should appear as a player message.
      expect(find.text('> Open door'), findsOneWidget);
    });

    testWidgets('suggestion chips are hidden during animation',
        (WidgetTester tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            responseStream: controller.stream,
            suggestions: const ['Option A', 'Option B', 'Option C'],
          ),
        ),
      );

      controller.add('tok');
      await tester.pump();

      // Chips should be hidden while animating.
      expect(find.text('1. Option A'), findsNothing);

      await controller.close();
      // Drain all animation.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 18));
      }
    });

    // ─── Text input → onCommand ─────────────────────────────────────

    testWidgets('text input submits command via onCommand callback',
        (WidgetTester tester) async {
      String? lastCommand;

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            onCommand: (cmd) => lastCommand = cmd,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'look around');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(lastCommand, 'look around');
      // Player message should appear in history.
      expect(find.text('> look around'), findsOneWidget);
    });

    // ─── CRT overlay ────────────────────────────────────────────────

    testWidgets('CRT scanline overlay is rendered via CustomPaint',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TerminalGameScreen(),
        ),
      );

      // CustomPaint with CrtScanlinePainter should exist.
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      final hasCrtPainter = customPaints.any(
        (cp) => cp.painter is CrtScanlinePainter,
      );
      expect(hasCrtPainter, isTrue);
    });

    // ─── AC4: No overflow in constrained viewport ───────────────────

    testWidgets('renders without overflow in a constrained viewport',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(375, 667)),
            child: TerminalGameScreen(
              initialMessages: List.generate(
                20,
                (i) => TerminalMessage('Line $i of the adventure text...'),
              ),
              suggestions: const ['Option A', 'Option B', 'Option C'],
            ),
          ),
        ),
      );

      // Flutter test framework automatically detects RenderFlex overflow
      // and reports it as an exception. No exception means no overflow.
      expect(tester.takeException(), isNull);
    });

    // ─── Blinking cursor visibility ─────────────────────────────────

    testWidgets('blinking cursor appears during stream animation',
        (WidgetTester tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            responseStream: controller.stream,
          ),
        ),
      );

      controller.add('token');
      await tester.pump();

      // The full block cursor character should be present.
      expect(find.text('\u2588'), findsOneWidget);

      await controller.close();
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 18));
      }

      // After animation completes, cursor should be gone (send icon instead).
      expect(find.text('\u2588'), findsNothing);
    });
  });
}
