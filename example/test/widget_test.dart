import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('TouchlessShowcaseApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TouchlessShowcaseApp());
    expect(find.text('Cooking'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Arcade'), findsOneWidget);
    expect(find.text('Engine'), findsOneWidget);
  });
}
