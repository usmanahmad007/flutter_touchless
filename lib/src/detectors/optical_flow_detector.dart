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
  double _alpha;

  /// Hardware sensor orientation in degrees (0, 90, 180, 270).
  int sensorOrientation;

  /// Whether the camera is a front-facing selfie camera.
  bool isFrontCamera;

  /// Whether to swap X and Y coordinates (necessary for mobile cameras in portrait).
  bool swapAxes;

  /// Whether to invert the horizontal X axis.
  bool invertX;

  /// Whether to invert the vertical Y axis.
  bool invertY;

  /// Coordinate reach gain multiplier (1.0 to 3.5).
  /// Expands center motion range so hand reaches screen edges comfortably.
  double gain;

  /// Minimum luminance intensity difference between frames to register motion.
  int threshold;

  // Live telemetry
  double _lastMotionMagnitude = 0.0;
  String _dominantDirection = 'Still';

  /// Live motion magnitude (0.0 to 1.0+).
  double get lastMotionMagnitude => _lastMotionMagnitude;

  /// Live dominant movement direction string ('Left ⬅️', 'Right ➡️', 'Up ⬆️', 'Down ⬇️', 'Still 🎯').
  String get dominantDirection => _dominantDirection;

  /// Real-time telemetry notifier for HUDs, calibration panels, and diagnostics.
  final ValueNotifier<OpticalFlowTelemetry> telemetryNotifier =
      ValueNotifier<OpticalFlowTelemetry>(const OpticalFlowTelemetry());

  /// Current live telemetry snapshot.
  OpticalFlowTelemetry get currentTelemetry => telemetryNotifier.value;

  /// Current smoothing factor (0.05 to 0.95).
  double get smoothingFactor => _alpha;
  set smoothingFactor(double val) => _alpha = val.clamp(0.05, 0.95);

  // Velocity tracking for swipe detection
  final List<_MotionSample> _motionHistory = [];
  DateTime _lastSwipeTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _swipeCooldown;
  final double _swipeSensitivity;
  bool _isDisposed = false;

  /// Creates an [OpticalFlowDetector].
  ///
  /// - [sensorOrientation]: Degrees of hardware sensor rotation (typically 270 on Android front camera, 0 on webcams).
  /// - [isFrontCamera]: If true, applies mirror effect.
  /// - [gain]: Coordinate amplifier (default 1.8x) so hand motion comfortably reaches all screen edges.
  /// - [threshold]: Minimum pixel difference to count as motion (default 18).
  OpticalFlowDetector({
    double smoothingFactor = 0.35,
    double swipeSensitivity = 0.25,
    Duration swipeCooldown = const Duration(milliseconds: 400),
    this.sensorOrientation = 0,
    this.isFrontCamera = true,
    bool? swapAxes,
    bool? invertX,
    bool? invertY,
    this.gain = 1.8,
    this.threshold = 18,
  })  : _alpha = smoothingFactor.clamp(0.05, 0.95),
        _swipeSensitivity = swipeSensitivity,
        _swipeCooldown = swipeCooldown,
        swapAxes = swapAxes ??
            (sensorOrientation == 90 || sensorOrientation == 270),
        invertX = invertX ??
            (sensorOrientation == 270
                ? true
                : (sensorOrientation == 90 ? false : isFrontCamera)),
        invertY = invertY ?? (sensorOrientation == 270);

  /// Configures sensor orientation and axis mapping.
  void configureOrientation({
    int? sensorOrientation,
    bool? isFrontCamera,
    bool? swapAxes,
    bool? invertX,
    bool? invertY,
    double? gain,
    int? threshold,
  }) {
    if (sensorOrientation != null) this.sensorOrientation = sensorOrientation;
    if (isFrontCamera != null) this.isFrontCamera = isFrontCamera;
    if (gain != null) this.gain = gain;
    if (threshold != null) this.threshold = threshold;

    if (swapAxes != null) {
      this.swapAxes = swapAxes;
    } else if (sensorOrientation != null) {
      this.swapAxes = (sensorOrientation == 90 || sensorOrientation == 270);
    }

    if (invertX != null) {
      this.invertX = invertX;
    } else if (sensorOrientation != null) {
      this.invertX = (sensorOrientation == 270
          ? true
          : (sensorOrientation == 90 ? false : this.isFrontCamera));
    }

    if (invertY != null) {
      this.invertY = invertY;
    } else if (sensorOrientation != null) {
      this.invertY = (sensorOrientation == 270);
    }
  }

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
    if (_isDisposed) return;
    _isDisposed = true;
    _isRunning = false;
    await _trackingController.close();
    await _gestureController.close();
    telemetryNotifier.dispose();
  }

  /// Processes a raw grayscale / Y-plane camera frame.
  ///
  /// Can be called directly from `CameraController.startImageStream`.
  /// - [luminanceBytes]: Raw 8-bit grayscale pixel buffer (e.g. `image.planes[0].bytes`).
  /// - [width]: Image width in pixels.
  /// - [height]: Image height in pixels.
  /// - [bytesPerRow]: Optional row stride (e.g. `image.planes[0].bytesPerRow`) to prevent row-padding skew on Android.
  /// - [step]: Sub-sampling step (default 4) for high-precision, 60 FPS mobile performance.
  void processFrame(
    Uint8List luminanceBytes,
    int width,
    int height, {
    int? bytesPerRow,
    int step = 4,
  }) {
    if (!_isRunning || luminanceBytes.isEmpty || width <= 0 || height <= 0) {
      return;
    }

    final rowStride = bytesPerRow ?? width;
    final now = DateTime.now();
    final gridW = width ~/ step;
    final gridH = height ~/ step;
    final totalGridPixels = gridW * gridH;
    final currentDownsampled = Uint8List(totalGridPixels);

    for (int gy = 0; gy < gridH; gy++) {
      final srcY = gy * step;
      final srcRowOffset = srcY * rowStride;
      final dstRowOffset = gy * gridW;

      for (int gx = 0; gx < gridW; gx++) {
        final srcX = gx * step;
        final index = srcRowOffset + srcX;
        if (index < luminanceBytes.length) {
          currentDownsampled[dstRowOffset + gx] = luminanceBytes[index];
        }
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
    int activePixels = 0;

    for (int i = 0; i < totalGridPixels; i++) {
      final diff = (currentDownsampled[i] - _prevFrame![i]).abs();
      if (diff > threshold) {
        activePixels++;
        final gx = i % gridW;
        final gy = i ~/ gridW;
        totalMotion += diff;
        weightedX += gx * diff;
        weightedY += gy * diff;
      }
    }

    _prevFrame = currentDownsampled;

    // Reject camera auto-exposure flashes where > 55% of the frame changed at once
    final isGlobalFlash = activePixels > (totalGridPixels * 0.55);

    // Detect proximity wave / hand push towards lens for play/pause
    if (!isGlobalFlash &&
        activePixels > (totalGridPixels * 0.25) &&
        activePixels <= (totalGridPixels * 0.55)) {
      if (now.difference(_lastSwipeTime) > const Duration(milliseconds: 650)) {
        _emitGesture(
          TouchlessGestureType.proximityWave,
          Offset(_smoothX, _smoothY),
          now,
        );
      }
    }

    // Minimum active pixels to qualify as hand motion (at least ~0.3% of the frame or 12 pixels)
    final minActivePixels = math.max(12, (totalGridPixels * 0.003).round());
    final hasHandMotion = !isGlobalFlash && (activePixels >= minActivePixels);

    _lastMotionMagnitude =
        (totalMotion / (totalGridPixels * 6)).clamp(0.0, 1.0);

    // If valid hand motion was detected
    if (hasHandMotion && totalMotion > 0) {
      final normGx = weightedX / (totalMotion * gridW);
      final normGy = weightedY / (totalMotion * gridH);

      double mappedX;
      double mappedY;

      if (swapAxes) {
        mappedX = invertX ? (1.0 - normGy) : normGy;
        mappedY = invertY ? (1.0 - normGx) : normGx;
      } else {
        mappedX = invertX ? (1.0 - normGx) : normGx;
        mappedY = invertY ? (1.0 - normGy) : normGy;
      }

      // Apply reach gain centered around 0.5 so motion comfortably spans entire screen
      if (gain != 1.0) {
        mappedX = ((mappedX - 0.5) * gain + 0.5).clamp(0.0, 1.0);
        mappedY = ((mappedY - 0.5) * gain + 0.5).clamp(0.0, 1.0);
      }

      // Compute delta vector for direction telemetry
      final dx = mappedX - _smoothX;
      final dy = mappedY - _smoothY;
      if (math.sqrt(dx * dx + dy * dy) > 0.015) {
        if (dx.abs() > dy.abs()) {
          _dominantDirection = dx > 0 ? 'Right ➡️' : 'Left ⬅️';
        } else {
          _dominantDirection = dy > 0 ? 'Down ⬇️' : 'Up ⬆️';
        }
      } else {
        _dominantDirection = 'Holding 🎯';
      }

      // Exponential moving average filter
      _smoothX = _smoothX + _alpha * (mappedX - _smoothX);
      _smoothY = _smoothY + _alpha * (mappedY - _smoothY);

      final point = TouchlessPoint(
        x: _smoothX,
        y: _smoothY,
        confidence: math.min(1.0, totalMotion / (gridW * gridH * 6)),
        isTracked: true,
      );

      _trackingController.add(point);

      if (!_isDisposed) {
        telemetryNotifier.value = OpticalFlowTelemetry(
          magnitude: _lastMotionMagnitude,
          direction: _dominantDirection,
          x: _smoothX,
          y: _smoothY,
          isTracking: true,
        );
      }

      // Analyze motion velocity for swipe gesture
      _analyzeSwipe(point, now);
    } else {
      _dominantDirection = 'Still';
      // Motion faded
      if (_motionHistory.isNotEmpty) {
        _motionHistory.clear();
      }
      if (!_isDisposed) {
        telemetryNotifier.value = OpticalFlowTelemetry(
          magnitude: _lastMotionMagnitude,
          direction: 'Still',
          x: _smoothX,
          y: _smoothY,
          isTracking: false,
        );
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

/// Real-time motion telemetry emitted by [OpticalFlowDetector].
class OpticalFlowTelemetry {
  /// Motion magnitude energy (0.0 to 1.0+).
  final double magnitude;

  /// Current dominant movement direction ('Left ⬅️', 'Right ➡️', 'Up ⬆️', 'Down ⬇️', 'Still 🎯', etc.).
  final String direction;

  /// Current smoothed normalized horizontal X coordinate (0.0 to 1.0).
  final double x;

  /// Current smoothed normalized vertical Y coordinate (0.0 to 1.0).
  final double y;

  /// Whether active motion is currently tracked.
  final bool isTracking;

  /// Creates an [OpticalFlowTelemetry] snapshot.
  const OpticalFlowTelemetry({
    this.magnitude = 0.0,
    this.direction = 'Still',
    this.x = 0.5,
    this.y = 0.5,
    this.isTracking = false,
  });
}

class _MotionSample {
  final double x;
  final double y;
  final DateTime time;
  _MotionSample(this.x, this.y, this.time);
}
