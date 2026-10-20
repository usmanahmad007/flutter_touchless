import 'package:flutter/widgets.dart';

/// Represents a 2D/3D tracking coordinate in normalized camera space (0.0 to 1.0).
@immutable
class TouchlessPoint {
  /// Normalized horizontal coordinate (0.0 = left, 1.0 = right).
  final double x;

  /// Normalized vertical coordinate (0.0 = top, 1.0 = bottom).
  final double y;

  /// Estimated relative depth or hand z-distance (0.0 = close, 1.0 = far).
  final double? z;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Whether the point is actively tracked by the detector.
  final bool isTracked;

  /// Creates a [TouchlessPoint].
  const TouchlessPoint({
    required this.x,
    required this.y,
    this.z,
    this.confidence = 1.0,
    this.isTracked = true,
  });

  /// Untracked point placeholder.
  static const TouchlessPoint untracked = TouchlessPoint(
    x: 0.5,
    y: 0.5,
    confidence: 0.0,
    isTracked: false,
  );

  /// Converts normalized point to screen pixel coordinates.
  Offset toOffset(Size screenSize) {
    return Offset(
      x.clamp(0.0, 1.0) * screenSize.width,
      y.clamp(0.0, 1.0) * screenSize.height,
    );
  }

  /// Linearly interpolates between two tracking points for smooth motion.
  static TouchlessPoint lerp(TouchlessPoint a, TouchlessPoint b, double t) {
    return TouchlessPoint(
      x: a.x + (b.x - a.x) * t,
      y: a.y + (b.y - a.y) * t,
      z: (a.z != null && b.z != null) ? a.z! + (b.z! - a.z!) * t : b.z,
      confidence: a.confidence + (b.confidence - a.confidence) * t,
      isTracked: b.isTracked,
    );
  }

  @override
  String toString() =>
      'TouchlessPoint(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, tracked: $isTracked)';
}
