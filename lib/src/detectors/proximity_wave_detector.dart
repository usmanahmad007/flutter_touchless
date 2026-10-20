import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/touchless_gesture.dart';
import '../models/touchless_point.dart';
import 'touchless_detector.dart';

/// Low-power detector utilizing device proximity and ambient light sensors
/// to recognize hand waves and hover covers over the screen.
class ProximityWaveDetector implements TouchlessDetector {
  final StreamController<TouchlessPoint> _trackingController =
      StreamController<TouchlessPoint>.broadcast();
  final StreamController<TouchlessGestureEvent> _gestureController =
      StreamController<TouchlessGestureEvent>.broadcast();

  bool _isRunning = false;
  DateTime? _coverStartTime;
  final Duration _minWaveDuration;
  final Duration _maxWaveDuration;
  final Duration _cooldown;
  DateTime _lastGestureTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Creates a [ProximityWaveDetector].
  ProximityWaveDetector({
    Duration minWaveDuration = const Duration(milliseconds: 60),
    Duration maxWaveDuration = const Duration(milliseconds: 700),
    Duration cooldown = const Duration(milliseconds: 350),
  })  : _minWaveDuration = minWaveDuration,
        _maxWaveDuration = maxWaveDuration,
        _cooldown = cooldown;

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

  /// Ingests a proximity sensor reading.
  ///
  /// - [isNear]: True if an object is within immediate sensor range (~5 cm).
  void handleProximityChange(bool isNear) {
    if (!_isRunning) return;

    final now = DateTime.now();

    if (isNear) {
      _coverStartTime ??= now;
      // Proximity emits a top-center virtual point
      _trackingController.add(
        const TouchlessPoint(
          x: 0.5,
          y: 0.15,
          confidence: 0.95,
          isTracked: true,
        ),
      );
    } else {
      if (_coverStartTime != null) {
        final duration = now.difference(_coverStartTime!);
        _coverStartTime = null;

        if (duration >= _minWaveDuration &&
            duration <= _maxWaveDuration &&
            now.difference(_lastGestureTime) > _cooldown) {
          _lastGestureTime = now;
          _gestureController.add(
            TouchlessGestureEvent(
              type: TouchlessGestureType.proximityWave,
              normalizedPosition: const Offset(0.5, 0.15),
              confidence: 0.95,
              timestamp: now,
              metadata: {'durationMs': duration.inMilliseconds},
            ),
          );
        }
      }
    }
  }

  /// Ingests an ambient light reading (in Lux).
  ///
  /// Rapid drops in illuminance indicate a hand waving over the sensor.
  double _prevLux = 500.0;
  void handleAmbientLight(double lux) {
    if (!_isRunning) return;

    final drop = _prevLux - lux;
    if (drop > 150 && lux < 60) {
      handleProximityChange(true);
    } else if (lux > 120 && _coverStartTime != null) {
      handleProximityChange(false);
    }
    _prevLux = lux;
  }

  /// Programmatically simulate a wave gesture (useful for testing & demo modes).
  void simulateWave() {
    handleProximityChange(true);
    Future.delayed(const Duration(milliseconds: 200), () {
      handleProximityChange(false);
    });
  }
}
