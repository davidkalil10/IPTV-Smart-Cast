import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../widgets/video_controls_overlay.dart';
import '../providers/channel_provider.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<dynamic>? episodes;
  final int? currentEpisodeIndex;
  final String? currentSeason;

  final List<String>? seasons;
  final Map<String, dynamic>? allEpisodesMap;

  const PlayerScreen({
    super.key,
    required this.channel,
    this.episodes,
    this.currentEpisodeIndex,
    this.currentSeason,
    this.seasons,
    this.allEpisodesMap,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;

  bool _isError = false;
  String _errorMessage = '';
  double? _overrideAspectRatio;
  BoxFit _overrideFit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    // Force landscape for player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Create a Player instance
    _player = Player();

    // Create a VideoController to handle video output from [Player]
    _videoController = VideoController(_player);

    // Play the media
    await _player.open(Media(widget.channel.streamUrl));

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
  }

  @override
  void dispose() {
    // Restore orientations to default
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
          ),
        ],
      ),
    );
  }
}
