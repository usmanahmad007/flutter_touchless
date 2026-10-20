import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/touchless_gesture.dart';
import '../models/touchless_point.dart';
import 'touchless_detector.dart';

/// Detects deliberate head gestures such as nodding (affirmative/select)
/// and head shaking (negative/cancel/dismiss).
class FacialMotionDetector implements TouchlessDetector {
  final StreamController<TouchlessPoint> _trackingController =
      StreamController<TouchlessPoint>.broadcast();
  final StreamController<TouchlessGestureEvent> _gestureController =
      StreamController<TouchlessGestureEvent>.broadcast();

  bool _isRunning = false;

  // Head pitch/yaw history
  final List<_AngleSample> _pitchHistory = [];
  final List<_AngleSample> _yawHistory = [];

  final Duration _gestureCooldown;
  DateTime _lastGestureTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Creates a [FacialMotionDetector].
  FacialMotionDetector({
    Duration gestureCooldown = const Duration(milliseconds: 600),
  }) : _gestureCooldown = gestureCooldown;

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

  /// Ingests normalized head pose angles or facial center coordinates.
  ///
  /// - [pitch]: Vertical angle in degrees (+ is looking down, - is looking up)
  ///            or normalized Y displacement.
  /// - [yaw]: Horizontal angle in degrees (+ is looking right, - is looking left)
  ///          or normalized X displacement.
  void handleHeadPose({required double pitch, required double yaw}) {
    if (!_isRunning) return;

    final now = DateTime.now();

    // Map head pose into tracking coordinates
    final normalizedX = (yaw / 40.0 + 0.5).clamp(0.0, 1.0);
    final normalizedY = (pitch / 40.0 + 0.5).clamp(0.0, 1.0);

    _trackingController.add(
      TouchlessPoint(
        x: normalizedX,
        y: normalizedY,
        confidence: 0.9,
        isTracked: true,
      ),
    );

    if (now.difference(_lastGestureTime) < _gestureCooldown) return;

    _pitchHistory.add(_AngleSample(pitch, now));
    _yawHistory.add(_AngleSample(yaw, now));

    // Keep 600ms history
    _pitchHistory.removeWhere(
      (s) => now.difference(s.time).inMilliseconds > 600,
    );
    _yawHistory.removeWhere(
      (s) => now.difference(s.time).inMilliseconds > 600,
    );

    // Check for Head Nod (vertical oscillation: down-up or up-down)
    if (_detectOscillation(_pitchHistory, minAmplitude: 12.0)) {
      _lastGestureTime = now;
      _pitchHistory.clear();
      _gestureController.add(
        TouchlessGestureEvent(
          type: TouchlessGestureType.headNod,
          normalizedPosition: Offset(normalizedX, normalizedY),
          confidence: 0.90,
          timestamp: now,
        ),
      );
      return;
    }

    // Check for Head Shake (horizontal oscillation: left-right or right-left)
    if (_detectOscillation(_yawHistory, minAmplitude: 14.0)) {
      _lastGestureTime = now;
      _yawHistory.clear();
      _gestureController.add(
        TouchlessGestureEvent(
          type: TouchlessGestureType.headShake,
          normalizedPosition: Offset(normalizedX, normalizedY),
          confidence: 0.90,
          timestamp: now,
        ),
      );
    }
  }

  bool _detectOscillation(List<_AngleSample> samples,
      {required double minAmplitude}) {
    if (samples.length < 5) return false;

    double minVal = samples.first.angle;
    double maxVal = samples.first.angle;

    for (final s in samples) {
      if (s.angle < minVal) minVal = s.angle;
      if (s.angle > maxVal) maxVal = s.angle;
    }

    final peakToPeak = maxVal - minVal;
    if (peakToPeak < minAmplitude) return false;

    // Verify it crossed from one extreme toward the other
    final first = samples.first.angle;
    final last = samples.last.angle;

    // Ended near original neutral or crossed through
    return (last - first).abs() < (peakToPeak * 0.7);
  }

  /// Simulate a head nod gesture (useful for testing).
  void simulateNod() {
    final now = DateTime.now();
    _gestureController.add(
      TouchlessGestureEvent(
        type: TouchlessGestureType.headNod,
        normalizedPosition: const Offset(0.5, 0.5),
        confidence: 1.0,
        timestamp: now,
      ),
    );
  }

  /// Simulate a head shake gesture (useful for testing).
  void simulateShake() {
    final now = DateTime.now();
    _gestureController.add(
      TouchlessGestureEvent(
        type: TouchlessGestureType.headShake,
        normalizedPosition: const Offset(0.5, 0.5),
        confidence: 1.0,
        timestamp: now,
      ),
    );
  }
}

class _AngleSample {
  final double angle;
  final DateTime time;
  _AngleSample(this.angle, this.time);
}
