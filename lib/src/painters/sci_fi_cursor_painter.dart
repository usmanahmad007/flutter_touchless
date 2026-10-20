import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/touchless_cursor_style.dart';

/// Renders an animated futuristic air cursor with glowing crosshairs,
/// circular dwell ring, and neon bloom shader.
class SciFiCursorPainter extends CustomPainter {
  /// Cursor style configuration.
  final TouchlessCursorStyle style;

  /// Current dwell progress between 0.0 and 1.0.
  final double dwellProgress;

  /// Whether the tracking source has high confidence.
  final bool isTracked;

  /// Animation phase (0.0 to 1.0) for pulsing idle breath.
  final double pulseAnimation;

  /// Creates a [SciFiCursorPainter].
  SciFiCursorPainter({
    required this.style,
    required this.dwellProgress,
    required this.isTracked,
    required this.pulseAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isTracked) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        (style.size / 2) + (math.sin(pulseAnimation * 2 * math.pi) * 1.5);

    final currentColor = Color.lerp(
      style.primaryColor,
      style.activeColor,
      dwellProgress,
    )!;

    // 1. Holographic outer bloom glow
    final glowPaint = Paint()
      ..color = currentColor.withAlpha((70 + (dwellProgress * 120)).toInt())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, style.glowRadius)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 2, glowPaint);

    // 2. Outer bracket reticle segments
    final strokePaint = Paint()
      ..color = currentColor
      ..strokeWidth = style.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arcSpan = math.pi / 2.8;
    const offsetAngle = math.pi / 4;

    for (int i = 0; i < 4; i++) {
      final startAngle = offsetAngle + (i * math.pi / 2) - (arcSpan / 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcSpan,
        false,
        strokePaint,
      );
    }

    // 3. Center tracking dot / pupil
    final centerDotPaint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    final dotRadius = 3.0 + (dwellProgress * 3.0);
    canvas.drawCircle(center, dotRadius, centerDotPaint);

    // 4. Dwell progress ring
    if (style.showDwellRing && dwellProgress > 0.0) {
      final dwellPaint = Paint()
        ..color = style.activeColor
        ..strokeWidth = style.strokeWidth + 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 6.0),
        -math.pi / 2,
        dwellProgress * 2 * math.pi,
        false,
        dwellPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SciFiCursorPainter oldDelegate) {
    return oldDelegate.dwellProgress != dwellProgress ||
        oldDelegate.isTracked != isTracked ||
        oldDelegate.pulseAnimation != pulseAnimation ||
        oldDelegate.style != style;
  }
}
