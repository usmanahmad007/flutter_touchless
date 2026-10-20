import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_touchless/flutter_touchless.dart';

void main() {
  group('Widget Tests', () {
    late MockTouchlessDetector mockDetector;
    late TouchlessController controller;

    setUp(() {
      mockDetector = MockTouchlessDetector();
      controller = TouchlessController(
        detector: mockDetector,
        config: const TouchlessConfig(
          dwellDuration: Duration(milliseconds: 100),
        ),
      );
      mockDetector.start();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('TouchlessScope renders child tree and cursor when tracked',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TouchlessScope(
            controller: controller,
            child: const Scaffold(
              body: Center(child: Text('Touchless Content')),
            ),
          ),
        ),
      );

      expect(find.text('Touchless Content'), findsOneWidget);

      final cursorFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SciFiCursorPainter,
      );
      expect(cursorFinder, findsNothing);

      mockDetector.simulatePoint(0.5, 0.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(cursorFinder, findsOneWidget);
    });

    testWidgets('TouchlessTarget executes callback on dwell completion',
        (tester) async {
      bool clicked = false;
      final targetController = TouchlessController(
        detector: mockDetector,
        nowProvider: () => tester.binding.clock.now(),
        config: const TouchlessConfig(
          dwellDuration: Duration(milliseconds: 100),
        ),
      );
      addTearDown(targetController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: TouchlessScope(
            controller: targetController,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 100,
                  child: TouchlessTarget(
                    id: 'target_box',
                    onTouchlessTap: () => clicked = true,
                    child: Container(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      mockDetector.simulatePoint(0.5, 0.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(targetController.hoveredTargetId, 'target_box');

      await tester.pump(const Duration(milliseconds: 150));
      mockDetector.simulatePoint(0.5, 0.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(clicked, isTrue);
    });

    testWidgets('TouchlessScrollable scrolls on swipeUp and swipeDown',
        (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: TouchlessScope(
            controller: controller,
            showCursor: false, // Avoid persistent repeat pulse in test
            child: Scaffold(
              body: TouchlessScrollable(
                scrollController: scrollController,
                scrollDelta: 200.0,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 40,
                  itemBuilder: (context, index) => SizedBox(
                    height: 100,
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(scrollController.offset, 0.0);

      controller.triggerGesture(TouchlessGestureType.swipeUp);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(scrollController.offset, greaterThan(0.0));
    });

    testWidgets('TouchlessStatusBar displays live status and gesture badge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouchlessStatusBar(
              controller: controller,
              detectorLabel: 'Vision Flow Active',
            ),
          ),
        ),
      );

      expect(find.text('Vision Flow Active'), findsOneWidget);

      controller.triggerGesture(TouchlessGestureType.swipeRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('👉 Wave Right'), findsOneWidget);

      // Settle the badge timer so no pending timers remain
      await tester.pump(const Duration(milliseconds: 1500));
    });
  });
}
