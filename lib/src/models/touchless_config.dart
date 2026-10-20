import 'package:flutter/foundation.dart';
import 'touchless_cursor_style.dart';
import 'touchless_gesture.dart';

/// Comprehensive configuration settings for the touchless engine.
@immutable
class TouchlessConfig {
  /// Dwell time required to trigger a click when hovering stationary over a target.
  final Duration dwellDuration;

  /// Sensitivity multiplier for motion tracking (0.5 = sluggish, 2.0 = fast).
  final double motionSensitivity;

  /// Velocity threshold needed to register an air swipe (normalized units/sec).
  final double swipeVelocityThreshold;

  /// Whether the floating virtual air cursor is visible on screen.
  final bool enableAirCursor;

  /// Whether air swipes (left, right, up, down) are actively detected.
  final bool enableAirSwipes;

  /// Whether head nods and shakes are actively detected.
  final bool enableHeadGestures;

  /// Whether low-power proximity sensor wave gestures are actively detected.
  final bool enableProximityGestures;

  /// Whether subtle haptic feedback plays when gestures trigger.
  final bool enableHapticFeedback;

  /// Enabled subset of gesture types. If empty, all supported gestures are active.
  final Set<TouchlessGestureType> enabledGestures;

  /// Visual styling of the air cursor.
  final TouchlessCursorStyle cursorStyle;

  /// Creates a [TouchlessConfig].
  const TouchlessConfig({
    this.dwellDuration = const Duration(milliseconds: 650),
    this.motionSensitivity = 1.0,
    this.swipeVelocityThreshold = 0.45,
    this.enableAirCursor = true,
    this.enableAirSwipes = true,
    this.enableHeadGestures = true,
    this.enableProximityGestures = true,
    this.enableHapticFeedback = true,
    this.enabledGestures = const {},
    this.cursorStyle = const TouchlessCursorStyle(),
  });

  /// Checks if a specific gesture type is enabled.
  bool isGestureEnabled(TouchlessGestureType type) {
    if (enabledGestures.isNotEmpty && !enabledGestures.contains(type)) {
      return false;
    }
    switch (type) {
      case TouchlessGestureType.swipeLeft:
      case TouchlessGestureType.swipeRight:
      case TouchlessGestureType.swipeUp:
      case TouchlessGestureType.swipeDown:
        return enableAirSwipes;
      case TouchlessGestureType.headNod:
      case TouchlessGestureType.headShake:
        return enableHeadGestures;
      case TouchlessGestureType.proximityWave:
        return enableProximityGestures;
      case TouchlessGestureType.dwellClick:
      case TouchlessGestureType.pinch:
      case TouchlessGestureType.airTap:
        return enableAirCursor;
    }
  }

  /// Copies config with overridden properties.
  TouchlessConfig copyWith({
    Duration? dwellDuration,
    double? motionSensitivity,
    double? swipeVelocityThreshold,
    bool? enableAirCursor,
    bool? enableAirSwipes,
    bool? enableHeadGestures,
    bool? enableProximityGestures,
    bool? enableHapticFeedback,
    Set<TouchlessGestureType>? enabledGestures,
    TouchlessCursorStyle? cursorStyle,
  }) {
    return TouchlessConfig(
      dwellDuration: dwellDuration ?? this.dwellDuration,
      motionSensitivity: motionSensitivity ?? this.motionSensitivity,
      swipeVelocityThreshold:
          swipeVelocityThreshold ?? this.swipeVelocityThreshold,
      enableAirCursor: enableAirCursor ?? this.enableAirCursor,
      enableAirSwipes: enableAirSwipes ?? this.enableAirSwipes,
      enableHeadGestures: enableHeadGestures ?? this.enableHeadGestures,
      enableProximityGestures:
          enableProximityGestures ?? this.enableProximityGestures,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enabledGestures: enabledGestures ?? this.enabledGestures,
      cursorStyle: cursorStyle ?? this.cursorStyle,
    );
  }
}
