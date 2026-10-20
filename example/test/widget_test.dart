import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('TouchlessShowcaseApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TouchlessShowcaseApp());
    expect(find.text('TOUCHLESS AUDIO PLAYER'), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });
}
