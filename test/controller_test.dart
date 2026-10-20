import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_touchless/flutter_touchless.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TouchlessController Tests', () {
    late MockTouchlessDetector mockDetector;
    late TouchlessController controller;

    setUp(() {
      mockDetector = MockTouchlessDetector();
      controller = TouchlessController(
        config: const TouchlessConfig(
          dwellDuration: Duration(milliseconds: 100),
        ),
        detector: mockDetector,
      );
      mockDetector.start();
    });

    tearDown(() {
      controller.dispose();
    });

    test('updates currentPoint when detector emits tracking coordinates',
        () async {
      expect(controller.currentPoint.isTracked, isFalse);

      mockDetector.simulatePoint(0.4, 0.7);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.currentPoint.isTracked, isTrue);
      expect(controller.currentPoint.x, 0.4);
      expect(controller.currentPoint.y, 0.7);
    });

    test('triggers dwell activation when hovering over registered target',
        () async {
      controller.updateScreenSize(const Size(1000, 1000));
      bool activated = false;

      controller.registerTarget(
        'btn_submit',
        const Rect.fromLTWH(200, 200, 200, 100),
        () => activated = true,
      );

      // Move cursor inside target bounds (x=300, y=250 -> normalized 0.3, 0.25)
      mockDetector.simulatePoint(0.3, 0.25);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.hoveredTargetId, 'btn_submit');
      expect(activated, isFalse);

      // Wait past dwellDuration (100ms)
      await Future<void>.delayed(const Duration(milliseconds: 120));
      // Trigger a tick to check hover progress
      mockDetector.simulatePoint(0.3, 0.25);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(activated, isTrue);
    });

    test('dispatches gestures through gestureStream', () async {
      TouchlessGestureEvent? received;
      final sub = controller.gestureStream.listen((event) => received = event);

      mockDetector.simulateSwipeRight();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isNotNull);
      expect(received!.type, TouchlessGestureType.swipeRight);

      await sub.cancel();
    });

    test('switching detector binds listeners seamlessly', () async {
      final newMock = MockTouchlessDetector();
      await controller.setDetector(newMock);

      newMock.simulatePoint(0.88, 0.99);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.currentPoint.x, 0.88);
      expect(controller.currentPoint.y, 0.99);
    });
  });
}
