import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/touchless_controller.dart';
import '../models/touchless_gesture.dart';
import 'touchless_scope.dart';

/// Wraps any scrollable view (ListView, PageView, SingleChildScrollView)
/// and translates touchless air-swipes and head gestures into hands-free scrolling.
class TouchlessScrollable extends StatefulWidget {
  /// The scrollable child widget.
  final Widget child;

  /// Optional ScrollController to control directly.
  final ScrollController? scrollController;

  /// Optional PageController if wrapping a PageView.
  final PageController? pageController;

  /// Distance in logical pixels to scroll per air swipe. Default 350.0.
  final double scrollDelta;

  /// Duration of the smooth animated scroll. Default 300ms.
  final Duration animationDuration;

  /// Animation curve for the scroll.
  final Curve animationCurve;

  /// Optional custom callback when swipeUp is detected.
  final VoidCallback? onSwipeUp;

  /// Optional custom callback when swipeDown is detected.
  final VoidCallback? onSwipeDown;

  /// Optional custom callback when swipeLeft is detected.
  final VoidCallback? onSwipeLeft;

  /// Optional custom callback when swipeRight is detected.
  final VoidCallback? onSwipeRight;

  /// Optional custom callback when proximity wave is detected.
  final VoidCallback? onProximityWave;

  /// Creates a [TouchlessScrollable].
  const TouchlessScrollable({
    super.key,
    required this.child,
    this.scrollController,
    this.pageController,
    this.scrollDelta = 350.0,
    this.animationDuration = const Duration(milliseconds: 320),
    this.animationCurve = Curves.easeOutCubic,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onProximityWave,
  });

  @override
  State<TouchlessScrollable> createState() => _TouchlessScrollableState();
}

class _TouchlessScrollableState extends State<TouchlessScrollable> {
  TouchlessController? _controller;
  StreamSubscription<TouchlessGestureEvent>? _gestureSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = TouchlessScope.maybeOf(context);
    if (newController != _controller) {
      _gestureSub?.cancel();
      _controller = newController;
      _gestureSub = _controller?.gestureStream.listen(_handleGesture);
    }
  }

  void _handleGesture(TouchlessGestureEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case TouchlessGestureType.swipeUp:
        if (widget.onSwipeUp != null) {
          widget.onSwipeUp!();
        } else {
          _scrollRelative(widget.scrollDelta);
        }
        break;

      case TouchlessGestureType.swipeDown:
        if (widget.onSwipeDown != null) {
          widget.onSwipeDown!();
        } else {
          _scrollRelative(-widget.scrollDelta);
        }
        break;

      case TouchlessGestureType.swipeRight:
        if (widget.onSwipeRight != null) {
          widget.onSwipeRight!();
        } else if (widget.pageController != null &&
            widget.pageController!.hasClients) {
          widget.pageController!.previousPage(
            duration: widget.animationDuration,
            curve: widget.animationCurve,
          );
        }
        break;

      case TouchlessGestureType.swipeLeft:
        if (widget.onSwipeLeft != null) {
          widget.onSwipeLeft!();
        } else if (widget.pageController != null &&
            widget.pageController!.hasClients) {
          widget.pageController!.nextPage(
            duration: widget.animationDuration,
            curve: widget.animationCurve,
          );
        }
        break;

      case TouchlessGestureType.proximityWave:
        if (widget.onProximityWave != null) {
          widget.onProximityWave!();
        } else {
          // Default proximity wave advances to next page/item
          _scrollRelative(widget.scrollDelta);
        }
        break;

      default:
        break;
    }
  }

  void _scrollRelative(double delta) {
    final controller = widget.scrollController;
    if (controller != null && controller.hasClients) {
      final target = (controller.offset + delta).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      );
      controller.animateTo(
        target,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    }
  }

  @override
  void dispose() {
    _gestureSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
