import 'dart:async';
import 'dart:math' as math;
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
    debugPrint('Camera discovery notice: $e');
  }

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
      title: 'Touchless Media Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF4081),
          surface: Color(0xFF141824),
        ),
        useMaterial3: true,
      ),
      home: const TouchlessMediaPlayerScreen(),
    );
  }
}

/// Track model for the audio playlist
class MediaTrack {
  final String title;
  final String artist;
  final String album;
  final String genre;
  final Duration duration;
  final List<Color> gradient;
  final IconData icon;

  const MediaTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.duration,
    required this.gradient,
    required this.icon,
  });
}

class TouchlessMediaPlayerScreen extends StatefulWidget {
  const TouchlessMediaPlayerScreen({super.key});

  @override
  State<TouchlessMediaPlayerScreen> createState() =>
      _TouchlessMediaPlayerScreenState();
}

class _TouchlessMediaPlayerScreenState extends State<TouchlessMediaPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TouchlessController _touchlessController;
  late MockTouchlessDetector _mockDetector;
  OpticalFlowDetector? _opticalFlowDetector;
  CameraController? _cameraController;

  bool _isCameraActive = false;
  bool _showPipCamera = true;
  String _detectorLabel = '🕹️ Simulator Mode';

  // Playlist
  final List<MediaTrack> _playlist = const [
    MediaTrack(
      title: 'Midnight City',
      artist: 'M83',
      album: "Hurry Up, We're Dreaming",
      genre: 'SYNTHWAVE',
      duration: Duration(minutes: 4, seconds: 3),
      gradient: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
      icon: Icons.nightlife,
    ),
    MediaTrack(
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      genre: 'SYNTHPOP',
      duration: Duration(minutes: 3, seconds: 20),
      gradient: [Color(0xFFFF5252), Color(0xFFFF4081)],
      icon: Icons.electric_bolt,
    ),
    MediaTrack(
      title: 'Starboy',
      artist: 'Daft Punk ft. The Weeknd',
      album: 'Starboy',
      genre: 'CYBER R&B',
      duration: Duration(minutes: 3, seconds: 50),
      gradient: [Color(0xFFFFD600), Color(0xFFFF6D00)],
      icon: Icons.auto_awesome,
    ),
    MediaTrack(
      title: 'Resonance',
      artist: 'HOME',
      album: 'Odyssey',
      genre: 'CHILLWAVE',
      duration: Duration(minutes: 3, seconds: 32),
      gradient: [Color(0xFF00E676), Color(0xFF00B0FF)],
      icon: Icons.waves,
    ),
    MediaTrack(
      title: 'After Dark',
      artist: 'Mr.Kitty',
      album: 'Time',
      genre: 'DARKWAVE',
      duration: Duration(minutes: 4, seconds: 17),
      gradient: [Color(0xFF7C4DFF), Color(0xFF311B92)],
      icon: Icons.dark_mode,
    ),
  ];

  int _currentTrackIndex = 0;
  bool _isPlaying = true;
  double _volume = 0.70;
  Duration _currentPosition = const Duration(minutes: 1, seconds: 15);
  Timer? _playbackTicker;
  bool _isShuffle = false;
  bool _isRepeat = false;

  // Visualizer Animation
  late AnimationController _visualizerAnim;

  // Active Gesture HUD feedback overlay
  String? _hudGestureTitle;
  String? _hudGestureSubtitle;
  IconData? _hudGestureIcon;
  Color _hudGestureColor = const Color(0xFF00E5FF);
  Timer? _hudDismissTimer;

  // Stream subscription for touchless gestures
  StreamSubscription<TouchlessGestureEvent>? _gestureSub;

  @override
  void initState() {
    super.initState();

    _visualizerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

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

    // Listen to touchless gestures
    _gestureSub = _touchlessController.gestureStream.listen(_handleTouchlessGesture);

    // Start playback timer
    _startPlaybackTicker();

    // Auto-start front camera if available
    _tryAutoInitCamera();
  }

  void _startPlaybackTicker() {
    _playbackTicker?.cancel();
    _playbackTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && mounted) {
        setState(() {
          final maxDur = _playlist[_currentTrackIndex].duration;
          if (_currentPosition < maxDur) {
            _currentPosition += const Duration(seconds: 1);
          } else {
            _nextTrack(fromAutoEnd: true);
          }
        });
      }
    });
  }

  void _handleTouchlessGesture(TouchlessGestureEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case TouchlessGestureType.swipeRight:
        _nextTrack();
        break;
      case TouchlessGestureType.swipeLeft:
        _prevTrack();
        break;
      case TouchlessGestureType.swipeUp:
        _adjustVolume(0.10);
        break;
      case TouchlessGestureType.swipeDown:
        _adjustVolume(-0.10);
        break;
      case TouchlessGestureType.proximityWave:
      case TouchlessGestureType.headNod:
      case TouchlessGestureType.pinch:
      case TouchlessGestureType.dwellClick:
      case TouchlessGestureType.airTap:
        _togglePlayPause();
        break;
      case TouchlessGestureType.headShake:
        _nextTrack();
        break;
    }
  }

  void _showGestureHud({
    required String title,
    required String subtitle,
    required IconData icon,
    Color color = const Color(0xFF00E5FF),
  }) {
    setState(() {
      _hudGestureTitle = title;
      _hudGestureSubtitle = subtitle;
      _hudGestureIcon = icon;
      _hudGestureColor = color;
    });

    _hudDismissTimer?.cancel();
    _hudDismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _hudGestureTitle = null;
        });
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    _showGestureHud(
      title: _isPlaying ? 'PLAYING' : 'PAUSED',
      subtitle: _playlist[_currentTrackIndex].title,
      icon: _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
      color: _isPlaying ? const Color(0xFF00E5FF) : const Color(0xFFFF4081),
    );
  }

  void _nextTrack({bool fromAutoEnd = false}) {
    setState(() {
      if (_isShuffle) {
        _currentTrackIndex = math.Random().nextInt(_playlist.length);
      } else {
        _currentTrackIndex = (_currentTrackIndex + 1) % _playlist.length;
      }
      _currentPosition = Duration.zero;
      _isPlaying = true;
    });

    _showGestureHud(
      title: 'NEXT TRACK ⏭️',
      subtitle: '${_playlist[_currentTrackIndex].title} • ${_playlist[_currentTrackIndex].artist}',
      icon: Icons.skip_next_rounded,
      color: const Color(0xFF00E5FF),
    );
  }

  void _prevTrack() {
    setState(() {
      if (_currentPosition.inSeconds > 4) {
        _currentPosition = Duration.zero;
      } else {
        _currentTrackIndex =
            (_currentTrackIndex - 1 + _playlist.length) % _playlist.length;
        _currentPosition = Duration.zero;
      }
      _isPlaying = true;
    });

    _showGestureHud(
      title: 'PREVIOUS TRACK ⏮️',
      subtitle: '${_playlist[_currentTrackIndex].title} • ${_playlist[_currentTrackIndex].artist}',
      icon: Icons.skip_previous_rounded,
      color: const Color(0xFF7C4DFF),
    );
  }

  void _adjustVolume(double delta) {
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 1.0);
    });

    final pct = (_volume * 100).round();
    _showGestureHud(
      title: delta > 0 ? 'VOLUME UP 🔊' : 'VOLUME DOWN 🔉',
      subtitle: '$pct%',
      icon: delta > 0 ? Icons.volume_up_rounded : Icons.volume_down_rounded,
      color: delta > 0 ? const Color(0xFF00E676) : const Color(0xFFFFB300),
    );
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
        _detectorLabel = '📷 Front Camera Active';
      });
    } catch (e) {
      debugPrint('Camera activation error, using simulator: $e');
      setState(() {
        _isCameraActive = false;
        _detectorLabel = '🕹️ Simulator Mode';
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_isCameraActive) {
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
      await _tryAutoInitCamera();
    }
  }

  @override
  void dispose() {
    _gestureSub?.cancel();
    _playbackTicker?.cancel();
    _hudDismissTimer?.cancel();
    _visualizerAnim.dispose();
    _cameraController?.dispose();
    _opticalFlowDetector?.dispose();
    _mockDetector.dispose();
    _touchlessController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _playlist[_currentTrackIndex];

    return TouchlessScope(
      controller: _touchlessController,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                currentTrack.gradient[0].withAlpha(45),
                const Color(0xFF090B10),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Main Media Player Body
                Column(
                  children: [
                    const SizedBox(height: 52), // Space for top status bar

                    // Header: Playlist and Calibration Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.queue_music, color: Colors.white70),
                            onPressed: _openPlaylistDrawer,
                            tooltip: 'Playlist',
                          ),
                          Column(
                            children: [
                              Text(
                                'TOUCHLESS AUDIO PLAYER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: currentTrack.gradient[0],
                                ),
                              ),
                              Text(
                                currentTrack.genre,
                                style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune, color: Colors.white70),
                            onPressed: _openEngineCalibrationModal,
                            tooltip: 'Sensor Calibration',
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Album Artwork Card with Touchless Dwell-Click Target
                    Center(
                      child: TouchlessTarget(
                        id: 'album_artwork_play_toggle',
                        onTouchlessTap: _togglePlayPause,
                        onTap: _togglePlayPause,
                        child: _buildAlbumArtworkCard(currentTrack),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Song Title & Artist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            currentTrack.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${currentTrack.artist} — ${currentTrack.album}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Animated Real-Time Audio Rhythm Visualizer
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _visualizerAnim,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _AudioVisualizerPainter(
                              isPlaying: _isPlaying,
                              animValue: _visualizerAnim.value,
                              primaryColor: currentTrack.gradient[0],
                              secondaryColor: currentTrack.gradient[1],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Seek Progress Bar & Time
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: currentTrack.gradient[0],
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _currentPosition.inSeconds
                                  .toDouble()
                                  .clamp(0.0, currentTrack.duration.inSeconds.toDouble()),
                              min: 0,
                              max: currentTrack.duration.inSeconds.toDouble(),
                              onChanged: (val) {
                                setState(() {
                                  _currentPosition = Duration(seconds: val.round());
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_currentPosition),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                                Text(
                                  _formatDuration(currentTrack.duration),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Primary Playback Controls with Touchless Air Targets
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle Button
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: _isShuffle
                                  ? currentTrack.gradient[0]
                                  : Colors.white38,
                            ),
                            onPressed: () {
                              setState(() => _isShuffle = !_isShuffle);
                              _showGestureHud(
                                title: _isShuffle ? 'SHUFFLE ON' : 'SHUFFLE OFF',
                                subtitle: 'Playlist randomizer',
                                icon: Icons.shuffle,
                                color: currentTrack.gradient[0],
                              );
                            },
                          ),

                          // Previous Track Air Target
                          TouchlessTarget(
                            id: 'btn_prev_track',
                            onTouchlessTap: _prevTrack,
                            onTap: _prevTrack,
                            child: _buildControlBubble(
                              icon: Icons.skip_previous_rounded,
                              size: 28,
                              onTap: _prevTrack,
                            ),
                          ),

                          // Giant Central Play/Pause Air Target
                          TouchlessTarget(
                            id: 'btn_play_pause_center',
                            onTouchlessTap: _togglePlayPause,
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: currentTrack.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentTrack.gradient[0].withAlpha(120),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _togglePlayPause,
                                  child: Center(
                                    child: Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 42,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Next Track Air Target
                          TouchlessTarget(
                            id: 'btn_next_track',
                            onTouchlessTap: _nextTrack,
                            onTap: _nextTrack,
                            child: _buildControlBubble(
                              icon: Icons.skip_next_rounded,
                              size: 28,
                              onTap: _nextTrack,
                            ),
                          ),

                          // Repeat Button
                          IconButton(
                            icon: Icon(
                              Icons.repeat,
                              color: _isRepeat
                                  ? currentTrack.gradient[0]
                                  : Colors.white38,
                            ),
                            onPressed: () {
                              setState(() => _isRepeat = !_isRepeat);
                              _showGestureHud(
                                title: _isRepeat ? 'REPEAT ON' : 'REPEAT OFF',
                                subtitle: 'Single track repeat',
                                icon: Icons.repeat,
                                color: currentTrack.gradient[0],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Gesture Quick-Guide Banner
                    _buildGestureGuideBanner(),

                    const SizedBox(height: 12),
                  ],
                ),

                // Top Status Bar HUD
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

                // Floating Picture-In-Picture Camera Feed
                if (_isCameraActive &&
                    _showPipCamera &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized)
                  Positioned(
                    top: 60,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showPipCamera = !_showPipCamera);
                      },
                      child: Container(
                        width: 90,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: currentTrack.gradient[0].withAlpha(180),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: currentTrack.gradient[0].withAlpha(70),
                              blurRadius: 12,
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
                  ),

                // Giant Holographic Gesture Pop-up HUD
                if (_hudGestureTitle != null)
                  Center(
                    child: _buildHolographicGestureHud(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArtworkCard(MediaTrack track) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: track.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: track.gradient[0].withAlpha(_isPlaying ? 140 : 60),
            blurRadius: _isPlaying ? 40 : 20,
            spreadRadius: _isPlaying ? 4 : 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner vinyl grooves aesthetic
          Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(30), width: 1.5),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
              ),
            ),
          ),
          Center(
            child: Icon(
              track.icon,
              size: 80,
              color: Colors.white.withAlpha(230),
            ),
          ),
          // Pulsing Play Badge
          Positioned(
            bottom: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPlaying ? Icons.graphic_eq : Icons.pause,
                    size: 14,
                    color: track.gradient[0],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isPlaying ? 'PLAYING' : 'PAUSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: track.gradient[0],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBubble({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: size, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGestureGuideBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141824).withAlpha(190),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _GestureGuideItem(gesture: '👈 Left', action: 'Prev'),
          _GestureGuideItem(gesture: '👉 Right', action: 'Next'),
          _GestureGuideItem(gesture: '👆 Up', action: 'Vol +'),
          _GestureGuideItem(gesture: '👇 Down', action: 'Vol -'),
          _GestureGuideItem(gesture: '🖐️ Push', action: 'Play/Pause'),
        ],
      ),
    );
  }

  Widget _buildHolographicGestureHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xEE0B0E17),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _hudGestureColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _hudGestureColor.withAlpha(120),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_hudGestureIcon, size: 48, color: _hudGestureColor),
          const SizedBox(height: 10),
          Text(
            _hudGestureTitle ?? '',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: _hudGestureColor,
            ),
          ),
          if (_hudGestureSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              _hudGestureSubtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPlaylistDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141824),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎼 Playlist Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_playlist.length, (index) {
                final track = _playlist[index];
                final isCurrent = index == _currentTrackIndex;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: track.gradient),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(track.icon, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    track.title,
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFF00E5FF) : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    track.artist,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Text(
                    _formatDuration(track.duration),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  onTap: () {
                    setState(() {
                      _currentTrackIndex = index;
                      _currentPosition = Duration.zero;
                      _isPlaying = true;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openEngineCalibrationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141824),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final detector = _opticalFlowDetector;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '⚙️ Camera & Gesture Lab',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () async {
                            await _toggleCamera();
                            setModalState(() {});
                          },
                          child: Text(_isCameraActive ? 'Use Sim' : 'Use Cam'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (detector != null) ...[
                      // Sensor presets
                      const Text('Hardware Preset:',
                          style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('📱 Pixel Front (270°)'),
                            selected: detector.swapAxes &&
                                detector.invertX &&
                                detector.invertY,
                            onSelected: (_) {
                              detector.configureOrientation(
                                swapAxes: true,
                                invertX: true,
                                invertY: true,
                              );
                              setModalState(() {});
                            },
                          ),
                          ChoiceChip(
                            label: const Text('💻 Webcam (0°)'),
                            selected: !detector.swapAxes &&
                                detector.invertX &&
                                !detector.invertY,
                            onSelected: (_) {
                              detector.configureOrientation(
                                swapAxes: false,
                                invertX: true,
                                invertY: false,
                              );
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Swap Axes (X ⇄ Y)'),
                        value: detector.swapAxes,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          detector.swapAxes = val;
                          setModalState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Invert Horizontal (Mirror X)'),
                        value: detector.invertX,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          detector.invertX = val;
                          setModalState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Invert Vertical (Invert Y)'),
                        value: detector.invertY,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          detector.invertY = val;
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 10),

                      // Reach Gain
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reach Gain Multiplier:'),
                          Text('${detector.gain.toStringAsFixed(1)}x',
                              style: const TextStyle(color: Color(0xFF00E5FF))),
                        ],
                      ),
                      Slider(
                        value: detector.gain,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          detector.gain = val;
                          setModalState(() {});
                        },
                      ),
                    ],

                    const Divider(color: Colors.white12),
                    const Text('🕹️ Manual Gesture Simulator:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('👉 Next Track'),
                          onPressed: () {
                            _touchlessController
                                .triggerGesture(TouchlessGestureType.swipeRight);
                          },
                        ),
                        ActionChip(
                          label: const Text('👈 Prev Track'),
                          onPressed: () {
                            _touchlessController
                                .triggerGesture(TouchlessGestureType.swipeLeft);
                          },
                        ),
                        ActionChip(
                          label: const Text('👆 Volume Up'),
                          onPressed: () {
                            _touchlessController
                                .triggerGesture(TouchlessGestureType.swipeUp);
                          },
                        ),
                        ActionChip(
                          label: const Text('👇 Volume Down'),
                          onPressed: () {
                            _touchlessController
                                .triggerGesture(TouchlessGestureType.swipeDown);
                          },
                        ),
                        ActionChip(
                          label: const Text('🖐️ Play / Pause'),
                          onPressed: () {
                            _touchlessController.triggerGesture(
                                TouchlessGestureType.proximityWave);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GestureGuideItem extends StatelessWidget {
  final String gesture;
  final String action;
  const _GestureGuideItem({required this.gesture, required this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gesture,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          action,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

/// Custom Canvas Painter rendering animated glowing sound waves
class _AudioVisualizerPainter extends CustomPainter {
  final bool isPlaying;
  final double animValue;
  final Color primaryColor;
  final Color secondaryColor;

  _AudioVisualizerPainter({
    required this.isPlaying,
    required this.animValue,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 36;
    final double barWidth = size.width / (barCount * 1.8);
    final double spacing = (size.width - (barCount * barWidth)) / (barCount - 1);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final double normalizedIndex = i / barCount;
      double barHeight;

      if (isPlaying) {
        final wave1 = math.sin((animValue * 2 * math.pi) + (i * 0.4));
        final wave2 = math.cos((animValue * 4 * math.pi) - (i * 0.2));
        final dynamicScale = (wave1 + wave2 + 2.0) / 4.0;
        final bellCurve = math.sin(normalizedIndex * math.pi);
        barHeight = (size.height * 0.85 * dynamicScale * bellCurve).clamp(4.0, size.height);
      } else {
        barHeight = 4.0;
      }

      final x = i * (barWidth + spacing);
      final y = (size.height - barHeight) / 2;

      paint.color = Color.lerp(primaryColor, secondaryColor, normalizedIndex)!
          .withAlpha(isPlaying ? 220 : 60);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioVisualizerPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.primaryColor != primaryColor;
  }
}
