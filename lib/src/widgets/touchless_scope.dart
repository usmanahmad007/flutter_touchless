import 'package:flutter/material.dart';
import '../controllers/touchless_controller.dart';
import 'touchless_cursor.dart';

/// Top-level provider and overlay coordinator for touchless interactions.
///
/// Wraps your application or screen, dispatches touchless events,
/// and renders the floating holographic air cursor.
class TouchlessScope extends StatefulWidget {
  /// The controller driving touchless tracking and gestures.
  final TouchlessController controller;

  /// The child widget tree beneath the touchless overlay.
  final Widget child;

  /// Whether to display the floating virtual air cursor overlay.
  final bool showCursor;

  /// Creates a [TouchlessScope].
  const TouchlessScope({
    super.key,
    required this.controller,
    required this.child,
    this.showCursor = true,
  });

  /// Retrieves the nearest [TouchlessController] ancestor from the widget tree.
  static TouchlessController of(BuildContext context) {
    final _InheritedTouchlessScope? scope =
        context.dependOnInheritedWidgetOfExactType<_InheritedTouchlessScope>();
    assert(scope != null, 'No TouchlessScope found in the widget tree.');
    return scope!.controller;
  }

  /// Retrieves the nearest [TouchlessController] without subscribing to rebuilds.
  static TouchlessController? maybeOf(BuildContext context) {
    final _InheritedTouchlessScope? scope =
        context.dependOnInheritedWidgetOfExactType<_InheritedTouchlessScope>();
    return scope?.controller;
  }

  @override
  State<TouchlessScope> createState() => _TouchlessScopeState();
}

class _TouchlessScopeState extends State<TouchlessScope> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.updateScreenSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return _InheritedTouchlessScope(
          controller: widget.controller,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (widget.showCursor && widget.controller.config.enableAirCursor)
                IgnorePointer(
                  child: TouchlessCursor(controller: widget.controller),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InheritedTouchlessScope extends InheritedWidget {
  final TouchlessController controller;

  const _InheritedTouchlessScope({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _InheritedTouchlessScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
