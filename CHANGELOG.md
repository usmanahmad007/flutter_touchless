# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-10-20

### Fixed
- Enforce strict `dart format` compliance across codebase for CI workflows.
- Responsive layout scaling in showcase example app to eliminate RenderFlex overflow on small viewports.
- Updated example smoke test suite to match the full-screen touchless audio player.

## [0.1.1] - 2026-10-20

### Changed
- Updated MIT License badge styling to standard blue in documentation.

## [0.1.0] - 2026-10-20

### Added
- **Hands-Free Air Gesture Engine**:
  - `TouchlessScope`: Top-level InheritedWidget and floating air cursor coordinator.
  - `TouchlessController`: Central state manager orchestrating spatial target tracking, dwell progress charge, and gesture event stream.
  - `TouchlessConfig`: Deep engine configuration supporting dwell duration, motion sensitivity, velocity thresholds, haptic feedback, and custom gesture sets.
- **Novel Detectors**:
  - `OpticalFlowDetector`: Pure-Dart, zero-native-dependency temporal frame-differencing and centroid tracker for real-time camera feeds at 60 FPS.
  - `ProximityWaveDetector`: Low-power proximity sensor wave detector for screen-off and cooking mode interactions.
  - `FacialMotionDetector`: Head nod (confirm) and head shake (dismiss/cancel) oscillation detector.
  - `MockTouchlessDetector`: Desktop, emulator, and unit test simulation engine.
- **Interactive UI Components**:
  - `TouchlessCursor`: Sci-Fi holographic glowing reticle with animated dwell progress arc and ambient pulse.
  - `TouchlessTarget`: Drop-in wrapper making any widget interactable via air cursor hover and dwell clicking with border charging effects.
  - `TouchlessScrollable`: Drop-in wrapper translating air swipes into smooth hands-free scrolling for `ListView`, `PageView`, and `SingleChildScrollView`.
  - `TouchlessStatusBar`: Floating HUD bar providing live tracking coordinates and animated gesture recognition badges.
- **Comprehensive Showcase Example**:
  - 🧑‍🍳 Cooking Mode: Hands-free step-by-step recipe reader with air swipe paging.
  - 🎬 Reels Mode: Vertical video feed with wave-up / wave-down scrolling and dwell liking.
  - 🎯 Arcade Mode: Dwell-click targets with score multipliers and haptic feedback.
  - ⚙️ Engine Control: Live camera PIP preview, sensitivity sliders, and manual test bench.
- Full test suite with 100% passing unit and widget tests.
