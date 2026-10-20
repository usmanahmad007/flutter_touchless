import 'dart:async';
import '../models/touchless_gesture.dart';
import '../models/touchless_point.dart';

/// Abstract contract for input sources providing touchless tracking coordinates and gestures.
abstract class TouchlessDetector {
  /// Stream emitting real-time tracking points (normalized 0.0 to 1.0).
  Stream<TouchlessPoint> get trackingStream;

  /// Stream emitting recognized discrete gesture events.
  Stream<TouchlessGestureEvent> get gestureStream;

  /// Whether this detector is currently active and processing inputs.
  bool get isRunning;

  /// Initializes hardware or sensors needed for detection.
  Future<void> initialize();

  /// Starts listening and emitting events.
  Future<void> start();

  /// Temporarily pauses detection.
  Future<void> pause();

  /// Disposes of any resources, streams, or camera feeds.
  Future<void> dispose();
}
