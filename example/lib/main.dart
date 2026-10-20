import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_touchless/flutter_touchless.dart';

List<CameraDescription> _availableCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _availableCameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera initialization error: $e');
  }

  // Force immersive orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const TouchlessShowcaseApp());
}

class TouchlessShowcaseApp extends StatelessWidget {
  const TouchlessShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Touchless Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF161B22),
        ),
        useMaterial3: true,
      ),
      home: const TouchlessHomeScreen(),
    );
  }
}

class TouchlessHomeScreen extends StatefulWidget {
  const TouchlessHomeScreen({super.key});

  @override
  State<TouchlessHomeScreen> createState() => _TouchlessHomeScreenState();
}

class _TouchlessHomeScreenState extends State<TouchlessHomeScreen> {
  late TouchlessController _touchlessController;
  late MockTouchlessDetector _mockDetector;
  OpticalFlowDetector? _opticalFlowDetector;
  CameraController? _cameraController;

  bool _isCameraActive = false;
  bool _isCameraInitializing = false;
  int _selectedTabIndex = 0;
  String _detectorLabel = '🕹️ Simulator Mode';

  // Simulation drag state
  Offset _simulatedNormalized = const Offset(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    _mockDetector = MockTouchlessDetector();
    _mockDetector.start();

    _touchlessController = TouchlessController(
      detector: _mockDetector,
      config: const TouchlessConfig(
        dwellDuration: Duration(milliseconds: 650),
        motionSensitivity: 1.0,
        enableAirCursor: true,
        enableAirSwipes: true,
        enableHapticFeedback: true,
        cursorStyle: TouchlessCursorStyle(
          primaryColor: Color(0xFF00E5FF),
          activeColor: Color(0xFFFF4081),
          size: 42.0,
        ),
      ),
    );

    // If a front camera is available, attempt to initialize it gracefully
    _tryAutoInitCamera();
  }

  Future<void> _tryAutoInitCamera() async {
    if (_availableCameras.isEmpty) return;

    final frontCamera = _availableCameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _availableCameras.first,
    );

    await _initCameraWithDescription(frontCamera);
  }

  Future<void> _initCameraWithDescription(CameraDescription camera) async {
    setState(() => _isCameraInitializing = true);

    try {
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      final isFront = camera.lensDirection == CameraLensDirection.front;
      final flowDetector = OpticalFlowDetector(
        smoothingFactor: 0.35,
        swipeSensitivity: 0.22,
        sensorOrientation: camera.sensorOrientation,
        isFrontCamera: isFront,
        gain: 1.8,
      );
      await flowDetector.start();

      await controller.startImageStream((CameraImage image) {
        if (!_isCameraActive) return;
        if (image.planes.isNotEmpty) {
          final plane = image.planes[0];
          flowDetector.processFrame(
            plane.bytes,
            image.width,
            image.height,
            bytesPerRow: plane.bytesPerRow,
            step: 4,
          );
        }
      });

      await _touchlessController.setDetector(flowDetector);

      setState(() {
        _cameraController = controller;
        _opticalFlowDetector = flowDetector;
        _isCameraActive = true;
        _isCameraInitializing = false;
        _detectorLabel = '📷 Front Camera Optical Flow';
      });
    } catch (e) {
      debugPrint('Camera activation failed, falling back to simulator: $e');
      setState(() {
        _isCameraActive = false;
        _isCameraInitializing = false;
        _detectorLabel = '🕹️ Simulator Mode';
      });
    }
  }

  Future<void> _toggleDetector() async {
    if (_isCameraActive) {
      // Switch back to Mock detector
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      _cameraController = null;
      _opticalFlowDetector?.dispose();
      _opticalFlowDetector = null;

      _mockDetector = MockTouchlessDetector();
      await _mockDetector.start();
      await _touchlessController.setDetector(_mockDetector);

      setState(() {
        _isCameraActive = false;
        _detectorLabel = '🕹️ Simulator Mode';
      });
    } else {
      // Switch to Camera
      await _tryAutoInitCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _opticalFlowDetector?.dispose();
    _mockDetector.dispose();
    _touchlessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TouchlessScope(
      controller: _touchlessController,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Main Tab Content
              Positioned.fill(
                child: IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    _CookingModeTab(controller: _touchlessController),
                    _ReelsModeTab(controller: _touchlessController),
                    _ArcadeLabTab(controller: _touchlessController),
                    _SettingsTab(
                      controller: _touchlessController,
                      isCameraActive: _isCameraActive,
                      isCameraInitializing: _isCameraInitializing,
                      cameraController: _cameraController,
                      opticalFlowDetector: _opticalFlowDetector,
                      onToggleCamera: _toggleDetector,
                      simulatedPos: _simulatedNormalized,
                      onSimulateMove: (pos) {
                        setState(() => _simulatedNormalized = pos);
                        _mockDetector.simulatePoint(pos.dx, pos.dy);
                      },
                      onSimulateGesture: (type) {
                        _touchlessController.triggerGesture(type);
                      },
                    ),
                  ],
                ),
              ),

              // Floating Top Status HUD Bar
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: _opticalFlowDetector != null && _isCameraActive
                    ? ValueListenableBuilder<OpticalFlowTelemetry>(
                        valueListenable:
                            _opticalFlowDetector!.telemetryNotifier,
                        builder: (context, telemetry, _) {
                          final dirStr = telemetry.isTracking
                              ? ' • ${telemetry.direction}'
                              : '';
                          return TouchlessStatusBar(
                            controller: _touchlessController,
                            detectorLabel: '📷 Front Cam$dirStr',
                          );
                        },
                      )
                    : TouchlessStatusBar(
                        controller: _touchlessController,
                        detectorLabel: _detectorLabel,
                      ),
              ),

              // Floating Picture-In-Picture Camera Feed (When active)
              if (_isCameraActive &&
                  _cameraController != null &&
                  _cameraController!.value.isInitialized)
                Positioned(
                  top: 76,
                  right: 16,
                  child: Container(
                    width: 96,
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withAlpha(180),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withAlpha(60),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        ),
                        if (_opticalFlowDetector != null)
                          ValueListenableBuilder<OpticalFlowTelemetry>(
                            valueListenable:
                                _opticalFlowDetector!.telemetryNotifier,
                            builder: (context, telemetry, _) {
                              if (!telemetry.isTracking) {
                                return const SizedBox.shrink();
                              }
                              return Align(
                                alignment: Alignment(
                                  (telemetry.x * 2.0 - 1.0).clamp(-1.0, 1.0),
                                  (telemetry.y * 2.0 - 1.0).clamp(-1.0, 1.0),
                                ),
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF4081),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFFFF4081),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedTabIndex = index);
          },
          backgroundColor: const Color(0xFF161B22),
          indicatorColor: const Color(0xFF00E5FF).withAlpha(45),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu),
              selectedIcon:
                  Icon(Icons.restaurant_menu, color: Color(0xFF00E5FF)),
              label: 'Cooking',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_arrow),
              selectedIcon: Icon(Icons.play_arrow, color: Color(0xFF00E5FF)),
              label: 'Reels',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_esports),
              selectedIcon:
                  Icon(Icons.sports_esports, color: Color(0xFF00E5FF)),
              label: 'Arcade',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune),
              selectedIcon: Icon(Icons.tune, color: Color(0xFF00E5FF)),
              label: 'Engine',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: 🧑‍🍳 COOKING RECIPE MODE
// ==========================================
class _CookingModeTab extends StatefulWidget {
  final TouchlessController controller;
  const _CookingModeTab({required this.controller});

  @override
  State<_CookingModeTab> createState() => _CookingModeTabState();
}

class _CookingModeTabState extends State<_CookingModeTab> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Prep & Chop Ingredients',
      'instruction':
          'Mince 4 garlic cloves and finely chop fresh Italian parsley. Grate 1 cup of fresh aged Parmesan.',
      'icon': Icons.kitchen,
      'duration': '5 mins',
      'done': false,
    },
    {
      'title': 'Boil Pasta Al Dente',
      'instruction':
          'Bring 4 quarts of heavily salted water to a rolling boil. Cook penne pasta for 9 minutes until firm to the bite.',
      'icon': Icons.water_drop,
      'duration': '9 mins',
      'done': false,
    },
    {
      'title': 'Infuse Garlic Butter',
      'instruction':
          'Melt 3 tbsp unsalted butter in extra-virgin olive oil on medium heat. Sauté garlic until golden & fragrant (do not burn).',
      'icon': Icons.local_fire_department,
      'duration': '3 mins',
      'done': false,
    },
    {
      'title': 'Emulsify Sauce',
      'instruction':
          'Transfer drained pasta directly into the garlic butter pan. Pour in 1/4 cup reserved pasta water and toss vigorously.',
      'icon': Icons.soup_kitchen,
      'duration': '2 mins',
      'done': false,
    },
    {
      'title': 'Garnish & Feast',
      'instruction':
          'Turn off heat. Fold in Parmesan cheese and parsley. Season with cracked black pepper and chili flakes.',
      'icon': Icons.dinner_dining,
      'duration': 'Ready!',
      'done': false,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TouchlessScrollable(
      pageController: _pageController,
      child: Padding(
        padding: const EdgeInsets.only(top: 64, left: 16, right: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🧑‍🍳 Hands-Free Chef',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wave hand Left / Right to flip pages without touching screen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withAlpha(120),
                    ),
                  ),
                  child: Text(
                    'Step ${_currentStep + 1} of ${_steps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Card(
                    color: const Color(0xFF161B22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.white.withAlpha(25),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            step['icon'] as IconData,
                            size: 52,
                            color: const Color(0xFF00E5FF),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step['instruction'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  step['duration'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Touchless Dwell Check Button
                          TouchlessTarget(
                            id: 'step_done_$index',
                            onTouchlessTap: () {
                              setState(() {
                                step['done'] = !(step['done'] as bool);
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: (step['done'] as bool)
                                    ? const Color(0xFF00E676).withAlpha(40)
                                    : const Color(0xFF00E5FF).withAlpha(30),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: (step['done'] as bool)
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFF00E5FF),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    (step['done'] as bool)
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: (step['done'] as bool)
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (step['done'] as bool)
                                        ? 'Step Completed! Hover to undo'
                                        : 'Hover / Dwell to Complete Step',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (step['done'] as bool)
                                          ? const Color(0xFF00E676)
                                          : const Color(0xFF00E5FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentStep == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentStep == i
                        ? const Color(0xFF00E5FF)
                        : Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 2: 🎬 REELS / SHORT-FORM FEED
// ==========================================
class _ReelsModeTab extends StatefulWidget {
  final TouchlessController controller;
  const _ReelsModeTab({required this.controller});

  @override
  State<_ReelsModeTab> createState() => _ReelsModeTabState();
}

class _ReelsModeTabState extends State<_ReelsModeTab> {
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _reels = [
    {
      'title': 'Liquid Metal UI Animation in Flutter 3.24 🚀',
      'author': '@creative_coder',
      'likes': 1420,
      'isLiked': false,
      'gradient': const [
        Color(0xFF0F2027),
        Color(0xFF203A43),
        Color(0xFF2C5364)
      ],
    },
    {
      'title': 'Touchless Air Swipes for Recipe Cooking Mode 🍝',
      'author': '@usman_ahmad',
      'likes': 3890,
      'isLiked': true,
      'gradient': const [Color(0xFF1F1C2C), Color(0xFF928DAB)],
    },
    {
      'title': 'Autonomous AI Agents on Mobile - Deep Dive 🧠',
      'author': '@ai_frontiers',
      'likes': 8210,
      'isLiked': false,
      'gradient': const [Color(0xFF141E30), Color(0xFF243B55)],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TouchlessScrollable(
      pageController: _pageController,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: _reels.length,
        itemBuilder: (context, index) {
          final reel = _reels[index];
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: reel['gradient'] as List<Color>,
              ),
            ),
            child: Stack(
              children: [
                // Bottom Reel Details
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reel['author'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reel['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Swipe Up for Next Reel 👆',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Action Sidebar
                Positioned(
                  bottom: 40,
                  right: 16,
                  child: Column(
                    children: [
                      TouchlessTarget(
                        id: 'like_reel_$index',
                        onTouchlessTap: () {
                          setState(() {
                            final isLiked = reel['isLiked'] as bool;
                            reel['isLiked'] = !isLiked;
                            reel['likes'] =
                                (reel['likes'] as int) + (isLiked ? -1 : 1);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(120),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (reel['isLiked'] as bool)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: (reel['isLiked'] as bool)
                                ? Colors.redAccent
                                : Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${reel['likes']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Comment Button
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '128',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TAB 3: 🎯 AIR CURSOR ARCADE & DWELL LAB
// ==========================================
class _ArcadeLabTab extends StatefulWidget {
  final TouchlessController controller;
  const _ArcadeLabTab({required this.controller});

  @override
  State<_ArcadeLabTab> createState() => _ArcadeLabTabState();
}

class _ArcadeLabTabState extends State<_ArcadeLabTab> {
  int _score = 0;
  int _streak = 0;
  Color _currentColor = const Color(0xFF00E5FF);

  final List<Color> _palette = [
    const Color(0xFF00E5FF),
    const Color(0xFF7C4DFF),
    const Color(0xFFFF4081),
    const Color(0xFF00E676),
    const Color(0xFFFFD600),
  ];
  int _colorIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72, left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 Dwell-Click Arcade',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Steer cursor over targets and hold stationary to dwell-click',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _currentColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _currentColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'SCORE: $_score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _currentColor,
                      ),
                    ),
                    Text(
                      'Streak: x$_streak',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Interactive Target Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildTargetCard(
                  id: 'arcade_score_10',
                  icon: Icons.add_circle_outline,
                  title: '+10 Score',
                  subtitle: 'Fast Dwell',
                  accentColor: const Color(0xFF00E5FF),
                  onActivated: () {
                    setState(() {
                      _score += 10;
                      _streak++;
                    });
                  },
                ),
                _buildTargetCard(
                  id: 'arcade_score_50',
                  icon: Icons.star_border,
                  title: '+50 Super',
                  subtitle: 'Bonus Charge',
                  accentColor: const Color(0xFFFFD600),
                  onActivated: () {
                    setState(() {
                      _score += 50;
                      _streak += 2;
                    });
                  },
                ),
                _buildTargetCard(
                  id: 'arcade_color_blast',
                  icon: Icons.palette_outlined,
                  title: 'Color Blast',
                  subtitle: 'Cycles Cursor Theme',
                  accentColor: const Color(0xFFFF4081),
                  onActivated: () {
                    setState(() {
                      _colorIndex = (_colorIndex + 1) % _palette.length;
                      _currentColor = _palette[_colorIndex];
                      widget.controller.config =
                          widget.controller.config.copyWith(
                        cursorStyle: TouchlessCursorStyle(
                          primaryColor: _currentColor,
                          activeColor: const Color(0xFFFF4081),
                          size: 42.0,
                        ),
                      );
                    });
                  },
                ),
                _buildTargetCard(
                  id: 'arcade_reset',
                  icon: Icons.refresh,
                  title: 'Reset Score',
                  subtitle: 'Clears streak',
                  accentColor: const Color(0xFFFF5252),
                  onActivated: () {
                    setState(() {
                      _score = 0;
                      _streak = 0;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onActivated,
  }) {
    return TouchlessTarget(
      id: id,
      hoverColor: accentColor,
      onTouchlessTap: onActivated,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withAlpha(20),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: accentColor),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 4: ⚙️ ENGINE SETTINGS & SIMULATOR
// ==========================================
class _SettingsTab extends StatefulWidget {
  final TouchlessController controller;
  final bool isCameraActive;
  final bool isCameraInitializing;
  final CameraController? cameraController;
  final OpticalFlowDetector? opticalFlowDetector;
  final VoidCallback onToggleCamera;
  final Offset simulatedPos;
  final ValueChanged<Offset> onSimulateMove;
  final ValueChanged<TouchlessGestureType> onSimulateGesture;

  const _SettingsTab({
    required this.controller,
    required this.isCameraActive,
    required this.isCameraInitializing,
    required this.cameraController,
    this.opticalFlowDetector,
    required this.onToggleCamera,
    required this.simulatedPos,
    required this.onSimulateMove,
    required this.onSimulateGesture,
  });

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late double _dwellMs;
  late double _sensitivity;
  late bool _enableSwipes;
  late bool _enableHaptics;

  @override
  void initState() {
    super.initState();
    _dwellMs = widget.controller.config.dwellDuration.inMilliseconds.toDouble();
    _sensitivity = widget.controller.config.motionSensitivity;
    _enableSwipes = widget.controller.config.enableAirSwipes;
    _enableHaptics = widget.controller.config.enableHapticFeedback;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 72, left: 16, right: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ Touchless Engine Control',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure live camera optical flow, dwell speeds, and manual test bench',
            style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(160)),
          ),
          const SizedBox(height: 20),

          // Camera vs Simulator Toggle Card
          Card(
            color: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.isCameraActive
                    ? const Color(0xFF00E5FF).withAlpha(120)
                    : Colors.white.withAlpha(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    widget.isCameraActive
                        ? Icons.camera_front
                        : Icons.videogame_asset,
                    size: 32,
                    color: widget.isCameraActive
                        ? const Color(0xFF00E5FF)
                        : Colors.amber,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCameraActive
                              ? 'Live Front Camera Active'
                              : 'Simulator Mode Active',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isCameraActive
                              ? 'Zero-dependency pure-Dart Optical Flow CV'
                              : 'Virtual touch pad & simulation test bench',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(160),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: widget.isCameraInitializing
                        ? null
                        : widget.onToggleCamera,
                    child: widget.isCameraInitializing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isCameraActive ? 'Switch' : 'Start Cam'),
                  ),
                ],
              ),
            ),
          ),

          // Live Motion Tracking & Calibration Section (When Camera is Active)
          if (widget.opticalFlowDetector != null) ...[
            const SizedBox(height: 20),
            const Text(
              '🧭 Motion Tracking & Sensor Calibration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Live optical flow telemetry, compass direction, and axis alignment',
              style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150)),
            ),
            const SizedBox(height: 12),

            // Live Direction Telemetry Card
            ValueListenableBuilder<OpticalFlowTelemetry>(
              valueListenable: widget.opticalFlowDetector!.telemetryNotifier,
              builder: (context, telemetry, _) {
                final isMoving = telemetry.isTracking;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMoving
                          ? const Color(0xFF00E5FF).withAlpha(140)
                          : Colors.white.withAlpha(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isMoving
                                      ? const Color(0xFF00E5FF)
                                      : Colors.white30,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Live Motion:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMoving
                                  ? const Color(0xFF00E5FF).withAlpha(35)
                                  : Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMoving
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              telemetry.direction,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isMoving
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Centroid: (${(telemetry.x * 100).toInt()}%, ${(telemetry.y * 100).toInt()}%)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (telemetry.magnitude * 2.5)
                                        .clamp(0.0, 1.0),
                                    backgroundColor: Colors.white10,
                                    color: const Color(0xFF00E5FF),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sensor: ${widget.opticalFlowDetector!.sensorOrientation}° • ${widget.opticalFlowDetector!.isFrontCamera ? "Front Camera" : "Back Camera"}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withAlpha(110),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Quick Hardware Presets
            const Text(
              'Hardware Presets',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('📱 Pixel Front (270°)'),
                  selected: widget.opticalFlowDetector!.swapAxes &&
                      widget.opticalFlowDetector!.invertX &&
                      widget.opticalFlowDetector!.invertY,
                  onSelected: (_) {
                    setState(() {
                      widget.opticalFlowDetector!.configureOrientation(
                        swapAxes: true,
                        invertX: true,
                        invertY: true,
                      );
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('📸 Back Cam (90°)'),
                  selected: widget.opticalFlowDetector!.swapAxes &&
                      !widget.opticalFlowDetector!.invertX &&
                      !widget.opticalFlowDetector!.invertY,
                  onSelected: (_) {
                    setState(() {
                      widget.opticalFlowDetector!.configureOrientation(
                        swapAxes: true,
                        invertX: false,
                        invertY: false,
                      );
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('💻 Desktop/Webcam (0°)'),
                  selected: !widget.opticalFlowDetector!.swapAxes &&
                      widget.opticalFlowDetector!.invertX &&
                      !widget.opticalFlowDetector!.invertY,
                  onSelected: (_) {
                    setState(() {
                      widget.opticalFlowDetector!.configureOrientation(
                        swapAxes: false,
                        invertX: true,
                        invertY: false,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Axis Calibration Switches
            SwitchListTile(
              title: const Text('Swap X / Y Axes',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Maps landscape camera buffer to portrait screen (fixes diagonal/transposed drift)',
                style: TextStyle(fontSize: 11),
              ),
              value: widget.opticalFlowDetector!.swapAxes,
              activeColor: const Color(0xFF00E5FF),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  widget.opticalFlowDetector!.swapAxes = val;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Invert Horizontal (Mirror X)',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Inverts left/right tracking to match mirror selfie motion',
                style: TextStyle(fontSize: 11),
              ),
              value: widget.opticalFlowDetector!.invertX,
              activeColor: const Color(0xFF00E5FF),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  widget.opticalFlowDetector!.invertX = val;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Invert Vertical (Invert Y)',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Inverts up/down tracking direction',
                style: TextStyle(fontSize: 11),
              ),
              value: widget.opticalFlowDetector!.invertY,
              activeColor: const Color(0xFF00E5FF),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  widget.opticalFlowDetector!.invertY = val;
                });
              },
            ),
            const SizedBox(height: 14),

            // Reach Gain Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reach Gain Multiplier',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.opticalFlowDetector!.gain.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: widget.opticalFlowDetector!.gain,
              min: 1.0,
              max: 3.0,
              divisions: 20,
              activeColor: const Color(0xFF00E5FF),
              label: '${widget.opticalFlowDetector!.gain.toStringAsFixed(1)}x',
              onChanged: (val) {
                setState(() {
                  widget.opticalFlowDetector!.gain = val;
                });
              },
            ),
            Text(
              'Higher gain lets subtle hand movements reach screen edges comfortably',
              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(140)),
            ),
            const SizedBox(height: 16),

            // Noise Gate Threshold Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Noise Gate Threshold',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.opticalFlowDetector!.threshold}',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: widget.opticalFlowDetector!.threshold.toDouble(),
              min: 10,
              max: 35,
              divisions: 25,
              activeColor: const Color(0xFF00E5FF),
              label: '${widget.opticalFlowDetector!.threshold}',
              onChanged: (val) {
                setState(() {
                  widget.opticalFlowDetector!.threshold = val.round();
                });
              },
            ),
            Text(
              'Higher threshold rejects background shadows and ambient noise',
              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(140)),
            ),
          ],
          const SizedBox(height: 20),

          // Dwell Duration Slider
          const Text(
            'Dwell Activation Duration',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _dwellMs,
            min: 300,
            max: 1200,
            divisions: 9,
            activeColor: const Color(0xFF00E5FF),
            label: '${_dwellMs.round()} ms',
            onChanged: (val) {
              setState(() => _dwellMs = val);
              widget.controller.config = widget.controller.config.copyWith(
                dwellDuration: Duration(milliseconds: val.round()),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fast (300ms)',
                  style: TextStyle(
                      color: Colors.white.withAlpha(140), fontSize: 11)),
              Text('${_dwellMs.round()} ms',
                  style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              Text('Slow (1200ms)',
                  style: TextStyle(
                      color: Colors.white.withAlpha(140), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),

          // Sensitivity Slider
          const Text(
            'Motion Sensitivity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _sensitivity,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            activeColor: const Color(0xFF00E5FF),
            label: '${_sensitivity.toStringAsFixed(1)}x',
            onChanged: (val) {
              setState(() => _sensitivity = val);
              widget.controller.config = widget.controller.config.copyWith(
                motionSensitivity: val,
              );
            },
          ),
          const SizedBox(height: 12),

          // Feature Toggles
          SwitchListTile(
            title: const Text('Air Swipes & Waves',
                style: TextStyle(fontSize: 14)),
            subtitle: const Text('Enable hands-free scrolling gestures',
                style: TextStyle(fontSize: 12)),
            value: _enableSwipes,
            activeColor: const Color(0xFF00E5FF),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _enableSwipes = val);
              widget.controller.config = widget.controller.config.copyWith(
                enableAirSwipes: val,
              );
            },
          ),
          SwitchListTile(
            title:
                const Text('Haptic Feedback', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Tactile buzz on gesture recognition',
                style: TextStyle(fontSize: 12)),
            value: _enableHaptics,
            activeColor: const Color(0xFF00E5FF),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _enableHaptics = val);
              widget.controller.config = widget.controller.config.copyWith(
                enableHapticFeedback: val,
              );
            },
          ),
          const SizedBox(height: 20),

          // Quick Gesture Simulation Bench
          const Text(
            '🕹️ Manual Gesture Test Bench',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('👆 Swipe Up'),
                onPressed: () =>
                    widget.onSimulateGesture(TouchlessGestureType.swipeUp),
              ),
              ActionChip(
                label: const Text('👇 Swipe Down'),
                onPressed: () =>
                    widget.onSimulateGesture(TouchlessGestureType.swipeDown),
              ),
              ActionChip(
                label: const Text('👈 Swipe Left'),
                onPressed: () =>
                    widget.onSimulateGesture(TouchlessGestureType.swipeLeft),
              ),
              ActionChip(
                label: const Text('👉 Swipe Right'),
                onPressed: () =>
                    widget.onSimulateGesture(TouchlessGestureType.swipeRight),
              ),
              ActionChip(
                label: const Text('🌊 Proximity Wave'),
                onPressed: () => widget
                    .onSimulateGesture(TouchlessGestureType.proximityWave),
              ),
              ActionChip(
                label: const Text('🙆 Head Nod'),
                onPressed: () =>
                    widget.onSimulateGesture(TouchlessGestureType.headNod),
              ),
              ActionChip(
                label: const Text('🙅 Head Shake'),
                onPressed: () =>
                    widget.onSimulateGesture(TouchlessGestureType.headShake),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Virtual Touchpad Steering (When using Simulator)
          const Text(
            '🖱️ Air Cursor Drag Pad',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Drag finger inside box to steer the floating air cursor anywhere on screen',
            style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onPanUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final newX = (widget.simulatedPos.dx + details.delta.dx / 200.0)
                  .clamp(0.05, 0.95);
              final newY = (widget.simulatedPos.dy + details.delta.dy / 200.0)
                  .clamp(0.05, 0.95);
              widget.onSimulateMove(Offset(newX, newY));
            },
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.touch_app,
                      size: 36,
                      color: Color(0xFF00E5FF),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cursor: (${widget.simulatedPos.dx.toStringAsFixed(2)}, ${widget.simulatedPos.dy.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
