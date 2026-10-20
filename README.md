# flutter_touchless 🖐️✨

[![Pub Version](https://img.shields.io/pub/v/flutter_touchless?color=00E5FF&logo=dart)](https://pub.dev/packages/flutter_touchless)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Flutter Platform](https://img.shields.io/badge/Platform-Flutter%20%7C%20Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue.svg)](https://flutter.dev)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/usmanahmad007/flutter_touchless/pulls)

A futuristic, zero-native-dependency **hands-free touchless interaction framework** for Flutter. Control your apps using **air swipes**, **virtual air cursors**, **dwell-click activation**, **head nods/shakes**, and **low-power proximity waves** — without ever touching the glass!

---

```
                       🖐️  Air Hand Wave
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
   [ Camera Optical Flow ]         [ Proximity / Light ]
            │                                 │
            └────────────────┬────────────────┘
                             ▼
                   [ TouchlessController ]
                             │
      ┌──────────────────────┼──────────────────────┐
      ▼                      ▼                      ▼
🎯 Virtual Air Cursor   👆 Air-Swipe Scroll    ⏱️ Dwell-Click
(Holographic Reticle)  (Feed / Recipe / Pager) (Hands-Free Buttons)
```

---

## 🌟 Why flutter_touchless?

- 🧑‍🍳 **Kitchen & Recipe Apps**: Read recipes and flip steps with wet, floury, or greasy hands without smudging your phone screen.
- 📱 **Hands-Free Feeds**: Scroll short-form reels, TikToks, or articles with quick air swipes from across your desk or treadmill.
- ♿ **Accessibility (a11y)**: Empower users with limited motor control or tremors using dwell-clicking and head tracking.
- 🏥 **Sterile & Medical Kiosks**: Interact with clinical tablets and public display screens without physical contact.
- ⚡ **Zero Native C++/Python Dependencies**: Pure-Dart computer vision temporal optical flow running at 60 FPS on any Flutter-supported platform.

---

## 🚀 Key Features

| Feature | Description |
| :--- | :--- |
| **🎯 Virtual Air Cursor** | Steer a floating holographic cursor in mid-air using hand centroid tracking. |
| **⏱️ Dwell-Click Activation** | Hover stationary over any target to charge an animated circular countdown that clicks automatically. |
| **👆 Directional Air Swipes** | Swipe Up, Down, Left, or Right to scroll list views, page views, and presentations hands-free. |
| **🙆 Head & Facial Gestures** | Head nod to confirm dialogues/actions; head shake to dismiss notifications or cancel. |
| **🌊 Low-Power Proximity Waves** | Trigger actions using hardware proximity or ambient light sensors without running the camera. |
| **🕹️ Test Simulator Built-in** | Test on emulators, simulators, and desktop environments using touch drag and simulation chips. |

---

## 📦 Installation

Add `flutter_touchless` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_touchless: ^0.1.0
```

Or install via terminal:

```bash
flutter pub add flutter_touchless
```

---

## ⚡ Quick Start

### 1. Wrap your screen in `TouchlessScope`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_touchless/flutter_touchless.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final TouchlessController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TouchlessController(
      config: const TouchlessConfig(
        dwellDuration: Duration(milliseconds: 650),
        enableAirCursor: true,
        enableAirSwipes: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TouchlessScope(
        controller: _controller,
        child: const HomeScreen(),
      ),
    );
  }
}
```

### 2. Make buttons dwell-clickable with `TouchlessTarget`

Wrap any button or card in `TouchlessTarget`. When the air cursor hovers over it, an animated glowing border charges up and triggers `onTouchlessTap`:

```dart
TouchlessTarget(
  id: 'order_now_button',
  hoverColor: const Color(0xFF00E5FF),
  hoverScale: 1.05,
  onTouchlessTap: () {
    print('Button activated hands-free via dwell click!');
  },
  child: ElevatedButton(
    onPressed: () {},
    child: const Text('Order Now'),
  ),
)
```

### 3. Scroll lists and feeds hands-free with `TouchlessScrollable`

Wrap any `ListView`, `PageView`, or `SingleChildScrollView` with `TouchlessScrollable`:

```dart
TouchlessScrollable(
  scrollController: myScrollController,
  scrollDelta: 300.0,
  child: ListView.builder(
    controller: myScrollController,
    itemCount: 50,
    itemBuilder: (context, index) => ListTile(
      title: Text('Item #$index'),
    ),
  ),
)
```

---

## 📷 Connecting Real Camera Optical Flow

You can stream raw grayscale / luminance frames directly from Flutter's official `camera` plugin into `OpticalFlowDetector`:

```dart
final flowDetector = OpticalFlowDetector(
  smoothingFactor: 0.35,
  swipeSensitivity: 0.22,
);
await flowDetector.start();

await cameraController.startImageStream((CameraImage image) {
  if (image.planes.isNotEmpty) {
    flowDetector.processFrame(
      image.planes[0].bytes, // Y-plane luminance
      image.width,
      image.height,
      step: 6, // 6x sub-sampling for 60 FPS mobile performance
    );
  }
});

// Bind to your touchless controller
await controller.setDetector(flowDetector);
```

---

## 🎨 Customizing the Air Cursor

Choose from pre-built sci-fi themes or customize reticle color, glow radius, and particle effects:

```dart
TouchlessConfig(
  cursorStyle: TouchlessCursorStyle(
    primaryColor: Color(0xFF00E5FF),
    activeColor: Color(0xFFFF4081),
    size: 44.0,
    glowRadius: 16.0,
    strokeWidth: 2.5,
    showTrailingParticles: true,
  ),
)

// Or use built-in presets:
TouchlessCursorStyle.sciFi();
TouchlessCursorStyle.minimal();
TouchlessCursorStyle.accessibility();
```

---

## 🕹️ Testing in Simulator / Emulator

`flutter_touchless` comes with `MockTouchlessDetector` out-of-the-box. You can simulate coordinates or dispatch gestures directly in tests and debug UI:

```dart
final mockDetector = MockTouchlessDetector();
final controller = TouchlessController(detector: mockDetector);

// Simulate hand pointing at center of screen
mockDetector.simulatePoint(0.5, 0.5);

// Simulate air swipe
controller.triggerGesture(TouchlessGestureType.swipeUp);
```

---

## 📱 Interactive Showcase App

Check out the included `example/` app for 4 interactive real-world demo modes:

1. **🧑‍🍳 Cooking Mode**: Recipe card reader with step-by-step air swipe paging.
2. **🎬 Reels Mode**: Vertical video feed with wave-up / wave-down scrolling.
3. **🎯 Arcade Lab**: Dwell-click buttons with score multipliers and haptic bursts.
4. **⚙️ Engine Control**: Live camera picture-in-picture preview, sensitivity sliders, and manual test bench.

Run the example:

```bash
cd example
flutter run
```

---

## 🛠️ Configuration Options

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dwellDuration` | `Duration` | `650ms` | Stationary time required to trigger a dwell-click. |
| `motionSensitivity` | `double` | `1.0` | Cursor speed multiplier (0.5x to 2.5x). |
| `swipeVelocityThreshold` | `double` | `0.45` | Normalized velocity needed to register air swipe. |
| `enableAirCursor` | `bool` | `true` | Whether the floating reticle is visible on screen. |
| `enableAirSwipes` | `bool` | `true` | Whether swipeUp/Down/Left/Right are recognized. |
| `enableHeadGestures` | `bool` | `true` | Whether head nod/shake oscillations are recognized. |
| `enableHapticFeedback` | `bool` | `true` | Whether tactile haptics fire upon gesture trigger. |
| `cursorStyle` | `TouchlessCursorStyle` | `sciFi` | Visual colors, size, glow, and particle styles. |

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Developed with ❤️ by **Usman Ahmad** ([@usmanahmad007](https://github.com/usmanahmad007)).
