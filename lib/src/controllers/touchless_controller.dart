import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../detectors/mock_touchless_detector.dart';
import '../detectors/touchless_detector.dart';
import '../models/touchless_config.dart';
import '../models/touchless_gesture.dart';
import '../models/touchless_point.dart';

/// Interactive target entry registered with the controller.
class _RegisteredTarget {
  final String id;
  final Rect screenBounds;
  final VoidCallback onActivated;
  _RegisteredTarget(this.id, this.screenBounds, this.onActivated);
}

/// Central state manager orchestrating touchless tracking, air cursor movement,
/// dwell-click countdowns, and gesture dispatching.
class TouchlessController extends ChangeNotifier {
  TouchlessConfig _config;
  TouchlessDetector _detector;
  final DateTime Function() _now;
  bool _isDisposed = false;

  StreamSubscription<TouchlessPoint>? _trackingSub;
  StreamSubscription<TouchlessGestureEvent>? _gestureSub;

  final StreamController<TouchlessGestureEvent> _gestureStreamController =
      StreamController<TouchlessGestureEvent>.broadcast(sync: true);

  TouchlessPoint _currentPoint = TouchlessPoint.untracked;
  TouchlessGestureEvent? _lastGesture;
  double _dwellProgress = 0.0;
  String? _hoveredTargetId;
  DateTime? _dwellStartTime;

  final Map<String, _RegisteredTarget> _targets = {};
  Size _screenSize = Size.zero;

  /// Creates a [TouchlessController].
  TouchlessController({
    TouchlessConfig config = const TouchlessConfig(),
    TouchlessDetector? detector,
    DateTime Function()? nowProvider,
  })  : _config = config,
        _detector = detector ?? MockTouchlessDetector(),
        _now = nowProvider ?? clock.now {
    _bindDetector();
  }

  /// Current configuration.
  TouchlessConfig get config => _config;

  /// Updates the engine configuration.
  set config(TouchlessConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  /// Currently active detector.
  TouchlessDetector get detector => _detector;

  /// Current normalized tracking point.
  TouchlessPoint get currentPoint => _currentPoint;

  /// Current dwell progress between 0.0 and 1.0.
  double get dwellProgress => _dwellProgress;

  /// ID of the currently hovered target, if any.
  String? get hoveredTargetId => _hoveredTargetId;

  /// The most recently recognized gesture event.
  TouchlessGestureEvent? get lastGesture => _lastGesture;

  /// Stream of recognized touchless gestures.
  Stream<TouchlessGestureEvent> get gestureStream =>
      _gestureStreamController.stream;

  /// Updates the reference screen size for pixel coordinate mapping.
  void updateScreenSize(Size size) {
    _screenSize = size;
  }

  /// Swaps out the current detector for a new one.
  Future<void> setDetector(TouchlessDetector newDetector) async {
    await _trackingSub?.cancel();
    await _gestureSub?.cancel();
    await _detector.dispose();

    _detector = newDetector;
    _bindDetector();
    if (_detector.isRunning == false) {
      await _detector.start();
    }
    notifyListeners();
  }

  void _bindDetector() {
    _trackingSub = _detector.trackingStream.listen(_onTrackingPointReceived);
    _gestureSub = _detector.gestureStream.listen(_onGestureReceived);
  }

  void _onTrackingPointReceived(TouchlessPoint point) {
    _currentPoint = point;

    if (_screenSize != Size.zero && point.isTracked) {
      final pixelPos = point.toOffset(_screenSize);
      _checkTargetHover(pixelPos);
    } else {
      _resetDwell();
    }

    notifyListeners();
  }

  void _onGestureReceived(TouchlessGestureEvent event) {
    if (!_config.isGestureEnabled(event.type)) return;

    _lastGesture = event;
    _gestureStreamController.add(event);

    if (_config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    notifyListeners();
  }

  /// Registers an interactive target with screen bounds and activation callback.
  void registerTarget(String id, Rect screenBounds, VoidCallback onActivated) {
    _targets[id] = _RegisteredTarget(id, screenBounds, onActivated);
  }

  /// Unregisters an interactive target when it leaves the widget tree.
  void unregisterTarget(String id) {
    if (_isDisposed) return;
    _targets.remove(id);
    if (_hoveredTargetId == id) {
      _resetDwell();
    }
  }

  void _checkTargetHover(Offset pixelPos) {
    if (_isDisposed) return;
    String? matchedId;
    _RegisteredTarget? matchedTarget;

    for (final entry in _targets.entries) {
      if (entry.value.screenBounds.contains(pixelPos)) {
        matchedId = entry.key;
        matchedTarget = entry.value;
        break;
      }
    }

    if (matchedId != null && matchedTarget != null) {
      if (_hoveredTargetId != matchedId) {
        // Just entered a new target
        _hoveredTargetId = matchedId;
        _dwellStartTime = _now();
        _dwellProgress = 0.0;
        if (_config.enableHapticFeedback) {
          HapticFeedback.selectionClick();
        }
      } else {
        // Continuing hover: advance dwell progress
        final elapsedMs = _now().difference(_dwellStartTime!).inMilliseconds;
        final totalMs = _config.dwellDuration.inMilliseconds;
        _dwellProgress = (elapsedMs / totalMs).clamp(0.0, 1.0);

        if (_dwellProgress >= 1.0) {
          // Dwell click trigger!
          matchedTarget.onActivated();
          if (_config.enableHapticFeedback) {
            HapticFeedback.mediumImpact();
          }

          final clickEvent = TouchlessGestureEvent(
            type: TouchlessGestureType.dwellClick,
            normalizedPosition: Offset(_currentPoint.x, _currentPoint.y),
            confidence: 1.0,
            timestamp: _now(),
            metadata: {'targetId': matchedId},
          );

          _lastGesture = clickEvent;
          _gestureStreamController.add(clickEvent);

          // Reset dwell progress to avoid continuous rapid clicking
          _dwellStartTime = _now();
          _dwellProgress = 0.0;
        }
      }
    } else {
      _resetDwell();
    }
  }

  void _resetDwell() {
    if (_isDisposed) return;
    if (_hoveredTargetId != null || _dwellProgress != 0.0) {
      _hoveredTargetId = null;
      _dwellStartTime = null;
      _dwellProgress = 0.0;
      notifyListeners();
    }
  }

  /// Manually triggers a gesture through the controller.
  void triggerGesture(TouchlessGestureType type, {Offset? position}) {
    if (_isDisposed) return;
    final event = TouchlessGestureEvent(
      type: type,
      normalizedPosition: position ??
          (_currentPoint.isTracked
              ? Offset(_currentPoint.x, _currentPoint.y)
              : const Offset(0.5, 0.5)),
      confidence: 1.0,
      timestamp: _now(),
    );
    _onGestureReceived(event);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _trackingSub?.cancel();
    _gestureSub?.cancel();
    _detector.dispose();
    _gestureStreamController.close();
    super.dispose();
  }
}
