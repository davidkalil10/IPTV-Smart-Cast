import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final Channel channel;
  final VoidCallback onNextEpisode;
  final VoidCallback onShowEpisodes;
  final Function(double ratio, BoxFit fit) onResize;

  const VideoControlsOverlay({
    super.key,
    required this.controller,
    required this.channel,
    required this.onNextEpisode,
    required this.onShowEpisodes,
    required this.onResize,
  });

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  bool _showControls = true;
  bool _showSettings = false;
  bool _isLocked = false;
  Timer? _hideTimer;
  double _volume = 1.0;
  double _brightness = 0.5;

  // Aspect Ratio State
  static const List<String> _aspectRatios = [
    'Fit Parent',
    'Match Parent',
    'Fill Parent',
    '16:9',
    '4:3',
  ];
  int _aspectRatioIndex = 0; // Starts at Fit Parent usually
  String? _osdMessage;
  Timer? _osdTimer;

  // Settings Mock State
  int _selectedVideoTrack = 1;
  int _selectedAudioTrack = 1;
  int _selectedSubtitleTrack = 0; // Disabled by default
  int _subtitleFontSize = 20;

  // Drag updates
  bool _isDraggingVolume = false;
  bool _isDraggingBrightness = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    widget.controller.setVolume(_volume);
    widget.controller.addListener(_onControllerScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerScroll);
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    super.dispose();
  }

  void _onControllerScroll() {
    if (mounted) setState(() {});
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      _showControls = !_showSettings;
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isLocked && !_showSettings) {
        setState(() => _showControls = false);
      }
    });
  }

  void _resetHideTimer() {
    if (_showControls) _startHideTimer();
  }

  void _seekRelative(Duration amount) {
    _resetHideTimer();
    final newPos = widget.controller.value.position + amount;
    widget.controller.seekTo(newPos);
  }

  void _togglePlay() {
    _resetHideTimer();
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _showOsdMessage(String msg) {
    setState(() => _osdMessage = msg);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _osdMessage = null);
    });
  }

  // Aspect Ratio Logic
  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioIndex = (_aspectRatioIndex + 1) % _aspectRatios.length;
    });
    _showOsdMessage(_aspectRatios[_aspectRatioIndex]);

    // Notify parent
    if (widget.controller.value.isInitialized) {
      final videoRatio = widget.controller.value.aspectRatio;
      final newRatio = _getAspectRatio(videoRatio);
      final newFit = _getBoxFit();
      widget.onResize(newRatio, newFit);
    }
  }

  double _getAspectRatio(double videoRatio) {
    switch (_aspectRatios[_aspectRatioIndex]) {
      case '16:9':
        return 16 / 9;
      case '4:3':
        return 4 / 3;
      case 'Match Parent':
        return 1.0; // Handled by wrapping layout usually, but here simulating via AspectRatio overrides
      case 'Fill Parent':
        return MediaQuery.of(context).size.width /
            MediaQuery.of(context).size.height;
      case 'Fit Parent':
      default:
        return videoRatio;
    }
  }

  BoxFit _getBoxFit() {
    switch (_aspectRatios[_aspectRatioIndex]) {
      case 'Fill Parent':
        return BoxFit.cover;
      case 'Match Parent':
        return BoxFit.contain;
      case 'Fit Parent':
        return BoxFit.contain;
      default:
        return BoxFit
            .contain; // For forced aspect ratios, we typically let the AspectRatio widget handle it
    }
  }

  // Speed Menu Logic
  void _showSpeedMenu() {
    _resetHideTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Velocidade de reprodução',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...[0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                return ListTile(
                  leading: Icon(
                    widget.controller.value.playbackSpeed == speed
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.grey[800],
                  ),
                  title: Text(
                    '${speed == 1.0 ? "1x (Normal)" : "${speed}x"}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    widget.controller.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                    setState(() {}); // Refresh UI
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, bool isRightSide) {
    setState(() {
      double delta = details.primaryDelta! / -200;
      if (isRightSide) {
        _isDraggingVolume = true;
        _volume = (_volume + delta).clamp(0.0, 1.0);
        widget.controller.setVolume(_volume);
      } else {
        _isDraggingBrightness = true;
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isDraggingVolume = false;
      _isDraggingBrightness = false;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  List<String> _getVideoTracks() {
    // Return default if no tracks detected
    return ['Padrão'];
  }

  List<String> _getAudioTracks() {
    // Return default if no tracks detected
    return ['Padrão'];
  }

  List<String> _getSubtitleTracks() {
    // Subtitles can be empty if none exist
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // ... rest of build logic

    // We need to Apply Aspect Ratio to the *Parent* of this Overlay really, but since this Overlay sits ON TOP of the video,
    // we can't easily change the video's sizing from *inside* here without a callback or state lift.
    // However, typical pattern is the VideoPlayer is in the background.
    // To solve this properly, we should wrap the VideoPlayer in the Parent Screen with a ValueListenable or similar.
    // BUT since I am editing THIS file, maybe I can just display the Message here, and rely on the Parent to read a "Global" or "Provider" state?
    // Actually, 'VideoControlsOverlay' is just Controls. The 'PlayerScreen' has the `AspectRatio` widget.
    // I will implement a quick workaround: The 'PlayerScreen' needs to be updated to respect this.
    // For now, I will implement the OSD and the State, but the actual resizing might not work unless I lift state or use a GlobalKey/Provider.
    // Wait, the user asked to "alternar". I need to allow this change.
    // The cleanest way without refactoring PlayerScreen deeply is to let PlayerScreen manage it?
    // No, I'll assume for this task I can only edit this file to show the UI, and if I need to change video size, I might need to edit PlayerScreen too.
    // Let's check: PlayerScreen builds `AspectRatio` using `_videoPlayerController!.value.aspectRatio`.
    // I can't change that from here easily without a callback.
    // I will add a callback `onAspectRatioChanged`? Or just implement the OSD for now?
    // User requirement: "proporção do conteudo na tela deve alternar".
    // I'll stick to implementing the UI logic here and I will simply update `PlayerScreen` in a subsequent step if needed, or if I can, I'll rewrite `PlayerScreen` to listen to a stream/callback.
    // Actually, `VideoControlsOverlay` is inside `Stack`.
    // I will add a callback to the constructor for `onAspectRatioChanged`?
    // Let's do a simple hack: I will assume `PlayerScreen` isn't updating yet, but I will implement the logic.
    // *Self-correction*: I can't satisfy the user fully without the video actually changing size.
    // I'll modify `PlayerScreen` in the next step to use a notifier or state.
    // For this file, I'll impl the UI.

    if (_isLocked) {
      return GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startHideTimer();
        },
        child: Container(
          color: Colors.transparent,
          child: _showControls
              ? Stack(
                  children: [
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(
                          Icons.lock,
                          color: Colors.purpleAccent,
                          size: 30,
                        ),
                        onPressed: () => setState(() => _isLocked = false),
                      ),
                    ),
                    const Center(
                      child: Text(
                        "Tela Bloqueada",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_showSettings) {
          setState(() => _showSettings = false);
        } else {
          _toggleControls();
        }
      },
      onVerticalDragUpdate: (details) {
        if (_showSettings) return;
        final screenWidth = MediaQuery.of(context).size.width;
        final isRight = details.localPosition.dx > screenWidth / 2;
        _onVerticalDragUpdate(details, isRight);
      },
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        color: (_showControls || _showSettings)
            ? Colors.black45
            : Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity((1.0 - _brightness) * 0.7),
              ),
            ),

            // OSD Message (Centered)
            if (_osdMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _osdMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            if (_showControls && !_showSettings) ...[
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 40,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.channel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cast, color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.lock_open, color: Colors.white),
                        onPressed: () => setState(() => _isLocked = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _toggleSettings,
                      ),
                    ],
                  ),
                ),
              ),

              // Center Controls
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.replay_10,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: () =>
                          _seekRelative(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 70,
                      ),
                      onPressed: _togglePlay,
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      icon: const Icon(
                        Icons.forward_10,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: () =>
                          _seekRelative(const Duration(seconds: 10)),
                    ),
                  ],
                ),
              ),

              // Sliders Indicators
              if (_isDraggingVolume)
                Positioned(
                  right: 30,
                  top: 100,
                  bottom: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.volume_up, color: Colors.white),
                      const SizedBox(height: 10),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: LinearProgressIndicator(
                            value: _volume,
                            backgroundColor: Colors.grey[700],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isDraggingBrightness)
                Positioned(
                  left: 30,
                  top: 100,
                  bottom: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.brightness_6, color: Colors.white),
                      const SizedBox(height: 10),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: LinearProgressIndicator(
                            value: _brightness,
                            backgroundColor: Colors.grey[700],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDuration(widget.controller.value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                                activeTrackColor: Colors.purpleAccent,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: widget
                                    .controller
                                    .value
                                    .position
                                    .inSeconds
                                    .toDouble()
                                    .clamp(
                                      0,
                                      widget.controller.value.duration.inSeconds
                                          .toDouble(),
                                    ),
                                min: 0,
                                max:
                                    widget.controller.value.duration.inSeconds
                                            .toDouble() >
                                        0
                                    ? widget.controller.value.duration.inSeconds
                                          .toDouble()
                                    : 1.0,
                                onChanged: (val) {
                                  _resetHideTimer();
                                  widget.controller.seekTo(
                                    Duration(seconds: val.toInt()),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(widget.controller.value.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (widget.channel.type == 'series' ||
                              widget.channel.type == 'series_episode')
                            _buildBottomAction(
                              Icons.video_library,
                              'EPISÓDIOS',
                              widget.onShowEpisodes,
                            ),

                          _buildBottomAction(
                            Icons.aspect_ratio,
                            'Proporção..',
                            _cycleAspectRatio,
                          ),
                          _buildBottomAction(
                            Icons.speed,
                            'Velocidade..',
                            _showSpeedMenu,
                          ),

                          // Subtitles button removed
                          if (widget.channel.type == 'series' ||
                              widget.channel.type == 'series_episode')
                            TextButton.icon(
                              onPressed: widget.onNextEpisode,
                              icon: const Icon(
                                Icons.skip_next,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Próximo ep..',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_showSettings)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 350,
                child: Container(
                  color: Colors.black.withOpacity(0.95),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: _toggleSettings,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          children: [
                            _buildSettingSection(
                              'Faixas de vídeo',
                              _getVideoTracks(),
                              _selectedVideoTrack,
                              (idx) =>
                                  setState(() => _selectedVideoTrack = idx),
                            ),
                            const Divider(color: Colors.white24),

                            _buildSettingSection(
                              'Faixas de áudio',
                              _getAudioTracks(),
                              _selectedAudioTrack,
                              (idx) =>
                                  setState(() => _selectedAudioTrack = idx),
                            ),
                            const Divider(color: Colors.white24),

                            if (_getSubtitleTracks().isNotEmpty) ...[
                              _buildSettingSection(
                                'Faixas de legendas',
                                _getSubtitleTracks(),
                                _selectedSubtitleTrack,
                                (idx) => setState(
                                  () => _selectedSubtitleTrack = idx,
                                ),
                              ),
                              const Divider(color: Colors.white24),
                            ],

                            const Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.settings_applications,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Configurações de legendas',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tamanho da fonte',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  DropdownButton<int>(
                                    value: _subtitleFontSize,
                                    dropdownColor: Colors.grey[900],
                                    underline: Container(),
                                    style: const TextStyle(color: Colors.white),
                                    items: [20, 24, 28, 32]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e.toString()),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _subtitleFontSize = v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
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
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSection(
    String title,
    List<String> options,
    int selectedIndex,
    Function(int) onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.video_settings, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...List.generate(options.length, (index) {
          final isSelected = index == selectedIndex;
          return InkWell(
            onTap: () => onSelect(index),
            child: Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8, top: 4),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      options[index],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
