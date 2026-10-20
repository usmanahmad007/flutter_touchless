import 'package:flutter/material.dart';
import '../controllers/touchless_controller.dart';
import '../painters/sci_fi_cursor_painter.dart';

/// Floating visual air cursor widget that tracks hand/head coordinates
/// and visualizes dwell countdown charging.
class TouchlessCursor extends StatefulWidget {
  /// The controller driving the cursor.
  final TouchlessController controller;

  /// Creates a [TouchlessCursor].
  const TouchlessCursor({super.key, required this.controller});

  @override
  State<TouchlessCursor> createState() => _TouchlessCursorState();
}

class _TouchlessCursorState extends State<TouchlessCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _pulseController]),
      builder: (context, _) {
        final point = widget.controller.currentPoint;
        if (!point.isTracked) return const SizedBox.shrink();

        final style = widget.controller.config.cursorStyle;
        final size = style.size + (style.glowRadius * 2);

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            final targetX = point.x.clamp(0.0, 1.0) * screenWidth;
            final targetY = point.y.clamp(0.0, 1.0) * screenHeight;

            return Transform.translate(
              offset: Offset(targetX - (size / 2), targetY - (size / 2)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: SciFiCursorPainter(
                      style: style,
                      dwellProgress: widget.controller.dwellProgress,
                      isTracked: point.isTracked,
                      pulseAnimation: _pulseController.value,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
