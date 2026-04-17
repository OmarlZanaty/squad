import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? lowQualityUrl;
  final String? mediumQualityUrl;
  final String? highQualityUrl;
  final Function(double aspectRatio)? onAspectRatio;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.lowQualityUrl,
    this.mediumQualityUrl,
    this.highQualityUrl,
    this.onAspectRatio,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  String? _error;
  double _playbackSpeed = 1.0;
  Timer? _hideTimer;
  String _selectedQuality = 'Auto'; // Default to Auto

  // Available playback speeds
  static const List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  // Map to hold available qualities
  Map<String, String> _qualities = {};

  @override
  void initState() {
    super.initState();
    _initializeQualities();
    _initializeVideo();
  }

  void _initializeQualities() {
    _qualities['Auto'] = widget.videoUrl;
    if ((widget.highQualityUrl ?? '').isNotEmpty) _qualities['1080p'] = widget.highQualityUrl!;
    if ((widget.mediumQualityUrl ?? '').isNotEmpty) _qualities['720p'] = widget.mediumQualityUrl!;
    if ((widget.lowQualityUrl ?? '').isNotEmpty) _qualities['360p'] = widget.lowQualityUrl!;

    // Sort qualities from highest to lowest resolution for display
    _qualities = Map.fromEntries(
      _qualities.entries.toList()..sort((a, b) {
        if (a.key == 'Auto') return 1; // 'Auto' always last
        if (b.key == 'Auto') return -1;
        return int.parse(b.key.replaceAll('p', ''))
            .compareTo(int.parse(a.key.replaceAll('p', '')));
      }),
    );
  }

  Future<void> _initializeVideo({Duration? startPosition}) async {
    // Ensure any previous controller is disposed before creating a new one
    if (_isInitialized) {
      _controller.removeListener(_listener);
      _controller.dispose();
      _isInitialized = false;
    }

    try {
      final currentVideoUrl = _qualities[_selectedQuality] ?? widget.videoUrl;
      final cleanUrl = currentVideoUrl.replaceAll(RegExp(r'/+$'), '');

      print("🎥 FINAL VIDEO URL: $cleanUrl (Quality: $_selectedQuality)");

      _controller = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));

      await _controller.initialize();
      _controller.addListener(_listener);

      if (startPosition != null) {
        await _controller.seekTo(startPosition);
      }

      widget.onAspectRatio?.call(_controller.value.aspectRatio);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e) {
      print("❌ VIDEO ERROR: $e");

      if (mounted) {
        setState(() {
          _error = 'Failed to load video';
          _isInitialized = false;
        });
      }
    }
  }

  void _listener() {
    if (mounted) {
      // Only call setState if something relevant changed to avoid unnecessary rebuilds
      if (_controller.value.hasError && _error == null) {
        setState(() {
          _error = _controller.value.errorDescription ?? 'Video playback error';
        });
      } else if (!_controller.value.hasError && _error != null) {
        setState(() {
          _error = null;
        });
      }

      // AUTO-HIDE: If video is playing and controls are visible, start the 3s timer
      if (_controller.value.isPlaying && _showControls && _hideTimer == null) {
        _startHideTimer();
      }
      setState(() {}); // Rebuild to update progress bar, play/pause button etc.
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_listener);
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls && _controller.value.isPlaying) {
        _startHideTimer();
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _hideTimer?.cancel();
        _showControls = true; // Show controls when paused
      } else {
        _controller.play();
        _startHideTimer(); // Start timer to hide controls
      }
    });
  }

  void _switchQuality(String? newQuality) async {
    if (newQuality == null || newQuality == _selectedQuality) return;

    final currentPosition = _controller.value.position;
    final wasPlaying = _controller.value.isPlaying;

    setState(() {
      _selectedQuality = newQuality;
      _isInitialized = false; // Show loading spinner while switching
    });

    await _initializeVideo(startPosition: currentPosition);

    if (wasPlaying) {
      _controller.play();
    }
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(
          controller: _controller,
          currentSpeed: _playbackSpeed,
          onSpeedChanged: (speed) {
            setState(() {
              _playbackSpeed = speed;
            });
          },
          selectedQuality: _selectedQuality,
          qualities: _qualities,
          onSwitchQuality: _switchQuality,
        ),
      ),
    );
  }

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SpeedSelectorSheet(
        currentSpeed: _playbackSpeed,
        speedOptions: _speedOptions,
        onSpeedSelected: (speed) {
          setState(() {
            _playbackSpeed = speed;
            _controller.setPlaybackSpeed(speed);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  String _format(Duration d) {
    if (d.inMilliseconds <= 0) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSpeed(double speed) {
    if (speed == 1.0) return '1x';
    if (speed == speed.toInt()) return '${speed.toInt()}x';
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _errorView();
    }

    if (!_isInitialized) {
      return _loadingView();
    }

    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final isPlaying = _controller.value.isPlaying;

    // AUTO-HIDE LOGIC: Controls are visible only if _showControls is true OR the video is paused
    final shouldShowControls = _showControls || !isPlaying;

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),

              if (shouldShowControls) ...[
                _centerPlayButton(),
                _topControls(), // Added top controls for quality selection
                _bottomControls(duration, position),
              ],

              if (_controller.value.isBuffering)
                const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerPlayButton() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _controller.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _topControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_qualities.length > 1) // Only show if there are multiple qualities
              DropdownButton<String>(
                value: _selectedQuality,
                dropdownColor: Colors.black87,
                onChanged: _switchQuality,
                items: _qualities.keys.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls(Duration duration, Duration position) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: position.inMilliseconds.toDouble(),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (v) {
                _controller.seekTo(Duration(milliseconds: v.toInt()));
              },
              activeColor: Colors.redAccent,
              inactiveColor: Colors.white30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_format(position),
                    style: const TextStyle(color: Colors.white)),
                Row(
                  children: [
                    // Speed selector button
                    GestureDetector(
                      onTap: _showSpeedSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatSpeed(_playbackSpeed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_format(duration),
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _openFullScreen,
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _errorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/* ================= FULL SCREEN VIDEO PLAYER ================= */

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final double currentSpeed;
  final Function(double) onSpeedChanged;
  final String selectedQuality;
  final Map<String, String> qualities;
  final Function(String?) onSwitchQuality;

  const _FullScreenVideoPlayer({
    required this.controller,
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.selectedQuality,
    required this.qualities,
    required this.onSwitchQuality,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _fullScreenController;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  static const List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _playbackSpeed = widget.currentSpeed;
    _fullScreenController = widget.controller;
    _fullScreenController.addListener(_listener);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideTimer();
  }

  void _listener() {
    if (mounted) {
      setState(() {});
      if (_fullScreenController.value.isPlaying && _showControls && _hideTimer == null) {
        _startHideTimer();
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _fullScreenController.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fullScreenController.removeListener(_listener);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls && _fullScreenController.value.isPlaying) {
        _startHideTimer();
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_fullScreenController.value.isPlaying) {
        _fullScreenController.pause();
        _hideTimer?.cancel();
        _showControls = true;
      } else {
        _fullScreenController.play();
        _startHideTimer();
      }
    });
  }

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SpeedSelectorSheet(
        currentSpeed: _playbackSpeed,
        speedOptions: _speedOptions,
        onSpeedSelected: (speed) {
          setState(() {
            _playbackSpeed = speed;
            _fullScreenController.setPlaybackSpeed(speed);
            widget.onSpeedChanged(speed);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  String _format(Duration d) {
    if (d.inMilliseconds <= 0) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSpeed(double speed) {
    if (speed == 1.0) return '1x';
    if (speed == speed.toInt()) return '${speed.toInt()}x';
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _fullScreenController.value.duration;
    final position = _fullScreenController.value.position;
    final isPlaying = _fullScreenController.value.isPlaying;

    final shouldShowControls = _showControls || !isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: AspectRatio(
            aspectRatio: _fullScreenController.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_fullScreenController),

                if (shouldShowControls) ...[
                  _centerPlayButton(),
                  _topControls(), // Added top controls for quality selection
                  _bottomControls(duration, position),
                ],

                if (_fullScreenController.value.isBuffering)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerPlayButton() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _fullScreenController.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _topControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            if (widget.qualities.length > 1) // Only show if there are multiple qualities
              DropdownButton<String>(
                value: widget.selectedQuality,
                dropdownColor: Colors.black87,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    widget.onSwitchQuality(newValue);
                    // After switching quality, pop the full screen and let the main widget handle it
                    Navigator.pop(context);
                  }
                },
                items: widget.qualities.keys.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls(Duration duration, Duration position) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: position.inMilliseconds.toDouble(),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (v) {
                _fullScreenController.seekTo(Duration(milliseconds: v.toInt()));
              },
              activeColor: Colors.redAccent,
              inactiveColor: Colors.white30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_format(position),
                    style: const TextStyle(color: Colors.white)),
                Row(
                  children: [
                    // Speed selector button
                    GestureDetector(
                      onTap: _showSpeedSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatSpeed(_playbackSpeed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_format(duration),
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () { Navigator.pop(context); }, // Exit fullscreen
                      child: const Icon(Icons.fullscreen_exit,
                          color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= SPEED SELECTOR SHEET ================= */

class _SpeedSelectorSheet extends StatelessWidget {
  final double currentSpeed;
  final List<double> speedOptions;
  final Function(double) onSpeedSelected;

  const _SpeedSelectorSheet({
    required this.currentSpeed,
    required this.speedOptions,
    required this.onSpeedSelected,
  });

  String _formatSpeed(double speed) {
    if (speed == 1.0) return 'Normal';
    if (speed == speed.toInt()) return '${speed.toInt()}x';
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Playback Speed',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: speedOptions.length,
                itemBuilder: (context, index) {
                  final speed = speedOptions[index];
                  return ListTile(
                    title: Text(
                      _formatSpeed(speed),
                      style: TextStyle(
                        color: currentSpeed == speed ? Colors.redAccent : Colors.white,
                        fontWeight: currentSpeed == speed ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () => onSpeedSelected(speed),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
