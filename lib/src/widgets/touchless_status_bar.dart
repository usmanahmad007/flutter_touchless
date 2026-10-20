import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/touchless_controller.dart';
import '../models/touchless_gesture.dart';

/// Floating futuristic HUD pill showing real-time detector status,
/// tracking confidence, and animated gesture detection badges.
class TouchlessStatusBar extends StatefulWidget {
  /// The controller to monitor.
  final TouchlessController controller;

  /// Background color of the status bar.
  final Color backgroundColor;

  /// Text label describing the active detector.
  final String detectorLabel;

  /// Creates a [TouchlessStatusBar].
  const TouchlessStatusBar({
    super.key,
    required this.controller,
    this.backgroundColor = const Color(0xDD14141E),
    this.detectorLabel = 'Touchless Active',
  });

  @override
  State<TouchlessStatusBar> createState() => _TouchlessStatusBarState();
}

class _TouchlessStatusBarState extends State<TouchlessStatusBar> {
  StreamSubscription<TouchlessGestureEvent>? _gestureSub;
  TouchlessGestureEvent? _recentGesture;
  Timer? _gestureBadgeTimer;

  @override
  void initState() {
    super.initState();
    _gestureSub = widget.controller.gestureStream.listen(_onGesture);
  }

  void _onGesture(TouchlessGestureEvent event) {
    if (!mounted) return;
    setState(() {
      _recentGesture = event;
    });
    _gestureBadgeTimer?.cancel();
    _gestureBadgeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _recentGesture = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _gestureSub?.cancel();
    _gestureBadgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final point = widget.controller.currentPoint;
        final isTracked = point.isTracked;
        final gesture = _recentGesture;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: gesture != null
                  ? const Color(0xFFFF4081)
                  : (isTracked ? const Color(0xFF00E5FF) : Colors.white24),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (gesture != null
                        ? const Color(0xFFFF4081)
                        : const Color(0xFF00E5FF))
                    .withAlpha(isTracked ? 50 : 15),
                blurRadius: 10.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing tracking indicator
              Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isTracked ? const Color(0xFF00FF66) : Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 8.0),

              // Main label or animated gesture badge
              if (gesture != null) ...[
                Text(
                  _formatGestureLabel(gesture.type),
                  style: const TextStyle(
                    color: Color(0xFFFF4081),
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Text(
                  widget.detectorLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isTracked) ...[
                  const SizedBox(width: 6.0),
                  Text(
                    '${(point.confidence * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatGestureLabel(TouchlessGestureType type) {
    switch (type) {
      case TouchlessGestureType.swipeLeft:
        return '👈 Wave Left';
      case TouchlessGestureType.swipeRight:
        return '👉 Wave Right';
      case TouchlessGestureType.swipeUp:
        return '👆 Wave Up';
      case TouchlessGestureType.swipeDown:
        return '👇 Wave Down';
      case TouchlessGestureType.headNod:
        return '👤 Head Nod';
      case TouchlessGestureType.headShake:
        return '👤 Head Shake';
      case TouchlessGestureType.proximityWave:
        return '🖐️ Proximity Wave';
      case TouchlessGestureType.dwellClick:
        return '🎯 Dwell Click';
      case TouchlessGestureType.pinch:
        return '🤏 Air Pinch';
      case TouchlessGestureType.airTap:
        return '👆 Air Tap';
    }
  }
}
