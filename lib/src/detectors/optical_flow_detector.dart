import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../models/touchless_gesture.dart';
import '../models/touchless_point.dart';
import 'touchless_detector.dart';

/// High-performance, zero-native-dependency computer vision motion detector.
///
/// Analyzes image frames using temporal frame differencing and optical flow
/// centroid tracking to extract air cursor positions and directional hand waves.
class OpticalFlowDetector implements TouchlessDetector {
  final StreamController<TouchlessPoint> _trackingController =
      StreamController<TouchlessPoint>.broadcast();
  final StreamController<TouchlessGestureEvent> _gestureController =
      StreamController<TouchlessGestureEvent>.broadcast();

  bool _isRunning = false;

  // Previous downsampled frame buffer
  Uint8List? _prevFrame;
  int _prevWidth = 0;
  int _prevHeight = 0;

  // Smoothing state (Exponential Moving Average)
  double _smoothX = 0.5;
  double _smoothY = 0.5;
  final double _alpha;

  // Velocity tracking for swipe detection
  final List<_MotionSample> _motionHistory = [];
  DateTime _lastSwipeTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _swipeCooldown;
  final double _swipeSensitivity;

  /// Creates an [OpticalFlowDetector].
  ///
  /// - [smoothingFactor]: 0.1 (very smooth, slightly laggy) to 0.8 (responsive, slightly noisy). Default 0.35.
  /// - [swipeSensitivity]: Motion magnitude threshold for swipe triggers. Default 0.25.
  /// - [swipeCooldown]: Delay between consecutive swipe triggers to prevent double-firing.
  OpticalFlowDetector({
    double smoothingFactor = 0.35,
    double swipeSensitivity = 0.25,
    Duration swipeCooldown = const Duration(milliseconds: 400),
  })  : _alpha = smoothingFactor.clamp(0.05, 0.95),
        _swipeSensitivity = swipeSensitivity,
        _swipeCooldown = swipeCooldown;

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

  /// Processes a raw grayscale / Y-plane camera frame.
  ///
  /// Can be called directly from `CameraController.startImageStream`.
  /// - [luminanceBytes]: Raw 8-bit grayscale pixel buffer.
  /// - [width]: Image width in pixels.
  /// - [height]: Image height in pixels.
  /// - [step]: Sub-sampling step (e.g. 4 or 8) for lightning-fast 60 FPS mobile performance.
  void processFrame(
    Uint8List luminanceBytes,
    int width,
    int height, {
    int step = 6,
  }) {
    if (!_isRunning || luminanceBytes.isEmpty || width <= 0 || height <= 0) {
      return;
    }

    final now = DateTime.now();
    final gridW = width ~/ step;
    final gridH = height ~/ step;
    final currentDownsampled = Uint8List(gridW * gridH);

    for (int gy = 0; gy < gridH; gy++) {
      final srcY = gy * step;
      final srcRowOffset = srcY * width;
      final dstRowOffset = gy * gridW;

      for (int gx = 0; gx < gridW; gx++) {
        final srcX = gx * step;
        currentDownsampled[dstRowOffset + gx] =
            luminanceBytes[srcRowOffset + srcX];
      }
    }

    if (_prevFrame == null || _prevWidth != gridW || _prevHeight != gridH) {
      _prevFrame = currentDownsampled;
      _prevWidth = gridW;
      _prevHeight = gridH;
      return;
    }

    // Compute frame difference & motion centroid
    double totalMotion = 0;
    double weightedX = 0;
    double weightedY = 0;
    const threshold = 18; // Minimum intensity difference to count as motion

    for (int i = 0; i < currentDownsampled.length; i++) {
      final diff = (currentDownsampled[i] - _prevFrame![i]).abs();
      if (diff > threshold) {
        final gx = i % gridW;
        final gy = i ~/ gridW;
        totalMotion += diff;
        weightedX += gx * diff;
        weightedY += gy * diff;
      }
    }

    _prevFrame = currentDownsampled;

    // If significant motion was detected
    if (totalMotion > (gridW * gridH * 1.2)) {
      // Mirrored horizontal coordinate (selfie camera behaves like a mirror)
      final rawX = 1.0 - (weightedX / (totalMotion * gridW));
      final rawY = weightedY / (totalMotion * gridH);

      // Exponential moving average filter
      _smoothX = _smoothX + _alpha * (rawX - _smoothX);
      _smoothY = _smoothY + _alpha * (rawY - _smoothY);

      final point = TouchlessPoint(
        x: _smoothX,
        y: _smoothY,
        confidence: math.min(1.0, totalMotion / (gridW * gridH * 6)),
        isTracked: true,
      );

      _trackingController.add(point);

      // Analyze motion velocity for swipe gesture
      _analyzeSwipe(point, now);
    } else {
      // Motion faded
      if (_motionHistory.isNotEmpty) {
        _motionHistory.clear();
      }
    }
  }

  void _analyzeSwipe(TouchlessPoint point, DateTime now) {
    _motionHistory.add(_MotionSample(point.x, point.y, now));

    // Keep last 350ms of motion
    _motionHistory.removeWhere(
      (s) => now.difference(s.time).inMilliseconds > 350,
    );

    if (_motionHistory.length < 3) return;

    if (now.difference(_lastSwipeTime) < _swipeCooldown) return;

    final oldest = _motionHistory.first;
    final dx = point.x - oldest.x;
    final dy = point.y - oldest.y;
    final dtSeconds = now.difference(oldest.time).inMilliseconds / 1000.0;

    if (dtSeconds <= 0.05) return;

    final vx = dx / dtSeconds;
    final vy = dy / dtSeconds;

    final absVx = vx.abs();
    final absVy = vy.abs();

    if (absVx > _swipeSensitivity && absVx > absVy * 1.3) {
      final type = vx > 0
          ? TouchlessGestureType.swipeRight
          : TouchlessGestureType.swipeLeft;
      _emitGesture(type, Offset(point.x, point.y), now);
      _motionHistory.clear();
    } else if (absVy > _swipeSensitivity && absVy > absVx * 1.3) {
      final type = vy > 0
          ? TouchlessGestureType.swipeDown
          : TouchlessGestureType.swipeUp;
      _emitGesture(type, Offset(point.x, point.y), now);
      _motionHistory.clear();
    }
  }

  void _emitGesture(TouchlessGestureType type, Offset pos, DateTime now) {
    _lastSwipeTime = now;
    final event = TouchlessGestureEvent(
      type: type,
      normalizedPosition: pos,
      confidence: 0.92,
      timestamp: now,
    );
    _gestureController.add(event);
  }
}

class _MotionSample {
  final double x;
  final double y;
  final DateTime time;
  _MotionSample(this.x, this.y, this.time);
}
