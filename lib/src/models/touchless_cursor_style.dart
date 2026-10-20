import 'package:flutter/material.dart';

/// Visual styling configuration for the floating air cursor.
@immutable
class TouchlessCursorStyle {
  /// The primary neon color of the reticle.
  final Color primaryColor;

  /// The active color when dwell-clicking or pinching.
  final Color activeColor;

  /// Diameter of the outer reticle in logical pixels.
  final double size;

  /// Spread radius of the holographic glow shader.
  final double glowRadius;

  /// Stroke width of the reticle outline.
  final double strokeWidth;

  /// Whether to render animated trailing particles behind fast cursor motion.
  final bool showTrailingParticles;

  /// Whether to render the circular dwell progress ring when stationary.
  final bool showDwellRing;

  /// Creates a [TouchlessCursorStyle].
  const TouchlessCursorStyle({
    this.primaryColor = const Color(0xFF00E5FF),
    this.activeColor = const Color(0xFFFF4081),
    this.size = 38.0,
    this.glowRadius = 14.0,
    this.strokeWidth = 2.5,
    this.showTrailingParticles = true,
    this.showDwellRing = true,
  });

  /// Sci-Fi holographic HUD preset with cyan & magenta neon accents.
  factory TouchlessCursorStyle.sciFi() => const TouchlessCursorStyle(
        primaryColor: Color(0xFF00E5FF),
        activeColor: Color(0xFFFF4081),
        size: 42.0,
        glowRadius: 16.0,
        strokeWidth: 2.5,
        showTrailingParticles: true,
      );

  /// Minimal clean circle preset.
  factory TouchlessCursorStyle.minimal() => const TouchlessCursorStyle(
        primaryColor: Colors.white,
        activeColor: Color(0xFF00E5FF),
        size: 28.0,
        glowRadius: 6.0,
        strokeWidth: 2.0,
        showTrailingParticles: false,
      );

  /// High-visibility accessibility preset for high-contrast viewing.
  factory TouchlessCursorStyle.accessibility() => const TouchlessCursorStyle(
        primaryColor: Color(0xFFFFD700),
        activeColor: Color(0xFF00FF66),
        size: 52.0,
        glowRadius: 20.0,
        strokeWidth: 3.5,
        showTrailingParticles: true,
      );
}
