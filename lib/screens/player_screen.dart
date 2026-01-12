import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../widgets/video_controls_overlay.dart';
import '../providers/channel_provider.dart';
import '../services/playback_service.dart';
import 'dart:async';
import 'package:simple_pip_mode/simple_pip.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<dynamic>? episodes;
  final int? currentEpisodeIndex;
  final String? currentSeason;

  final List<String>? seasons;
  final Map<String, dynamic>? allEpisodesMap;
  final Duration? startPosition;
  final String? seriesId;

  const PlayerScreen({
    super.key,
    required this.channel,
    this.episodes,
    this.currentEpisodeIndex,
    this.currentSeason,
    this.seasons,
    this.allEpisodesMap,
    this.startPosition,
    this.seriesId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  Timer? _progressTimer;
  bool _isPip = false;
  late SimplePip _pip;

  bool _isError = false;
  String _errorMessage = '';
  double? _overrideAspectRatio;
  BoxFit _overrideFit = BoxFit.contain;
  int _subtitleFontSize = 48;

  @override
  void initState() {
    super.initState();
    // Force landscape for player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initializePlayer();
    _pip = SimplePip(
      onPipEntered: () {
        setState(() {
          _isPip = true;
        });
      },
      onPipExited: () {
        setState(() {
          _isPip = false;
        });
      },
    );
    _pip.setAutoPipMode();
  }

  Future<void> _initializePlayer() async {
    // Create a Player instance
    _player = Player();

    // Create a VideoController to handle video output from [Player]
    _videoController = VideoController(_player);

    // Play the media (start paused if we are going to seek)
    await _player.open(
      Media(widget.channel.streamUrl),
      play: widget.startPosition == null,
    );

    // Listen for errors
    _player.stream.error.listen((error) {
      debugPrint("Player Error: $error");
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = error.toString();
        });
      }
    });

    setState(() {});

    if (widget.startPosition != null) {
      debugPrint(
        "PLAYER: Starting resume process. Target: ${widget.startPosition}",
      );
      try {
        // Wait for metadata/duration load
        if (_player.state.duration == Duration.zero) {
          debugPrint("PLAYER: Waiting for duration...");
          await _player.stream.duration
              .firstWhere((d) => d != Duration.zero)
              .timeout(const Duration(seconds: 10));
          debugPrint("PLAYER: Duration loaded: ${_player.state.duration}");
        }

        // Seek
        debugPrint("PLAYER: Seeking to: ${widget.startPosition}");
        await _player.seek(widget.startPosition!);
        debugPrint("PLAYER: Seek done.");

        // Resume
        await _player.play();
        debugPrint("PLAYER: Play called.");

        // Verification / Retry logic
        // Sometimes stream starts from 0 anyway. Check after a delay.
        await Future.delayed(const Duration(seconds: 2));
        if (mounted &&
            _player.state.position.inSeconds <
                (widget.startPosition!.inSeconds - 10)) {
          debugPrint(
            "PLAYER: Position reset detected. Reseeking to ${widget.startPosition}...",
          );
          await _player.seek(widget.startPosition!);
        }
      } catch (e) {
        debugPrint("PLAYER: Seek error: $e");
        await _player.play();
      }
    } else {
      debugPrint("PLAYER: No startPosition provided. Starting normally.");
    }

    // Start tracking progress
    _startProgressTracking();
  }

  bool _isUserRestart = false;

  void _startProgressTracking() {
    // Save every 5 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final position = _player.state.position.inSeconds;
      final duration = _player.state.duration.inSeconds;

      // PROTECT RESUME:
      // If we intended to resume (>10s) but current position is near 0 (<5s),
      // and the user didn't manually restart, DO NOT SAVE.
      // This prevents the "reset bug" from wiping out progress.
      if (widget.startPosition != null &&
          widget.startPosition!.inSeconds > 10 &&
          position < 5 &&
          !_isUserRestart) {
        debugPrint(
          "PLAYER: Saving SKIPPED causing potential reset bug from ${widget.startPosition} to 0.",
        );
        return;
      }

      if (duration > 0) {
        PlaybackService().saveProgress(
          widget.channel.id,
          position,
          duration,
          seriesId: widget.seriesId,
        );
      }
    });
  }

  @override
  void dispose() {
    // Enforce landscape even on dispose, just to be safe
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _progressTimer?.cancel();
    // One last save on exit
    final position = _player.state.position.inSeconds;
    final duration = _player.state.duration.inSeconds;
    // PROTECT RESUME ON EXIT:
    // If we intended to resume (>10s) but current position is near 0 (<5s),
    // and the user didn't manually restart, DO NOT SAVE.
    if (widget.startPosition != null &&
        widget.startPosition!.inSeconds > 10 &&
        position < 5 &&
        !_isUserRestart) {
      debugPrint("PLAYER: Dispose Save SKIPPED to prevent reset bug.");
    } else if (duration > 0) {
      PlaybackService().saveProgress(
        widget.channel.id,
        position,
        duration,
        seriesId: widget.seriesId,
      );
    }

    _player.dispose();
    super.dispose();
  }

  void _onNextEpisode() {
    if (widget.episodes != null && widget.currentEpisodeIndex != null) {
      // 1. Try Next Episode in Current Season
      if (widget.currentEpisodeIndex! + 1 < widget.episodes!.length) {
        _switchEpisode(
          widget.currentEpisodeIndex! + 1,
          widget.currentSeason!,
          widget.episodes!,
        );
      }
      // 2. Try Next Season
      else if (widget.seasons != null &&
          widget.allEpisodesMap != null &&
          widget.currentSeason != null) {
        final currentSeasonIndex = widget.seasons!.indexOf(
          widget.currentSeason!,
        );

        if (currentSeasonIndex != -1 &&
            currentSeasonIndex + 1 < widget.seasons!.length) {
          // Found Next Season
          final nextSeason = widget.seasons![currentSeasonIndex + 1];
          final nextEpisodes =
              widget.allEpisodesMap![nextSeason] as List<dynamic>;
          if (nextEpisodes.isNotEmpty) {
            _switchEpisode(0, nextSeason, nextEpisodes);
          } else {
            _showNoMoreEpisodesMsg();
          }
        }
        // 3. Loop to Start (Season 1 Episode 1)
        else if (widget.seasons!.isNotEmpty) {
          final firstSeason = widget.seasons!.first;
          final firstEpisodes =
              widget.allEpisodesMap![firstSeason] as List<dynamic>;
          if (firstEpisodes.isNotEmpty) {
            _switchEpisode(0, firstSeason, firstEpisodes);
          } else {
            _showNoMoreEpisodesMsg();
          }
        } else {
          _showNoMoreEpisodesMsg();
        }
      } else {
        _showNoMoreEpisodesMsg();
      }
    } else {
      _showNoMoreEpisodesMsg();
    }
  }

  void _showNoMoreEpisodesMsg() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Não há mais episódios disponíveis.")),
    );
  }

  void _switchEpisode(int index, String season, List<dynamic> episodeList) {
    final ep = episodeList[index];
    final provider = context.read<ChannelProvider>();
    final baseUrl = provider.savedUrl ?? '';
    final user = provider.savedUser ?? '';
    final pass = provider.savedPass ?? '';
    final ext = ep['container_extension'] ?? 'mp4';
    final id = ep['id'].toString();

    final url = '$baseUrl/series/$user/$pass/$id.$ext';

    // Construct cleaner title
    final epNum = ep['episode_num'] ?? '?';
    final epName = 'S${season}E$epNum';

    final newChannel = Channel(
      id: id,
      name: '${widget.channel.name.split(" - S").first} - $epName',
      streamUrl: url,
      logoUrl: ep['info']?['movie_image'] ?? widget.channel.logoUrl,
      category: widget.channel.category,
      type: 'series_episode',
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: newChannel,
          episodes: episodeList,
          currentEpisodeIndex: index,
          currentSeason: season,
          seasons: widget.seasons,
          allEpisodesMap: widget.allEpisodesMap,
          seriesId: widget.seriesId,
        ),
      ),
    );
  }

  void _showEpisodesList() {
    if (widget.episodes == null || widget.episodes!.isEmpty) {
      _showNoMoreEpisodesMsg();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (_, scrollController) {
            return Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Episódios - Temporada ${widget.currentSeason}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: widget.episodes!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final ep = widget.episodes![index];
                        final isPlaying = index == widget.currentEpisodeIndex;
                        final epTitle = ep['title'].toString();
                        final epImg = ep['info']?['movie_image'] ?? '';

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context); // Close sheet
                            if (!isPlaying) {
                              _switchEpisode(
                                index,
                                widget.currentSeason!,
                                widget.episodes!,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? Colors.purple.withOpacity(0.2)
                                  : Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              border: isPlaying
                                  ? Border.all(color: Colors.purpleAccent)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    width: 80,
                                    height: 50,
                                    child: CachedNetworkImage(
                                      imageUrl: epImg,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          Container(color: Colors.grey[800]),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.movie,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        epTitle,
                                        style: TextStyle(
                                          color: isPlaying
                                              ? Colors.purpleAccent
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (ep['info']?['plot'] != null)
                                        Text(
                                          ep['info']['plot'].toString(),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (isPlaying)
                                  const Icon(
                                    Icons.equalizer,
                                    color: Colors.purpleAccent,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              const Text(
                'Erro ao reproduzir vídeo',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPip) {
      // Minimal UI for PiP
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: _overrideAspectRatio ?? 16 / 9,
            child: FittedBox(
              fit: _overrideFit,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height:
                    MediaQuery.of(context).size.width /
                    (_overrideAspectRatio ?? 16 / 9),
                child: Video(
                  controller: _videoController,
                  controls: NoVideoControls,
                  fit: _overrideFit == BoxFit.contain
                      ? BoxFit.contain
                      : BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Video Layer
          Center(
            child: AspectRatio(
              aspectRatio: _overrideAspectRatio ?? 16 / 9,
              child: FittedBox(
                fit: _overrideFit,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height:
                      MediaQuery.of(context).size.width /
                      (_overrideAspectRatio ?? 16 / 9),
                  child: Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: TextStyle(
                        height: 1.4,
                        fontSize: _subtitleFontSize.toDouble(),
                        letterSpacing: 0.0,
                        wordSpacing: 0.0,
                        color: const Color(0xffffffff),
                        fontWeight: FontWeight.normal,
                        backgroundColor: const Color(0xaa000000),
                      ),
                    ),
                    fit: _overrideFit == BoxFit.contain
                        ? BoxFit.contain
                        : BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          // Controls Layer
          VideoControlsOverlay(
            player: _player,
            channel: widget.channel,
            onNextEpisode: _onNextEpisode,
            onShowEpisodes: _showEpisodesList,
            onResize: (ratio, fit) {
              setState(() {
                _overrideAspectRatio = ratio > 0 ? ratio : null;
                _overrideFit = fit;
              });
            },
            onSubtitleSizeChanged: (size) {
              setState(() => _subtitleFontSize = size);
            },
            onRestart: () {
              // User manually restarted. Allow saving "0" progress.
              _isUserRestart = true;
              _player.seek(Duration.zero);
            },
          ),
        ],
      ),
    );
  }
}
