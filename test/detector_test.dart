import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_touchless/flutter_touchless.dart';

void main() {
  group('Detector Tests', () {
    test('OpticalFlowDetector processes frame difference and tracks movement',
        () async {
      final detector = OpticalFlowDetector(smoothingFactor: 0.5);
      await detector.initialize();
      await detector.start();

      TouchlessPoint? lastPoint;
      final sub = detector.trackingStream.listen((p) => lastPoint = p);

      const width = 80;
      const height = 60;

      // Blank initial frame
      final frame1 = Uint8List(width * height);
      detector.processFrame(frame1, width, height, step: 4);

      // Frame with motion block on right side
      final frame2 = Uint8List(width * height);
      for (int y = 20; y < 40; y++) {
        for (int x = 50; x < 70; x++) {
          frame2[y * width + x] = 200;
        }
      }
      detector.processFrame(frame2, width, height, step: 4);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(lastPoint, isNotNull);
      expect(lastPoint!.isTracked, isTrue);

      await sub.cancel();
      await detector.dispose();
    });

    test('OpticalFlowDetector configures hardware sensor orientations properly',
        () async {
      // Android Front Camera (270°)
      final frontCam = OpticalFlowDetector(sensorOrientation: 270);
      expect(frontCam.swapAxes, isTrue);
      expect(frontCam.invertX, isTrue);
      expect(frontCam.invertY, isTrue);
      await frontCam.dispose();

      // Android Back Camera (90°)
      final backCam = OpticalFlowDetector(sensorOrientation: 90);
      expect(backCam.swapAxes, isTrue);
      expect(backCam.invertX, isFalse);
      expect(backCam.invertY, isFalse);
      await backCam.dispose();

      // Desktop / Webcam (0°)
      final webcam = OpticalFlowDetector(sensorOrientation: 0, isFrontCamera: true);
      expect(webcam.swapAxes, isFalse);
      expect(webcam.invertX, isTrue);
      expect(webcam.invertY, isFalse);
      await webcam.dispose();
    });

    test('OpticalFlowDetector updates real-time telemetryNotifier on motion',
        () async {
      final detector = OpticalFlowDetector(
        sensorOrientation: 270,
        gain: 2.0,
      );
      await detector.start();

      expect(detector.currentTelemetry.direction, 'Still');
      expect(detector.currentTelemetry.isTracking, isFalse);

      const width = 80;
      const height = 60;
      final frame1 = Uint8List(width * height);
      detector.processFrame(frame1, width, height, step: 4);

      final frame2 = Uint8List(width * height);
      for (int y = 10; y < 30; y++) {
        for (int x = 10; x < 30; x++) {
          frame2[y * width + x] = 220;
        }
      }
      detector.processFrame(frame2, width, height, step: 4);

      expect(detector.currentTelemetry.isTracking, isTrue);
      expect(detector.currentTelemetry.magnitude, greaterThan(0.0));

      await detector.dispose();
    });

    test('ProximityWaveDetector detects valid hand wave', () async {
      final detector = ProximityWaveDetector(
        minWaveDuration: const Duration(milliseconds: 50),
        maxWaveDuration: const Duration(milliseconds: 500),
      );
      await detector.start();

      TouchlessGestureEvent? gesture;
      final sub = detector.gestureStream.listen((g) => gesture = g);

      // Hand approaches sensor
      detector.handleProximityChange(true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      // Hand departs
      detector.handleProximityChange(false);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(gesture, isNotNull);
      expect(gesture!.type, TouchlessGestureType.proximityWave);

      await sub.cancel();
      await detector.dispose();
    });

    test('FacialMotionDetector detects head nod and head shake', () async {
      final detector = FacialMotionDetector(
        gestureCooldown: const Duration(milliseconds: 50),
      );
      await detector.start();

      final gestures = <TouchlessGestureType>[];
      final sub = detector.gestureStream.listen((g) => gestures.add(g.type));

      // Simulate nod down-up
      detector.handleHeadPose(pitch: 0.0, yaw: 0.0);
      detector.handleHeadPose(pitch: 16.0, yaw: 0.0);
      detector.handleHeadPose(pitch: -16.0, yaw: 0.0);
      detector.handleHeadPose(pitch: 1.0, yaw: 0.0);
      detector.handleHeadPose(pitch: 0.0, yaw: 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(gestures, contains(TouchlessGestureType.headNod));

      // Wait past cooldown
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Simulate shake left-right
      detector.handleHeadPose(pitch: 0.0, yaw: 0.0);
      detector.handleHeadPose(pitch: 0.0, yaw: 18.0);
      detector.handleHeadPose(pitch: 0.0, yaw: -18.0);
      detector.handleHeadPose(pitch: 0.0, yaw: 1.0);
      detector.handleHeadPose(pitch: 0.0, yaw: 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(gestures, contains(TouchlessGestureType.headShake));

      await sub.cancel();
      await detector.dispose();
    });

    test('MockTouchlessDetector simulation helpers emit accurate events',
        () async {
      final mock = MockTouchlessDetector();
      await mock.start();

      TouchlessGestureEvent? received;
      final sub = mock.gestureStream.listen((g) => received = g);

      mock.simulateSwipeUp();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received?.type, TouchlessGestureType.swipeUp);

      mock.simulateSwipeDown();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received?.type, TouchlessGestureType.swipeDown);

      await sub.cancel();
      await mock.dispose();
    });
  });
}
