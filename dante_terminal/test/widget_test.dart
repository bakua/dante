import 'package:flutter_test/flutter_test.dart';
import 'package:dante_terminal/main.dart';

void main() {
  testWidgets('Terminal screen renders title text', (WidgetTester tester) async {
    await tester.pumpWidget(const DanteTerminalApp());

    expect(find.text('DANTE TERMINAL'), findsOneWidget);
    expect(find.text('> AI-powered text adventure'), findsOneWidget);
    expect(find.text('> Powered by on-device LLM'), findsOneWidget);
    expect(find.text('> Runs entirely offline'), findsOneWidget);
    expect(find.text('v0.1.0'), findsOneWidget);
  });

  testWidgets('Terminal screen has blinking cursor', (WidgetTester tester) async {
    await tester.pumpWidget(const DanteTerminalApp());

    expect(find.text('> _'), findsOneWidget);
  });
}
