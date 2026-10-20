import 'package:flutter/material.dart';
import '../controllers/touchless_controller.dart';
import 'touchless_scope.dart';

/// Wraps any widget to make it interactable via air cursor hover and dwell clicking.
///
/// Automatically tracks screen bounds, renders subtle hover animations,
/// and triggers [onTouchlessTap] or [onTap] when the user hovers over it.
class TouchlessTarget extends StatefulWidget {
  /// Unique identifier for this target. If null, a key or identity hash is used.
  final String? id;

  /// The interactive child widget (e.g. Button, Card, Icon).
  final Widget child;

  /// Callback executed when activated by dwell-click or air-tap.
  final VoidCallback? onTouchlessTap;

  /// Standard touch callback. If [onTouchlessTap] is null, this is called instead.
  final VoidCallback? onTap;

  /// Highlight border color when the air cursor hovers over this target.
  final Color hoverColor;

  /// Scale factor applied during hover (e.g. 1.04 for subtle pop).
  final double hoverScale;

  /// Whether to display a border glow charging effect during dwell.
  final bool showDwellBorder;

  /// Creates a [TouchlessTarget].
  const TouchlessTarget({
    super.key,
    this.id,
    required this.child,
    this.onTouchlessTap,
    this.onTap,
    this.hoverColor = const Color(0xFF00E5FF),
    this.hoverScale = 1.04,
    this.showDwellBorder = true,
  });

  @override
  State<TouchlessTarget> createState() => _TouchlessTargetState();
}

class _TouchlessTargetState extends State<TouchlessTarget> {
  late final String _targetId;
  TouchlessController? _controller;
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targetId = widget.id ?? 'target_${identityHashCode(this)}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBounds());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = TouchlessScope.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBounds());
  }

  void _updateBounds() {
    if (!mounted || _controller == null) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final bounds = position & renderBox.size;
      _controller!.registerTarget(_targetId, bounds, _handleActivation);
    }
  }

  void _handleActivation() {
    if (widget.onTouchlessTap != null) {
      widget.onTouchlessTap!();
    } else if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  void dispose() {
    _controller?.unregisterTarget(_targetId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Schedule bound update after build/layout changes
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBounds());

    final controller = _controller;
    final isHovered = controller?.hoveredTargetId == _targetId;
    final dwellProgress = isHovered ? (controller?.dwellProgress ?? 0.0) : 0.0;

    return GestureDetector(
      key: _key,
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else if (widget.onTouchlessTap != null) {
          widget.onTouchlessTap!();
        }
      },
      child: AnimatedScale(
        scale: isHovered ? widget.hoverScale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: CustomPaint(
          foregroundPainter: widget.showDwellBorder && isHovered
              ? _TargetDwellPainter(
                  progress: dwellProgress,
                  color: widget.hoverColor,
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}

class _TargetDwellPainter extends CustomPainter {
  final double progress;
  final Color color;

  _TargetDwellPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14.0));

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withAlpha((progress * 90).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(rrect, glowPaint);

    // Border charging stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final totalLen = metrics.first.length;
      final extractPath = metrics.first.extractPath(0.0, totalLen * progress);
      canvas.drawPath(extractPath, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TargetDwellPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
