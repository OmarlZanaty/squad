import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global player pool — max 3 concurrent players to avoid codec exhaustion
// ─────────────────────────────────────────────────────────────────────────────
class _VideoPlayerPool {
  static const int _maxActive = 3;
  static final _VideoPlayerPool instance = _VideoPlayerPool._();
  _VideoPlayerPool._();

  final List<String> _activeKeys = [];
  final Map<String, VoidCallback> _pauseCallbacks = {};

  void register(String key, VoidCallback onForcePause) {
    _pauseCallbacks[key] = onForcePause;
  }

  void unregister(String key) {
    _activeKeys.remove(key);
    _pauseCallbacks.remove(key);
  }

  void requestPlay(String key) {
    if (!_activeKeys.contains(key)) _activeKeys.add(key);
    while (_activeKeys.length > _maxActive) {
      final oldest = _activeKeys.removeAt(0);
      _pauseCallbacks[oldest]?.call();
    }
  }

  void notifyPaused(String key) => _activeKeys.remove(key);
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoPlayerWidget — inline adaptive-height card player
// ─────────────────────────────────────────────────────────────────────────────
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? lowQualityUrl;
  final String? mediumQualityUrl;
  final String? highQualityUrl;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.lowQualityUrl,
    this.mediumQualityUrl,
    this.highQualityUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  Player? _player;
  VideoController? _controller;

  bool _initialized = false;
  bool _hasError = false;
  bool _isVisible = false;
  bool _showControls = true;
  String _selectedQuality = 'Auto';
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  Timer? _controlsTimer;
  bool _disposed = false;

  // Video dimensions — discovered after media loads
  int _videoWidth = 0;
  int _videoHeight = 0;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;

  static const List<double> _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const double _maxCardHeight = 500; // cap for very tall portrait videos
  static const double _minCardHeight = 180; // floor for very wide landscape

  String get _poolKey => 'vid_${widget.videoUrl.hashCode}';

  Map<String, String> get _qualities {
    final map = <String, String>{};
    if ((widget.highQualityUrl ?? '').isNotEmpty) map['1080p'] = widget.highQualityUrl!;
    if ((widget.mediumQualityUrl ?? '').isNotEmpty) map['720p'] = widget.mediumQualityUrl!;
    if ((widget.lowQualityUrl ?? '').isNotEmpty) map['360p'] = widget.lowQualityUrl!;
    map['Auto'] = widget.videoUrl;
    return map;
  }

  @override
  bool get wantKeepAlive => true;

  // ── Adaptive card height based on actual video dimensions ──
  double _cardHeight(double screenWidth) {
    if (_videoWidth <= 0 || _videoHeight <= 0) {
      // Before dimensions are known: use 16:9 placeholder
      return screenWidth * (9 / 16);
    }
    final ratio = _videoHeight / _videoWidth;
    final natural = screenWidth * ratio;
    return natural.clamp(_minCardHeight, _maxCardHeight);
  }

  @override
  void initState() {
    super.initState();
    _VideoPlayerPool.instance.register(_poolKey, _forcePause);
    _createPlayer();
  }

  void _createPlayer() {
    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 16 * 1024 * 1024),
    );
    _controller = VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true),
    );

    // Subscribe to dimension streams so card resizes when metadata loads
    _widthSub = _player!.stream.width.listen((w) {
      if (w != null && w > 0 && mounted && !_disposed) {
        setState(() => _videoWidth = w);
      }
    });
    _heightSub = _player!.stream.height.listen((h) {
      if (h != null && h > 0 && mounted && !_disposed) {
        setState(() => _videoHeight = h);
      }
    });

    _initVideo();
  }

  Future<void> _initVideo() async {
    if (_disposed || _player == null) return;
    try {
      await _player!.open(Media(widget.videoUrl), play: false);
      await _player!.setVolume(_volume * 100);
      if (mounted && !_disposed) {
        setState(() { _initialized = true; _hasError = false; });
        if (_isVisible) _requestPlay();
      }
    } catch (e) {
      debugPrint('VideoPlayer init error: $e');
      if (mounted && !_disposed) setState(() => _hasError = true);
    }
  }

  void _requestPlay() {
    if (_disposed || _player == null) return; // Safety check
    _VideoPlayerPool.instance.requestPlay(_poolKey);
    _player?.play();
    _startControlsTimer();
  }

  void _forcePause() {
    if (_disposed || _player == null) return; // Safety check
    _player?.pause();
    _VideoPlayerPool.instance.notifyPaused(_poolKey);
    if (mounted) setState(() => _showControls = true);
  }

  Future<void> _switchQuality(String label) async {
    final url = _qualities[label];
    if (url == null || _player == null) return;
    final pos = _player!.state.position;
    final wasPlaying = _player!.state.playing;
    try {
      await _player!.open(Media(url), play: false);
      await _player!.setVolume(_volume * 100);
      await _player!.seek(pos);
      if (wasPlaying) _player!.play();
      if (mounted) setState(() => _selectedQuality = label);
    } catch (e) { debugPrint('Quality switch error: $e'); }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_player?.state.playing ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _showControls = !_showControls);
    if (_showControls && (_player?.state.playing ?? false)) _startControlsTimer();
  }

  void _togglePlay() {
    if (_player == null) return;
    if (_player!.state.playing) {
      _player!.pause();
      _VideoPlayerPool.instance.notifyPaused(_poolKey);
      _controlsTimer?.cancel();
      if (mounted) setState(() => _showControls = true);
    } else {
      _requestPlay();
      if (mounted) setState(() {});
    }
  }

  void _setVolume(double v) {
    _volume = v; _isMuted = v == 0;
    _player?.setVolume(v * 100);
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    if (_isMuted) { _setVolume(_volume == 0 ? 1.0 : _volume); }
    else { _player?.setVolume(0); if (mounted) setState(() => _isMuted = true); }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _disposed = true;
    _controlsTimer?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _VideoPlayerPool.instance.unregister(_poolKey);
    _player?.pause();
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = _cardHeight(screenWidth);

    return VisibilityDetector(
      key: Key(_poolKey),
      onVisibilityChanged: (info) {
        final nowVisible = info.visibleFraction > 0.5;
        if (nowVisible == _isVisible) return;
        _isVisible = nowVisible;
        if (!_initialized) return;
        if (_isVisible) {
          _requestPlay();
        } else {
          _controlsTimer?.cancel();
          _player?.pause();
          _player?.seek(Duration.zero);
          _VideoPlayerPool.instance.notifyPaused(_poolKey);
          if (mounted) setState(() => _showControls = true);
        }
      },
      child: GestureDetector(
        onTap: _toggleControls,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: screenWidth,
          height: cardHeight,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail before init
              if (!_initialized && (widget.thumbnailUrl ?? '').isNotEmpty)
                Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.contain, // contain so portrait thumbnails don't crop
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),

              // Video — BoxFit.contain fills the adaptive container correctly
              if (_initialized && _controller != null)
                Video(
                  controller: _controller!,
                  fit: BoxFit.contain,
                  controls: NoVideoControls,
                ),

              // Loading spinner
              if (!_initialized && !_hasError)
                const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),

              // Error state
              if (_hasError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white54, size: 36),
                      const SizedBox(height: 8),
                      const Text('تعذر تشغيل الفيديو',
                          style:
                          TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _initialized = false;
                          });
                          _player?.dispose();
                          _createPlayer();
                        },
                        child: const Text('إعادة المحاولة',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

              // Controls overlay
              if (_initialized && !_hasError && _showControls && _player != null)
                ..._buildControls(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildControls(BuildContext context) => [
    // Bottom gradient
    Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 100,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
      ),
    ),

    // Center play/pause
    Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle),
          child: StreamBuilder<bool>(
            stream: _player!.stream.playing,
            initialData: false,
            builder: (_, snap) => Icon(
              (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 36,
            ),
          ),
        ),
      ),
    ),

    // Bottom bar
    Positioned(
      bottom: 0, left: 8, right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress slider
          StreamBuilder<Duration>(
            stream: _player!.stream.position,
            initialData: Duration.zero,
            builder: (_, posSnap) => StreamBuilder<Duration>(
              stream: _player!.stream.duration,
              initialData: Duration.zero,
              builder: (_, durSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = durSnap.data ?? Duration.zero;
                final maxMs =
                dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: pos.inMilliseconds.toDouble().clamp(0.0, maxMs),
                    max: maxMs,
                    activeColor: const Color(0xFF26A69A),
                    inactiveColor: const Color(0xFF26A69A).withOpacity(0.3),
                    onChanged: (v) {
                      _player!
                          .seek(Duration(milliseconds: v.toInt()));
                      _startControlsTimer();
                    },
                  ),
                );
              },
            ),
          ),

          // Controls row
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
            child: Row(
              children: [
                // Time
                StreamBuilder<Duration>(
                  stream: _player!.stream.position,
                  initialData: Duration.zero,
                  builder: (_, posSnap) => StreamBuilder<Duration>(
                    stream: _player!.stream.duration,
                    initialData: Duration.zero,
                    builder: (_, durSnap) => Text(
                      '${_fmt(posSnap.data ?? Duration.zero)} / ${_fmt(durSnap.data ?? Duration.zero)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Volume
                GestureDetector(
                  onTap: () {
                    _controlsTimer?.cancel();
                    _toggleMute();
                    _startControlsTimer();
                  },
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white, size: 18,
                  ),
                ),
                SizedBox(
                  width: 55,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 8),
                    ),
                    child: Slider(
                      value: _isMuted ? 0 : _volume,
                      min: 0, max: 1,
                      activeColor: const Color(0xFF26A69A),
                      inactiveColor: const Color(0xFF26A69A).withOpacity(0.3),
                      onChanged: (v) {
                        _setVolume(v);
                        _startControlsTimer();
                      },
                    ),
                  ),
                ),
                const Spacer(),
                _ControlChip(
                  label: _playbackSpeed == 1.0
                      ? '1x'
                      : '${_playbackSpeed}x',
                  onTap: () {
                    _controlsTimer?.cancel();
                    _showSpeedSheet();
                  },
                ),
                const SizedBox(width: 6),
                _ControlChip(
                  label: _selectedQuality,
                  onTap: () {
                    _controlsTimer?.cancel();
                    _showQualitySheet();
                  },
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _openFullscreen,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.fullscreen,
                        color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ];

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SpeedSheet(
        speeds: _speeds,
        current: _playbackSpeed,
        onSelect: (s) {
          Navigator.pop(context);
          _player?.setRate(s);
          if (mounted) setState(() => _playbackSpeed = s);
          _startControlsTimer();
        },
      ),
    ).then((_) => _startControlsTimer());
  }

  void _showQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _QualitySheet(
        qualities: _qualities,
        current: _selectedQuality,
        onSelect: (label) {
          Navigator.pop(context);
          _switchQuality(label);
        },
      ),
    ).then((_) => _startControlsTimer());
  }

  void _openFullscreen() {
    if (_player == null) return;
    _controlsTimer?.cancel();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenPage(
          player: _player!,
          controller: _controller!,
          initialPosition: _player!.state.position,
          shouldPlay: _player!.state.playing,
          speeds: _speeds,
          qualities: _qualities,
          currentSpeed: _playbackSpeed,
          currentQuality: _selectedQuality,
          currentVolume: _volume,
          isMuted: _isMuted,
          knownWidth: _videoWidth,
          knownHeight: _videoHeight,
          onSpeedChanged: (s) => setState(() => _playbackSpeed = s),
          onQualityChanged: (q) => setState(() => _selectedQuality = q),
          onVolumeChanged: (v, m) =>
              setState(() { _volume = v; _isMuted = m; }),
        ),
      ),
    ).then((_) {
      if (mounted && (_player?.state.playing ?? false)) _startControlsTimer();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen page — fills the screen for both portrait and landscape videos
// ─────────────────────────────────────────────────────────────────────────────
class _FullscreenPage extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final Duration initialPosition;
  final bool shouldPlay;
  final List<double> speeds;
  final Map<String, String> qualities;
  final double currentSpeed;
  final String currentQuality;
  final double currentVolume;
  final bool isMuted;
  final int knownWidth;   // dimensions already discovered in the card
  final int knownHeight;
  final void Function(double) onSpeedChanged;
  final void Function(String) onQualityChanged;
  final void Function(double, bool) onVolumeChanged;

  const _FullscreenPage({
    required this.player,
    required this.controller,
    required this.initialPosition,
    required this.shouldPlay,
    required this.speeds,
    required this.qualities,
    required this.currentSpeed,
    required this.currentQuality,
    required this.currentVolume,
    required this.isMuted,
    required this.knownWidth,
    required this.knownHeight,
    required this.onSpeedChanged,
    required this.onQualityChanged,
    required this.onVolumeChanged,
  });

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  bool _showControls = true;
  late double _speed;
  late String _quality;
  late double _volume;
  late bool _isMuted;
  bool _isLandscape = false;
  Timer? _controlsTimer;

  late int _videoWidth;
  late int _videoHeight;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
    _quality = widget.currentQuality;
    _volume = widget.currentVolume;
    _isMuted = widget.isMuted;

    // Use already-known dimensions from the card widget
    _videoWidth  = widget.knownWidth  > 0 ? widget.knownWidth  : (widget.player.state.width  ?? 0);
    _videoHeight = widget.knownHeight > 0 ? widget.knownHeight : (widget.player.state.height ?? 0);

    // Continue listening in case they weren't loaded yet
    _widthSub = widget.player.stream.width.listen((w) {
      if (w != null && w > 0 && mounted) {
        setState(() => _videoWidth = w);
        _lockOrientation();
      }
    });
    _heightSub = widget.player.stream.height.listen((h) {
      if (h != null && h > 0 && mounted) {
        setState(() => _videoHeight = h);
        _lockOrientation();
      }
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _lockOrientation();

    widget.player.seek(widget.initialPosition);
    if (widget.shouldPlay) widget.player.play();
    _startControlsTimer();
  }

  bool get _isPortraitVideo =>
      _videoHeight > 0 && _videoWidth > 0 && _videoHeight > _videoWidth;

  double get _videoAspectRatio {
    if (_videoWidth <= 0 || _videoHeight <= 0) return 16 / 9;
    return _videoWidth / _videoHeight;
  }

  void _lockOrientation() {
    if (_videoWidth <= 0 || _videoHeight <= 0) return;
    if (_isPortraitVideo) {
      _isLandscape = false;
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      _isLandscape = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (mounted) setState(() {});
  }

  void _toggleRotation() {
    setState(() => _isLandscape = !_isLandscape);
    SystemChrome.setPreferredOrientations(_isLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.player.state.playing) {
        setState(() => _showControls = false);
      }
    });
  }

  void _setVolume(double v) {
    _volume = v; _isMuted = v == 0;
    widget.player.setVolume(v * 100);
    widget.onVolumeChanged(v, _isMuted);
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    if (_isMuted) { _setVolume(_volume == 0 ? 1.0 : _volume); }
    else {
      widget.player.setVolume(0);
      widget.onVolumeChanged(_volume, true);
      if (mounted) setState(() => _isMuted = true);
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startControlsTimer();
        },
        onDoubleTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video: size to fill screen dimension matching video orientation ──
            Center(
              child: _isPortraitVideo
              // Portrait video: fill height, constrain width by aspect ratio
                  ? SizedBox(
                height: screenSize.height,
                width: screenSize.height * _videoAspectRatio,
                child: Video(
                  controller: widget.controller,
                  fit: BoxFit.fill,
                  controls: NoVideoControls,
                ),
              )
              // Landscape video: fill width, constrain height by aspect ratio
                  : SizedBox(
                width: screenSize.width,
                height: screenSize.width / _videoAspectRatio,
                child: Video(
                  controller: widget.controller,
                  fit: BoxFit.fill,
                  controls: NoVideoControls,
                ),
              ),
            ),

            if (_showControls) ...[
              // Top bar — rotation FIRST, back SECOND
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Directionality(
                    textDirection: TextDirection.ltr, // 🔥 THIS FIXES IT
                    child: Row(
                      children: [
                        // 🔄 Rotation ALWAYS LEFT
                        IconButton(
                          icon: Icon(
                            _isLandscape
                                ? Icons.screen_lock_rotation
                                : Icons.screen_rotation,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: _toggleRotation,
                        ),

                        const Spacer(),

                        // 🔙 Back ALWAYS RIGHT
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom gradient
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 160,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),

              // Center play/pause
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (widget.player.state.playing) {
                      widget.player.pause();
                      _controlsTimer?.cancel();
                      setState(() => _showControls = true);
                    } else {
                      widget.player.play();
                      _startControlsTimer();
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: StreamBuilder<bool>(
                      stream: widget.player.stream.playing,
                      initialData: true,
                      builder: (_, snap) => Icon(
                        (snap.data ?? true) ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 50,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 8, left: 12, right: 12,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<Duration>(
                        stream: widget.player.stream.position,
                        initialData: Duration.zero,
                        builder: (_, posSnap) => StreamBuilder<Duration>(
                          stream: widget.player.stream.duration,
                          initialData: Duration.zero,
                          builder: (_, durSnap) {
                            final pos = posSnap.data ?? Duration.zero;
                            final dur = durSnap.data ?? Duration.zero;
                            final maxMs = dur.inMilliseconds
                                .toDouble()
                                .clamp(1.0, double.infinity);
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: pos.inMilliseconds
                                    .toDouble()
                                    .clamp(0.0, maxMs),
                                max: maxMs,
                                activeColor: const Color(0xFF26A69A),
                                inactiveColor: const Color(0xFF26A69A).withOpacity(0.3),
                                onChanged: (v) {
                                  widget.player.seek(
                                      Duration(milliseconds: v.toInt()));
                                  _startControlsTimer();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          StreamBuilder<Duration>(
                            stream: widget.player.stream.position,
                            initialData: Duration.zero,
                            builder: (_, posSnap) => StreamBuilder<Duration>(
                              stream: widget.player.stream.duration,
                              initialData: Duration.zero,
                              builder: (_, durSnap) => Text(
                                '${_fmt(posSnap.data ?? Duration.zero)} / ${_fmt(durSnap.data ?? Duration.zero)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _controlsTimer?.cancel();
                              _toggleMute();
                              _startControlsTimer();
                            },
                            child: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white, size: 20,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 8),
                              ),
                              child: Slider(
                                value: _isMuted ? 0 : _volume,
                                min: 0, max: 1,
                                activeColor: const Color(0xFF26A69A),
                                inactiveColor: const Color(0xFF26A69A).withOpacity(0.3),
                                onChanged: (v) {
                                  _setVolume(v);
                                  _startControlsTimer();
                                },
                              ),
                            ),
                          ),
                          const Spacer(),
                          _ControlChip(
                            label: _speed == 1.0 ? '1x' : '${_speed}x',
                            icon: Icons.speed,
                            onTap: () {
                              _controlsTimer?.cancel();
                              _showSpeedSheet();
                            },
                          ),
                          const SizedBox(width: 6),
                          _ControlChip(
                            label: _quality,
                            onTap: () {
                              _controlsTimer?.cancel();
                              _showQualitySheet();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SpeedSheet(
        speeds: widget.speeds,
        current: _speed,
        onSelect: (s) {
          Navigator.pop(context);
          widget.player.setRate(s);
          widget.onSpeedChanged(s);
          setState(() => _speed = s);
          _startControlsTimer();
        },
      ),
    ).then((_) => _startControlsTimer());
  }

  void _showQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _QualitySheet(
        qualities: widget.qualities,
        current: _quality,
        onSelect: (label) async {
          Navigator.pop(context);
          final url = widget.qualities[label]!;
          final pos = widget.player.state.position;
          final was = widget.player.state.playing;
          try {
            await widget.player.open(Media(url), play: false);
            await widget.player.setVolume(_volume * 100);
            await widget.player.seek(pos);
            if (was) widget.player.play();
            widget.onQualityChanged(label);
            if (mounted) setState(() => _quality = label);
          } catch (e) { debugPrint('Quality switch error: $e'); }
          _startControlsTimer();
        },
      ),
    ).then((_) => _startControlsTimer());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────
class _ControlChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _ControlChip({required this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

class _SpeedSheet extends StatelessWidget {
  final List<double> speeds;
  final double current;
  final void Function(double) onSelect;
  const _SpeedSheet(
      {required this.speeds, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('سرعة التشغيل',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      ...speeds.map((s) => ListTile(
        title: Text(s == 1.0 ? '1x' : '${s}x',
            style: TextStyle(
                color: current == s ? Colors.blue : Colors.white,
                fontWeight: current == s
                    ? FontWeight.bold
                    : FontWeight.normal)),
        trailing:
        current == s ? const Icon(Icons.check, color: Colors.blue) : null,
        onTap: () => onSelect(s),
      )),
      const SizedBox(height: 16),
    ],
  );
}

class _QualitySheet extends StatelessWidget {
  final Map<String, String> qualities;
  final String current;
  final void Function(String) onSelect;
  const _QualitySheet(
      {required this.qualities,
        required this.current,
        required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('جودة الفيديو',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      ...qualities.keys.map((label) => ListTile(
        title: Text(label,
            style: TextStyle(
                color: current == label ? Colors.blue : Colors.white,
                fontWeight: current == label
                    ? FontWeight.bold
                    : FontWeight.normal)),
        trailing: current == label
            ? const Icon(Icons.check, color: Colors.blue)
            : null,
        onTap: () => onSelect(label),
      )),
      const SizedBox(height: 16),
    ],
  );
}