import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/main.dart';

void main() {
  testWidgets('Terminal screen renders header and system lines',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DanteTerminalApp());

    // Header line
    expect(find.text('DANTE TERMINAL v0.1.0'), findsOneWidget);

    // Static info lines rendered in the terminal output
    expect(find.text('> AI-powered text adventure'), findsOneWidget);
    expect(find.text('> Powered by on-device LLM'), findsOneWidget);
    expect(find.text('> Runs entirely offline'), findsOneWidget);
  });

  testWidgets('Terminal screen has input field with hint text',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DanteTerminalApp());

    // The prompt character and hint text should be visible
    expect(find.text('> '), findsOneWidget);
    expect(find.text('Type a command...'), findsOneWidget);
  });
}
