/// A hands-free touchless interaction framework for Flutter with air swipes,
/// virtual air cursor, dwell-click activation, head tracking, and proximity wave gestures.
library flutter_touchless;

// Models
export 'src/models/touchless_config.dart';
export 'src/models/touchless_cursor_style.dart';
export 'src/models/touchless_gesture.dart';
export 'src/models/touchless_point.dart';

// Controllers
export 'src/controllers/touchless_controller.dart';

// Detectors
export 'src/detectors/facial_motion_detector.dart';
export 'src/detectors/mock_touchless_detector.dart';
export 'src/detectors/optical_flow_detector.dart';
export 'src/detectors/proximity_wave_detector.dart';
export 'src/detectors/touchless_detector.dart';

// Painters
export 'src/painters/sci_fi_cursor_painter.dart';

// Widgets
export 'src/widgets/touchless_cursor.dart';
export 'src/widgets/touchless_scope.dart';
export 'src/widgets/touchless_scrollable.dart';
export 'src/widgets/touchless_status_bar.dart';
export 'src/widgets/touchless_target.dart';
