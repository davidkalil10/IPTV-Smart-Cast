import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../models/channel.dart';

class VideoControlsOverlay extends StatefulWidget {
  final Player player;
  final Channel channel;
  final VoidCallback onNextEpisode;
  final VoidCallback onShowEpisodes;
  final Function(double ratio, BoxFit fit) onResize;
  final Function(int size) onSubtitleSizeChanged;
  final VoidCallback onRestart;
  final VoidCallback? onExit;

  const VideoControlsOverlay({
    super.key,
    required this.player,
    required this.channel,
    required this.onNextEpisode,
    required this.onShowEpisodes,
    required this.onResize,
    required this.onSubtitleSizeChanged,
    required this.onRestart,
    this.onExit,
  });

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  bool _showControls = true;
  bool _showSettings = false;
  bool _isLocked = false;
  Timer? _hideTimer;
  double _volume = 100.0; // media_kit volume is 0..100
  double _brightness = 0.5;

  // Aspect Ratio State
  static const List<String> _aspectRatios = [
    'Fit Parent',
    'Match Parent',
    'Fill Parent',
    '16:9',
    '4:3',
  ];
  int _aspectRatioIndex = 0;
  String? _osdMessage;
  Timer? _osdTimer;

  // Track State
  VideoTrack? _selectedVideoTrack;
  AudioTrack? _selectedAudioTrack;
  SubtitleTrack? _selectedSubtitleTrack;

  // Subtitle Settings
  int _subtitleFontSize = 48;

  // Drag updates
  bool _isDraggingVolume = false;
  bool _isDraggingBrightness = false;

  // Stream Subscriptions
  List<StreamSubscription> _subscriptions = [];

  // Player State Cache for UI
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  final FocusNode _backgroundFocusNode = FocusNode();
  final FocusNode _playFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startHideTimer();

    // Initial State
    _volume = widget.player.state.volume;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _isPlaying = widget.player.state.playing;
    _playbackSpeed = widget.player.state.rate;
    _selectedVideoTrack = widget.player.state.track.video;
    _selectedAudioTrack = widget.player.state.track.audio;
    _selectedSubtitleTrack = widget.player.state.track.subtitle;

    // Initial enforcement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceDefaultTracks();
      if (mounted) _playFocusNode.requestFocus();
    });

    // Subscribe to streams
    _subscriptions.add(
      widget.player.stream.position.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
    );
    _subscriptions.add(
      widget.player.stream.duration.listen((dur) {
        if (mounted) setState(() => _duration = dur);
      }),
    );
    _subscriptions.add(
      widget.player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      }),
    );
    _subscriptions.add(
      widget.player.stream.rate.listen((rate) {
        if (mounted) setState(() => _playbackSpeed = rate);
      }),
    );
    _subscriptions.add(
      widget.player.stream.volume.listen((vol) {
        if (mounted) setState(() => _volume = vol);
      }),
    );

    // Listen for currently selected track changes
    _subscriptions.add(
      widget.player.stream.track.listen((track) {
        if (mounted) {
          setState(() {
            _selectedVideoTrack = track.video;
            _selectedAudioTrack = track.audio;
            _selectedSubtitleTrack = track.subtitle;
          });
        }
      }),
    );

    // Listen for available tracks list changes (to enforce defaults when loaded)
    _subscriptions.add(
      widget.player.stream.tracks.listen((tracks) {
        if (mounted) {
          setState(() {}); // Update UI with new keys
          _enforceDefaultTracks();
        }
      }),
    );
  }

  void _enforceDefaultTracks() {
    // Helper to check and set default if current is auto
    // We assume 'auto' track has id 'auto'.
    final tracks = widget.player.state.tracks;

    // Video
    if (_selectedVideoTrack?.id == 'auto' || _selectedVideoTrack == null) {
      final realVideo = tracks.video
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      if (realVideo.isNotEmpty) {
        // Enforce first real track ("1:")
        widget.player.setVideoTrack(realVideo.first);
      }
    }

    // Audio
    if (_selectedAudioTrack?.id == 'auto' || _selectedAudioTrack == null) {
      final realAudio = tracks.audio
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      if (realAudio.isNotEmpty) {
        widget.player.setAudioTrack(realAudio.first);
      }
    }

    // Subtitle
    // User requested "1:" for subtitle too.
    // Assuming this means enable first subtitle if available, avoiding 'auto'.
    if (_selectedSubtitleTrack?.id == 'auto' ||
        _selectedSubtitleTrack == null) {
      final realSubs = tracks.subtitle
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      if (realSubs.isNotEmpty) {
        widget.player.setSubtitleTrack(realSubs.first);
      }
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _osdTimer?.cancel();
    _osdTimer?.cancel();
    _backgroundFocusNode.dispose();
    _playFocusNode.dispose();
    super.dispose();
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
      // Move focus to play button when controls appear
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playFocusNode.requestFocus();
      });
    } else {
      _hideTimer?.cancel();
      // Return focus to background when controls hide (so key presses wake it up)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _backgroundFocusNode.requestFocus();
      });
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
    final newPos = _position + amount;
    widget.player.seek(newPos);
  }

  void _togglePlay() {
    _resetHideTimer();
    widget.player.playOrPause();
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

    // Calculate aspect ratio
    // If width/height are null (audio only or not loaded), default to 16:9
    final videoParams =
        widget.player.state.width != null && widget.player.state.height != null
        ? widget.player.state.width! / widget.player.state.height!
        : 16 / 9;

    final newRatio = _getAspectRatio(videoParams);
    final newFit = _getBoxFit();
    widget.onResize(newRatio, newFit);
  }

  double _getAspectRatio(double videoRatio) {
    switch (_aspectRatios[_aspectRatioIndex]) {
      case '16:9':
        return 16 / 9;
      case '4:3':
        return 4 / 3;
      case 'Match Parent':
        return 1.0;
      case 'Fill Parent':
        // Approximation, user wants to fill.
        // Returning screen ratio here is a hack if we are using AspectRatio widget.
        // A better approach is dealing with BoxFit.cover
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
        return BoxFit.contain;
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
                    _playbackSpeed == speed
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.grey[800],
                  ),
                  title: Text(
                    '${speed == 1.0 ? "1x (Normal)" : "${speed}x"}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    widget.player.setRate(speed);
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

  void _onVerticalDragUpdate(DragUpdateDetails details, bool isRightSide) {
    setState(() {
      double delta = details.primaryDelta! / -200;
      if (isRightSide) {
        _isDraggingVolume = true;
        // Volume 0..100
        double newVol = (_volume + (delta * 100)).clamp(0.0, 100.0);
        widget.player.setVolume(newVol);
      } else {
        _isDraggingBrightness = true;
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        // Note: For actual brightness control, use a plugin like screen_brightness
        // This variable currently just affects the opacity overlay.
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

  // --- SETTINGS WIDGETS ---

  Widget _buildSettingSection<T>(
    String title,
    List<T> items,
    T? selectedItem,
    Function(T) onSelect,
    String Function(T) labelBuilder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 50, top: 10, bottom: 5),
          child: Row(
            children: [
              Icon(
                title.contains('vídeo')
                    ? Icons.video_settings
                    : title.contains('áudio')
                    ? Icons.audiotrack
                    : Icons.subtitles,
                color: Colors.white,
                size: 20,
              ),
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
        ...items.map((item) {
          final isSelected = selectedItem == item;
          return RadioListTile<T>(
            value: item,
            groupValue: selectedItem,
            onChanged: (val) {
              if (val != null) onSelect(val);
            },
            activeColor: Colors.white,
            title: Text(
              labelBuilder(item),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            dense: true,
            contentPadding: const EdgeInsets.only(left: 30),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return WillPopScope(
        onWillPop: () async {
          // If locked, prevent back unless unlocked? Or maybe just consume it.
          // Let's allow back to exit even if locked, strictly speaking,
          // or maybe we should just return false to enforce lock.
          // User didn't specify, but usually Lock means Lock.
          setState(() {
            _osdMessage = "Tela Bloqueada. Desbloqueie para sair.";
          });
          _showOsdMessage("Tela Bloqueada. Desbloqueie para sair.");
          return false;
        },
        child: GestureDetector(
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
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_showSettings) {
          setState(() => _showSettings = false);
          return false; // Do not exit
        }
        if (_showControls) {
          setState(() => _showControls = false);
          return false; // Do not exit, just hide controls
        }
        // System back pressed and controls are hidden -> Exit
        if (widget.onExit != null) widget.onExit!();
        return true; // Exit player
      },
      child: FocusScope(
        child: KeyboardListener(
          focusNode: _backgroundFocusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              // Any key press wakes up controls
              if (!_showControls) {
                setState(() => _showControls = true);
                _startHideTimer();
                // When waking up, focus the play button immediately
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _playFocusNode.requestFocus();
                });
              } else {
                _resetHideTimer();
              }
            }
          },
          child: GestureDetector(
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
                      color: Colors.black.withOpacity(
                        (1.0 - _brightness) * 0.7,
                      ),
                    ),
                  ),

                  // OSD Message
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
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                // UI Back Button: Always exit
                                if (widget.onExit != null) widget.onExit!();
                                Navigator.pop(context);
                              },
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
                            if (widget.channel.type != 'live')
                              IconButton(
                                icon: const Icon(
                                  Icons.replay,
                                  color: Colors.white,
                                ),
                                tooltip: 'Recomeçar',
                                onPressed: () {
                                  _resetHideTimer();
                                  widget.onRestart();
                                },
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.lock_open,
                                color: Colors.white,
                              ),
                              onPressed: () => setState(() => _isLocked = true),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                              ),
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
                              _isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                              size: 70,
                            ),
                            onPressed: _togglePlay,
                            focusNode: _playFocusNode,
                            autofocus: true,
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
                                  value: _volume / 100,
                                  backgroundColor: Colors.grey[700],
                                  valueColor: const AlwaysStoppedAnimation(
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
                                  valueColor: const AlwaysStoppedAnimation(
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
                                  _formatDuration(_position),
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
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 10,
                                          ),
                                      activeTrackColor: Colors.purpleAccent,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: _position.inSeconds
                                          .toDouble()
                                          .clamp(
                                            0,
                                            _duration.inSeconds.toDouble(),
                                          ),
                                      min: 0,
                                      max: _duration.inSeconds.toDouble() > 0
                                          ? _duration.inSeconds.toDouble()
                                          : 1.0,
                                      onChanged: (val) {
                                        _resetHideTimer();
                                        widget.player.seek(
                                          Duration(seconds: val.toInt()),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
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
                                  // Video Tracks
                                  _buildSettingSection<VideoTrack>(
                                    'Faixas de vídeo',
                                    widget.player.state.tracks.video
                                        .where(
                                          (t) => t.id != 'auto' && t.id != 'no',
                                        )
                                        .toList(),
                                    _selectedVideoTrack,
                                    (track) =>
                                        widget.player.setVideoTrack(track),
                                    (track) =>
                                        '${track.id}: ${track.codec ?? "Unknown"} ${track.w != null ? "${track.w}x${track.h}" : ""} ${track.bitrate != null ? "${(track.bitrate! / 1000).round()}kb/s" : ""}',
                                  ),
                                  const Divider(color: Colors.white24),

                                  // Audio Tracks
                                  _buildSettingSection<AudioTrack>(
                                    'Faixas de áudio',
                                    widget.player.state.tracks.audio
                                        .where(
                                          (t) => t.id != 'auto' && t.id != 'no',
                                        )
                                        .toList(),
                                    _selectedAudioTrack,
                                    (track) =>
                                        widget.player.setAudioTrack(track),
                                    (track) =>
                                        '${track.id}: ${track.language ?? "Unknown"} ${track.codec ?? ""} ${track.channels != null ? "${track.channels}ch" : ""} ${track.bitrate != null ? "${(track.bitrate! / 1000).round()}kb/s" : ""}',
                                  ),
                                  const Divider(color: Colors.white24),

                                  // Subtitle Tracks
                                  if (widget.player.state.tracks.subtitle.any(
                                    (t) => t.id != 'auto' && t.id != 'no',
                                  )) ...[
                                    _buildSettingSection<SubtitleTrack>(
                                      'Faixas de legendas',
                                      widget.player.state.tracks.subtitle
                                          .where((t) => t.id != 'auto')
                                          .toList(),
                                      _selectedSubtitleTrack,
                                      (track) =>
                                          widget.player.setSubtitleTrack(track),
                                      (track) {
                                        if (track.id == 'no')
                                          return 'Desativado';
                                        return '${track.id}: ${track.language ?? "Unknown"} ${track.codec ?? ""} ${track.title ?? ""}';
                                      },
                                    ),
                                    const Divider(color: Colors.white24),
                                  ],

                                  const Padding(
                                    padding: EdgeInsets.only(
                                      top: 10,
                                      bottom: 6,
                                    ),
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
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        DropdownButton<int>(
                                          value: _subtitleFontSize,
                                          dropdownColor: Colors.grey[900],
                                          underline: Container(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          items:
                                              [
                                                    20,
                                                    24,
                                                    28,
                                                    32,
                                                    36,
                                                    40,
                                                    48,
                                                    56,
                                                    64,
                                                  ]
                                                  .map(
                                                    (e) => DropdownMenuItem(
                                                      value: e,
                                                      child: Text(e.toString()),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(
                                                () => _subtitleFontSize = v,
                                              );
                                              widget.onSubtitleSizeChanged(v);
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
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
