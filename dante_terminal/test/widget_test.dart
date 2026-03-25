import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/main.dart';
import 'package:dante_terminal/screens/model_download_screen.dart';

void main() {
  testWidgets('App launcher shows splash while checking for model',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DanteTerminalApp());

    // The launcher shows the title during the filesystem check
    expect(find.text('DANTE TERMINAL'), findsOneWidget);
  });

  testWidgets('ModelDownloadScreen shows ready state with download button',
      (WidgetTester tester) async {
    // Test ModelDownloadScreen directly — no platform channel dependency
    await tester.pumpWidget(
      MaterialApp(
        home: ModelDownloadScreen(onDownloadComplete: () {}),
      ),
    );

    // Download screen should show the "AI ENGINE REQUIRED" prompt
    expect(find.text('AI ENGINE REQUIRED'), findsOneWidget);
    expect(find.text('[ DOWNLOAD NOW ]'), findsOneWidget);
    expect(find.text('Model: Qwen2-1.5B-Instruct'), findsOneWidget);
    expect(find.text('Size:  ~986 MB'), findsOneWidget);
  });

  testWidgets('TerminalScreen renders header and system lines',
      (WidgetTester tester) async {
    // Test TerminalScreen directly, bypassing the model-check launcher
    await tester.pumpWidget(
      const MaterialApp(
        home: TerminalScreen(),
      ),
    );

    // Header line
    expect(find.text('DANTE TERMINAL v0.2.0'), findsOneWidget);

    // Static info lines rendered in the terminal output
    expect(find.text('> AI-powered text adventure'), findsOneWidget);
    expect(find.text('> Powered by on-device LLM'), findsOneWidget);
    expect(find.text('> Runs entirely offline'), findsOneWidget);
  });
}
