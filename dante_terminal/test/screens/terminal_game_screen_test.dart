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

    // ─── BL-165: Accessibility fixes ─────────────────────────────────

    group('accessibility', () {
      // ── Color contrast ─────────────────────────────────────────────

      testWidgets('hint text color meets WCAG AA 4.5:1 contrast',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TerminalGameScreen(),
          ),
        );

        // Find the TextField and verify hint color is no longer #004D15.
        final textField = tester.widget<TextField>(find.byType(TextField));
        final hintColor = textField.decoration?.hintStyle?.color;
        // Old failing color was 0xFF004D15 (1.95:1 ratio).
        // New color should be 0xFF33884D (~4.5:1 ratio).
        expect(hintColor, isNot(const Color(0xFF004D15)));
        expect(hintColor, const Color(0xFF33884D));
      });

      // ── Touch targets ──────────────────────────────────────────────

      testWidgets('suggestion chips have at least 48px touch targets',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TerminalGameScreen(
              suggestions: ['Look around', 'Open door', 'Check inventory'],
            ),
          ),
        );

        // Find chip containers via their text children.
        final chipFinder = find.text('1. Look around');
        expect(chipFinder, findsOneWidget);

        // Walk up to the Container with constraints.
        final container = tester.widget<Container>(
          find.ancestor(
            of: chipFinder,
            matching: find.byType(Container),
          ).first,
        );

        expect(container.constraints?.minHeight, greaterThanOrEqualTo(48));
        expect(container.constraints?.minWidth, greaterThanOrEqualTo(48));
      });

      testWidgets('send button has at least 48x48 touch target',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TerminalGameScreen(),
          ),
        );

        final iconButton =
            tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.constraints?.minWidth, greaterThanOrEqualTo(48));
        expect(iconButton.constraints?.minHeight, greaterThanOrEqualTo(48));
      });

      testWidgets('send button has tooltip for screen readers',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: TerminalGameScreen(),
          ),
        );

        final iconButton =
            tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Send command');
      });

      // ── Reduce motion ──────────────────────────────────────────────

      testWidgets(
          'typewriter shows text instantly when disableAnimations is true',
          (WidgetTester tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data:
                    MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              );
            },
            home: TerminalGameScreen(
              responseStream: controller.stream,
            ),
          ),
        );

        // Emit tokens.
        controller.add('Hello world');
        await tester.pump(); // Process stream event.

        // With reduce motion, text should appear immediately — no need
        // to pump multiple 18ms ticks.
        expect(find.textContaining('Hello world'), findsOneWidget);

        // Close stream to finalize.
        await controller.close();
        await tester.pump();

        // Finalized text should be in history.
        expect(find.text('Hello world'), findsOneWidget);
      });

      testWidgets(
          'blinking cursor is static when disableAnimations is true',
          (WidgetTester tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data:
                    MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              );
            },
            home: TerminalGameScreen(
              responseStream: controller.stream,
            ),
          ),
        );

        controller.add('tok');
        await tester.pump();

        // Cursor should be present.
        expect(find.text('\u2588'), findsOneWidget);

        // With reduce motion, the cursor's own FadeTransition should NOT
        // be present. Check specifically for a FadeTransition whose
        // direct child is the cursor Text (excludes Navigator transitions).
        final cursorFade = find.byWidgetPredicate(
          (widget) =>
              widget is FadeTransition &&
              widget.child is Text &&
              (widget.child as Text).data == '\u2588',
        );
        expect(cursorFade, findsNothing);

        await controller.close();
        await tester.pump();
      });
    });
  });
}
