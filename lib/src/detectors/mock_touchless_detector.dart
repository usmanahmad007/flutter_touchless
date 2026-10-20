import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/touchless_gesture.dart';
import '../models/touchless_point.dart';
import 'touchless_detector.dart';

/// Simulator detector designed for unit tests, local development,
/// and desktop / emulator testing without requiring physical cameras or sensors.
class MockTouchlessDetector implements TouchlessDetector {
  final StreamController<TouchlessPoint> _trackingController =
      StreamController<TouchlessPoint>.broadcast();
  final StreamController<TouchlessGestureEvent> _gestureController =
      StreamController<TouchlessGestureEvent>.broadcast();

  bool _isRunning = false;

  @override
  Stream<TouchlessPoint> get trackingStream => _trackingController.stream;

  @override
  Stream<TouchlessGestureEvent> get gestureStream => _gestureController.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> initialize() async {
    _isRunning = false;
  }

  @override
  Future<void> start() async {
    _isRunning = true;
  }

  @override
  Future<void> pause() async {
    _isRunning = false;
  }

  @override
  Future<void> dispose() async {
    _isRunning = false;
    await _trackingController.close();
    await _gestureController.close();
  }

  /// Manually feeds a simulated tracking point.
  void simulatePoint(double x, double y,
      {double confidence = 1.0, bool isTracked = true}) {
    if (!_isRunning) return;
    _trackingController.add(
      TouchlessPoint(
        x: x.clamp(0.0, 1.0),
        y: y.clamp(0.0, 1.0),
        confidence: confidence,
        isTracked: isTracked,
      ),
    );
  }

  /// Manually emits a simulated gesture event.
  void simulateGesture(TouchlessGestureType type,
      {Offset? position, double confidence = 1.0}) {
    if (!_isRunning) return;
    _gestureController.add(
      TouchlessGestureEvent(
        type: type,
        normalizedPosition: position ?? const Offset(0.5, 0.5),
        confidence: confidence,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Helper to simulate a swipe left.
  void simulateSwipeLeft() => simulateGesture(TouchlessGestureType.swipeLeft);

  /// Helper to simulate a swipe right.
  void simulateSwipeRight() => simulateGesture(TouchlessGestureType.swipeRight);

  /// Helper to simulate a swipe up.
  void simulateSwipeUp() => simulateGesture(TouchlessGestureType.swipeUp);

  /// Helper to simulate a swipe down.
  void simulateSwipeDown() => simulateGesture(TouchlessGestureType.swipeDown);

  /// Helper to simulate a head nod.
  void simulateHeadNod() => simulateGesture(TouchlessGestureType.headNod);

  /// Helper to simulate a head shake.
  void simulateHeadShake() => simulateGesture(TouchlessGestureType.headShake);

  /// Helper to simulate a proximity wave.
  void simulateProximityWave() =>
      simulateGesture(TouchlessGestureType.proximityWave);
}
