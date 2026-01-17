import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class WebVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final Duration? startPosition;
  final Function(Duration position, Duration duration)? onProgress;
  final VoidCallback? onCompleted;

  const WebVideoPlayer({
    super.key,
    required this.url,
    this.autoPlay = true,
    this.startPosition,
    this.onProgress,
    this.onCompleted,
  });

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      debugPrint('WEB PLAYER: Initializing for ${widget.url}');
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));

      await _controller.initialize();

      if (widget.startPosition != null) {
        await _controller.seekTo(widget.startPosition!);
      }

      _controller.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.autoPlay) {
          await _controller.play();
          _startHideControlsTimer();
        }
        _startProgressTimer();
      }
    } catch (e) {
      debugPrint('WEB PLAYER: Error initializing: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller.value.hasError) {
      debugPrint("WEB PLAYER ERROR: ${_controller.value.errorDescription}");
    }
    if (_controller.value.isCompleted) {
      widget.onCompleted?.call();
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isInitialized || !_controller.value.isPlaying) return;
      widget.onProgress?.call(
        _controller.value.position,
        _controller.value.duration,
      );
    });
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _controlsTimer?.cancel();
      } else {
        _controller.play();
        _startHideControlsTimer();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && _controller.value.isPlaying) {
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying && !_isDragging) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Falha ao carregar video:\n$_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),

            // Tap Detector (Always active)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            if (_showControls) ...[
              // Black Overlay (Blocks interaction with transparent detector, but that's fine as it has its own controls)
              Positioned.fill(child: Container(color: Colors.black26)),

              // Center Play/Pause (Pass-through taps to toggle play, NOT controls)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),

              // Bottom Controls
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(_controller.value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                              activeTrackColor: Colors.purpleAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _controller.value.position.inSeconds
                                  .toDouble(),
                              min: 0,
                              max: _controller.value.duration.inSeconds
                                  .toDouble(),
                              onChanged: (value) {
                                setState(() {
                                  _isDragging = true;
                                });
                                _controller.seekTo(
                                  Duration(seconds: value.toInt()),
                                );
                              },
                              onChangeEnd: (value) {
                                setState(() {
                                  _isDragging = false;
                                });
                                if (_controller.value.isPlaying) {
                                  _startHideControlsTimer();
                                }
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
