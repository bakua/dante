import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dante_terminal/screens/terminal_game_screen.dart';
import 'package:dante_terminal/services/content_report_service.dart';

void main() {
  group('Report Content button (BL-279)', () {
    late ContentReportService reportService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      reportService = ContentReportService();
    });

    // ─── 1. Button presence ───────────────────────────────────────────

    testWidgets('flag button is visible on the terminal screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
          ),
        ),
      );

      // The report button should be present with a flag icon.
      final button = find.byKey(const Key('reportContentButton'));
      expect(button, findsOneWidget);

      // Verify it uses the flag icon.
      final iconButton = tester.widget<IconButton>(button);
      final icon = iconButton.icon as Icon;
      expect(icon.icon, Icons.flag_outlined);

      // Verify tooltip for accessibility.
      expect(iconButton.tooltip, 'Report content');
    });

    // ─── 2. Dialog flow ───────────────────────────────────────────────

    testWidgets('tapping button shows dialog with latest AI response',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
            initialMessages: [
              const TerminalMessage('You enter a dark cave.'),
              const TerminalMessage('look around', isPlayer: true),
              const TerminalMessage(
                  'The cave walls shimmer with crystals.'),
            ],
          ),
        ),
      );

      // Tap the report button.
      await tester.tap(find.byKey(const Key('reportContentButton')));
      await tester.pumpAndSettle();

      // Dialog should be visible with the title.
      expect(find.text('REPORT CONTENT'), findsOneWidget);

      // Dialog should show the latest AI response (not the player message).
      // Text appears in both the message list (14px) and dialog (12px).
      expect(
        find.text('The cave walls shimmer with crystals.'),
        findsNWidgets(2),
      );

      // Both action buttons should be present.
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('REPORT'), findsOneWidget);
    });

    // ─── 3. Cancel dismissal ──────────────────────────────────────────

    testWidgets('tapping Cancel closes dialog without reporting',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
            initialMessages: [
              const TerminalMessage('Some AI response text.'),
            ],
          ),
        ),
      );

      // Open the dialog.
      await tester.tap(find.byKey(const Key('reportContentButton')));
      await tester.pumpAndSettle();
      expect(find.text('REPORT CONTENT'), findsOneWidget);

      // Tap Cancel.
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed.
      expect(find.text('REPORT CONTENT'), findsNothing);

      // No reports should have been stored.
      final reports = await reportService.getReports();
      expect(reports, isEmpty);
    });

    // ─── 4. Report persistence ────────────────────────────────────────

    testWidgets(
        'tapping Report stores content and shows confirmation snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
            initialMessages: [
              const TerminalMessage('Offensive AI text here.'),
            ],
          ),
        ),
      );

      // Open the dialog.
      await tester.tap(find.byKey(const Key('reportContentButton')));
      await tester.pumpAndSettle();

      // Tap Report.
      await tester.tap(find.text('REPORT'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed.
      expect(find.text('REPORT CONTENT'), findsNothing);

      // Confirmation snackbar should appear.
      expect(
        find.text('Content reported. Thank you for your feedback.'),
        findsOneWidget,
      );

      // Report should be persisted via SharedPreferences.
      final reports = await reportService.getReports();
      expect(reports.length, 1);
      expect(reports.first.flaggedText, 'Offensive AI text here.');
      expect(reports.first.timestamp, isA<DateTime>());
    });

    // ─── 5. No-response edge case ────────────────────────────────────

    testWidgets('shows snackbar when no AI response to report',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
          ),
        ),
      );

      // Tap the report button with no messages in history.
      await tester.tap(find.byKey(const Key('reportContentButton')));
      await tester.pumpAndSettle();

      // No dialog should appear.
      expect(find.text('REPORT CONTENT'), findsNothing);

      // Snackbar should inform the user.
      expect(find.text('No AI response to report.'), findsOneWidget);
    });

    // ─── 6. No-response edge case with only player/system messages ───

    testWidgets(
        'shows snackbar when only player and system messages exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
            initialMessages: [
              const TerminalMessage('System initializing...', isSystem: true),
              const TerminalMessage('look around', isPlayer: true),
            ],
          ),
        ),
      );

      // Tap the report button.
      await tester.tap(find.byKey(const Key('reportContentButton')));
      await tester.pumpAndSettle();

      // No dialog should appear — no AI response exists.
      expect(find.text('REPORT CONTENT'), findsNothing);
      expect(find.text('No AI response to report.'), findsOneWidget);
    });

    // ─── 7. Reports latest response, not earlier ones ────────────────

    testWidgets('dialog shows the most recent AI response',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalGameScreen(
            reportService: reportService,
            initialMessages: [
              const TerminalMessage('First AI response.'),
              const TerminalMessage('go north', isPlayer: true),
              const TerminalMessage('Second AI response.'),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('reportContentButton')));
      await tester.pumpAndSettle();

      // Should show the latest AI response, not the first.
      // Text appears in both the message list (14px) and dialog (12px).
      expect(find.text('Second AI response.'), findsNWidgets(2));
      // First response should only appear once (in message list, not dialog).
      expect(find.text('First AI response.'), findsOneWidget);
    });
  });
}
