import 'package:flutter/widgets.dart';

/// Recognized types of hands-free touchless gestures.
enum TouchlessGestureType {
  /// Hand wave moving leftwards.
  swipeLeft,

  /// Hand wave moving rightwards.
  swipeRight,

  /// Hand wave moving upwards (e.g. scroll down in feed).
  swipeUp,

  /// Hand wave moving downwards (e.g. scroll up in feed).
  swipeDown,

  /// Quick hand or finger pinch gesture.
  pinch,

  /// Dwell completion (holding cursor steady over a target).
  dwellClick,

  /// Vertical head nod (affirming / selecting).
  headNod,

  /// Horizontal head shake (cancelling / dismissing).
  headShake,

  /// Hand hovering or waving over proximity sensor.
  proximityWave,

  /// Air tap / forward poke gesture.
  airTap,
}

/// An emitted touchless gesture event.
@immutable
class TouchlessGestureEvent {
  /// The type of gesture recognized.
  final TouchlessGestureType type;

  /// The normalized screen position of the gesture (0.0 to 1.0), if spatial.
  final Offset? normalizedPosition;

  /// Detection confidence score from 0.0 to 1.0.
  final double confidence;

  /// Timestamp when the gesture was detected.
  final DateTime timestamp;

  /// Additional payload data provided by the detector.
  final Map<String, dynamic> metadata;

  /// Creates a [TouchlessGestureEvent].
  const TouchlessGestureEvent({
    required this.type,
    this.normalizedPosition,
    this.confidence = 1.0,
    required this.timestamp,
    this.metadata = const {},
  });

  @override
  String toString() =>
      'TouchlessGestureEvent(type: $type, pos: $normalizedPosition, confidence: ${confidence.toStringAsFixed(2)})';
}
