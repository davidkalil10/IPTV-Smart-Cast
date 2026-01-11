import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'dart:ui';

import '../models/channel.dart';

import '../providers/channel_provider.dart';

import '../services/iptv_service.dart';

import 'player_screen.dart';

import '../services/playback_service.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Channel channel;

  const SeriesDetailScreen({super.key, required this.channel});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  bool _isLoading = true;

  Map<String, dynamic> _info = {};

  Map<String, dynamic> _episodesMap =
      {}; // Map of Season Number -> List of Episodes

  List<String> _seasons = [];

  String? _selectedSeason;

  String? _resumeEpisodeId;

  @override
  void initState() {
    super.initState();

    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final provider = context.read<ChannelProvider>();

    final service = IptvService();

    if (provider.savedUrl != null &&
        provider.savedUser != null &&
        provider.savedPass != null) {
      final data = await service.getSeriesInfo(
        widget.channel.id,

        provider.savedUrl!,

        provider.savedUser!,

        provider.savedPass!,
      );

      final lastEp = await PlaybackService().getLastEpisodeId(
        widget.channel.id,
      );

      if (mounted) {
        setState(() {
          _info = data['info'] ?? {};

          _resumeEpisodeId = lastEp;

          final episodesData = data['episodes'];

          if (episodesData is Map<String, dynamic>) {
            _episodesMap = episodesData;

            _seasons = _episodesMap.keys.toList();

            // Sort seasons numerically if possible

            _seasons.sort((a, b) {
              int? nA = int.tryParse(a);

              int? nB = int.tryParse(b);

              if (nA != null && nB != null) return nA.compareTo(nB);

              return a.compareTo(b);
            });

            if (_seasons.isNotEmpty) {
              _selectedSeason = _seasons.first;
            }
          } else if (episodesData is List) {
            // Sometimes API returns empty list [] if no episodes

            _episodesMap = {};

            _seasons = [];
          }

          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _findEpisodeById(String? id) {
    if (id == null) return null;

    for (var season in _episodesMap.values) {
      if (season is List) {
        for (var ep in season) {
          if (ep['id'].toString() == id) return ep as Map<String, dynamic>;
        }
      }
    }

    return null;
  }

  void _playEpisode(Map<String, dynamic> episode) {
    final provider = context.read<ChannelProvider>();

    final baseUrl = provider.savedUrl ?? '';

    final user = provider.savedUser ?? '';

    final pass = provider.savedPass ?? '';

    final ext = episode['container_extension'] ?? 'mp4';

    final id = episode['id'].toString();

    final url = '$baseUrl/series/$user/$pass/$id.$ext';

    final episodeChannel = Channel(
      id: id,

      name:
          '${widget.channel.name} - S${_selectedSeason}E${episode['episode_num'] ?? '?'}',

      streamUrl: url,

      logoUrl: episode['info']?['movie_image'] ?? widget.channel.logoUrl,

      category: widget.channel.category,

      type: 'series_episode',
    );

    // Calculate index in the current list

    int currentIndex = -1;

    List<dynamic> episodeList = [];

    if (_selectedSeason != null && _episodesMap.containsKey(_selectedSeason)) {
      episodeList = _episodesMap[_selectedSeason] as List<dynamic>;

      currentIndex = episodeList.indexWhere((e) => e['id'].toString() == id);
    }

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          channel: episodeChannel,

          episodes: episodeList,

          currentEpisodeIndex: currentIndex,

          currentSeason: _selectedSeason,

          seasons: _seasons,

          allEpisodesMap: _episodesMap,

          seriesId: widget.channel.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final infoData = _info;

    // Backdrop

    final backdropUrlList = infoData['backdrop_path'] as List<dynamic>?;

    String? backdropImage;

    if (backdropUrlList != null && backdropUrlList.isNotEmpty) {
      backdropImage = backdropUrlList[0].toString();
    } else if (infoData['backdrop_path'] is String) {
      backdropImage = infoData['backdrop_path'];
    }

    final bgImage = backdropImage ?? widget.channel.logoUrl;

    // Get episodes for selected season

    List<dynamic> currentEpisodes = [];

    if (_selectedSeason != null && _episodesMap.containsKey(_selectedSeason)) {
      currentEpisodes = _episodesMap[_selectedSeason] as List<dynamic>;
    }

    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        children: [
          // Background Image (Blurred)
          if (bgImage != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bgImage,

                fit: BoxFit.cover,

                errorWidget: (context, url, error) =>
                    Container(color: Colors.black),
              ),
            ),

          // Dark Overlay & Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),

              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),

          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    // Use Column instead of SingleScrollView for outer to secure Layout
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      // --- HEADER ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,

                          vertical: 16,
                        ),

                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,

                                color: Colors.white,

                                size: 28,
                              ),

                              onPressed: () => Navigator.pop(context),
                            ),

                            Expanded(
                              child: Text(
                                widget.channel.name,

                                textAlign: TextAlign.center,

                                style: const TextStyle(
                                  color: Colors.white,

                                  fontSize: 22,

                                  fontWeight: FontWeight.bold,
                                ),

                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,

                                color: Colors.white,

                                size: 28,
                              ),

                              color: Colors.grey[900],

                              onSelected: (value) {
                                if (value == 'home') {
                                  Navigator.popUntil(
                                    context,

                                    (route) => route.isFirst,
                                  );
                                } else if (value == 'exit') {
                                  Navigator.popUntil(
                                    context,

                                    (route) => route.isFirst,
                                  );
                                }
                              },

                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'home',

                                  child: Row(
                                    children: [
                                      Icon(Icons.home, color: Colors.white),

                                      SizedBox(width: 10),

                                      Text(
                                        'Home Screen',

                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),

                                const PopupMenuItem(
                                  value: 'exit',

                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.exit_to_app,

                                        color: Colors.white,
                                      ),

                                      SizedBox(width: 10),

                                      Text(
                                        'Sair',

                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- Scrollable Content ---
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              // Main Info Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  // Poster
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),

                                    child: CachedNetworkImage(
                                      imageUrl:
                                          infoData['cover'] ??
                                          widget.channel.logoUrl ??
                                          '',

                                      width: 160,

                                      fit: BoxFit.cover,

                                      placeholder: (context, url) => Container(
                                        width: 160,

                                        height: 240,

                                        color: Colors.grey[900],
                                      ),

                                      errorWidget: (context, url, error) =>
                                          Container(
                                            width: 160,

                                            height: 240,

                                            color: Colors.grey[900],

                                            child: const Icon(
                                              Icons.movie,

                                              size: 50,

                                              color: Colors.white54,
                                            ),
                                          ),
                                    ),
                                  ),

                                  const SizedBox(width: 20),

                                  // Details Column + Heart
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            _buildInfoRow(
                                              'Dirigido por:',

                                              infoData['director'],
                                            ),

                                            _buildInfoRow(
                                              'Data de lançam..',

                                              infoData['releaseDate'],
                                            ), // Sometimes releaseDate

                                            _buildInfoRow(
                                              'Gênero:',

                                              infoData['genre'],
                                            ),

                                            _buildInfoRow(
                                              'Elenco:',

                                              infoData['cast'],
                                            ),

                                            const SizedBox(height: 10),

                                            // Plot with Label (Aligned)
                                            if (infoData['plot'] != null &&
                                                infoData['plot']
                                                    .toString()
                                                    .isNotEmpty)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2.0,
                                                    ),

                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,

                                                  children: [
                                                    const SizedBox(
                                                      width: 120,

                                                      child: Text(
                                                        'Enredo:',

                                                        style: TextStyle(
                                                          color: Colors.white70,

                                                          fontSize: 14,

                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),

                                                    Expanded(
                                                      child: Text(
                                                        infoData['plot'],

                                                        maxLines: 4,

                                                        overflow: TextOverflow
                                                            .ellipsis,

                                                        style: const TextStyle(
                                                          color: Colors.grey,

                                                          fontSize: 13,

                                                          height: 1.2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            const SizedBox(height: 15),

                                            // Controls Row (Play S1E1 | Seasons Dropdown) - Compact
                                            Row(
                                              children: [
                                                // Resume Button
                                                if (_resumeEpisodeId !=
                                                    null) ...[
                                                  Builder(
                                                    builder: (context) {
                                                      final resumeEp =
                                                          _findEpisodeById(
                                                            _resumeEpisodeId,
                                                          );

                                                      if (resumeEp == null)
                                                        return const SizedBox.shrink();

                                                      // Optional: Check progress

                                                      final progress =
                                                          PlaybackService()
                                                              .getProgress(
                                                                _resumeEpisodeId!,
                                                              );

                                                      if (progress < 10)
                                                        return const SizedBox.shrink();

                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 10,
                                                            ),

                                                        child: ElevatedButton.icon(
                                                          onPressed: () =>
                                                              _playEpisode(
                                                                resumeEp,
                                                              ),

                                                          icon: const Icon(
                                                            Icons.history,

                                                            size: 16,
                                                          ),

                                                          label: Text(
                                                            'RETOMAR S${resumeEp['season'] ?? '?'}E${resumeEp['episode_num'] ?? '?'}',

                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,

                                                                  fontSize: 13,
                                                                ),
                                                          ),

                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFF00838F,
                                                                ),

                                                            foregroundColor:
                                                                Colors.white,

                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,

                                                                  vertical: 0,
                                                                ),

                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    5,
                                                                  ),
                                                            ),

                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .white24,
                                                                ),

                                                            minimumSize:
                                                                const Size(
                                                                  140,

                                                                  45,
                                                                ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],

                                                if (currentEpisodes.isNotEmpty)
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        _playEpisode(
                                                          currentEpisodes[0],
                                                        ),

                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.grey[900],

                                                      foregroundColor:
                                                          Colors.white,

                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,

                                                            vertical: 0,
                                                          ),

                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5,
                                                            ),
                                                      ),

                                                      side: const BorderSide(
                                                        color: Colors.white24,
                                                      ),

                                                      minimumSize: const Size(
                                                        140,

                                                        45,
                                                      ), // Fixed width, not expanded
                                                    ),

                                                    child: Text(
                                                      'Play - S$_selectedSeason:E1',

                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,

                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),

                                                const SizedBox(width: 10),

                                                // Season Dropdown
                                                if (_seasons.isNotEmpty)
                                                  Container(
                                                    height: 45,

                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),

                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[900],

                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            5,
                                                          ),

                                                      border: Border.all(
                                                        color: Colors.white24,
                                                      ),
                                                    ),

                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        dropdownColor:
                                                            Colors.grey[900],

                                                        value: _selectedSeason,

                                                        icon: const Icon(
                                                          Icons.arrow_drop_down,

                                                          color: Colors.white,
                                                        ),

                                                        style: const TextStyle(
                                                          color: Colors.white,

                                                          fontWeight:
                                                              FontWeight.bold,

                                                          fontSize: 13,
                                                        ),

                                                        items: _seasons.map((
                                                          s,
                                                        ) {
                                                          return DropdownMenuItem(
                                                            value: s,

                                                            child: Text(
                                                              'Temporada - $s',
                                                            ),
                                                          );
                                                        }).toList(),

                                                        onChanged: (val) {
                                                          if (val != null)
                                                            setState(
                                                              () =>
                                                                  _selectedSeason =
                                                                      val,
                                                            );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Favorite Heart
                                        Positioned(
                                          top: 0,

                                          right: 0,

                                          child: Consumer<ChannelProvider>(
                                            builder: (context, provider, child) {
                                              final isFav = provider.channels
                                                  .firstWhere(
                                                    (c) =>
                                                        c.id ==
                                                        widget.channel.id,

                                                    orElse: () =>
                                                        widget.channel,
                                                  )
                                                  .isFavorite;

                                              return IconButton(
                                                padding: EdgeInsets.zero,

                                                constraints:
                                                    const BoxConstraints(),

                                                icon: Icon(
                                                  isFav
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,

                                                  color: isFav
                                                      ? Colors.red
                                                      : Colors.white,

                                                  size: 30,
                                                ),

                                                onPressed: () =>
                                                    provider.toggleFavorite(
                                                      widget.channel,
                                                    ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Rating Stars (Main Series Rating)
                              Row(
                                children: List.generate(5, (index) {
                                  double rating = 0;

                                  if (infoData['rating'] != null) {
                                    // Try to parse rating depending on format (10-based or 5-based)

                                    double? val = double.tryParse(
                                      infoData['rating'].toString(),
                                    );

                                    if (val != null) {
                                      if (val > 5)
                                        rating = val / 2;
                                      else
                                        rating = val;
                                    }
                                  } else {
                                    rating = (widget.channel.rating ?? 0) / 2;
                                  }

                                  if (index < rating) {
                                    return const Icon(
                                      Icons.star,

                                      color: Colors.yellow,

                                      size: 20,
                                    );
                                  } else {
                                    return Icon(
                                      Icons.star,

                                      color: Colors.grey[800],

                                      size: 20,
                                    );
                                  }
                                }),
                              ),

                              const SizedBox(height: 20),

                              // Episodes Count Header
                              Container(
                                width: 140,

                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),

                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.purple,

                                      width: 3,
                                    ),
                                  ),
                                ),

                                child: Text(
                                  'EPISÓDIOS (${currentEpisodes.length})',

                                  style: const TextStyle(
                                    color: Colors.white,

                                    fontWeight: FontWeight.bold,

                                    fontSize: 16,
                                  ),
                                ),
                              ),

                              const Divider(color: Colors.grey),

                              // Episodes List
                              if (currentEpisodes.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20),

                                  child: Text(
                                    'Nenhum episódio encontrado.',

                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,

                                  physics: const NeverScrollableScrollPhysics(),

                                  itemCount: currentEpisodes.length,

                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 16),

                                  itemBuilder: (context, index) {
                                    final ep = currentEpisodes[index];

                                    final epImg =
                                        ep['info']?['movie_image']; // Check API structure carefully

                                    var epTitle = ep['title'].toString();

                                    var epPlot =
                                        ep['info']?['plot'] ?? ep['plot'] ?? '';

                                    double epRating = 0.0;

                                    if (ep['info']?['rating'] != null) {
                                      epRating =
                                          double.tryParse(
                                            ep['info']['rating'].toString(),
                                          ) ??
                                          0.0;
                                    } else if (ep['rating'] != null) {
                                      epRating =
                                          double.tryParse(
                                            ep['rating'].toString(),
                                          ) ??
                                          0.0;
                                    }

                                    // normalizing rating to 5 stars calc

                                    double starRating = (epRating > 5)
                                        ? epRating / 2
                                        : epRating;

                                    return InkWell(
                                      onTap: () => _playEpisode(ep),

                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,

                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),

                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            // Episode Thumb (with Play overlay)
                                            SizedBox(
                                              width: 120,

                                              height: 80,

                                              child: Stack(
                                                alignment: Alignment.center,

                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                8,
                                                              ),

                                                          bottomLeft:
                                                              Radius.circular(
                                                                8,
                                                              ),
                                                        ),

                                                    child: CachedNetworkImage(
                                                      imageUrl: epImg ?? '',

                                                      fit: BoxFit.cover,

                                                      width: double.infinity,

                                                      height: double.infinity,

                                                      placeholder: (_, __) =>
                                                          Container(
                                                            color: Colors
                                                                .grey[800],
                                                          ),

                                                      errorWidget:
                                                          (_, __, ___) =>
                                                              Container(
                                                                color: Colors
                                                                    .grey[800],
                                                              ),
                                                    ),
                                                  ),

                                                  Container(
                                                    color: Colors.black45,
                                                  ),

                                                  const Icon(
                                                    Icons.play_circle_outline,

                                                    color: Colors.white,

                                                    size: 30,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // Info
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,

                                                      horizontal: 8,
                                                    ),

                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,

                                                  children: [
                                                    Text(
                                                      epTitle,

                                                      style: const TextStyle(
                                                        color: Colors.white,

                                                        fontWeight:
                                                            FontWeight.bold,

                                                        fontSize: 13,
                                                      ),
                                                    ),

                                                    const SizedBox(height: 4),

                                                    // Rating Stars & Duration
                                                    Row(
                                                      children: [
                                                        if (epRating > 0) ...[
                                                          ...List.generate(5, (
                                                            starIndex,
                                                          ) {
                                                            if (starIndex <
                                                                starRating) {
                                                              return const Icon(
                                                                Icons.star,

                                                                color: Colors
                                                                    .yellow,

                                                                size: 12,
                                                              );
                                                            } else {
                                                              return Icon(
                                                                Icons.star,

                                                                color: Colors
                                                                    .grey[600],

                                                                size: 12,
                                                              );
                                                            }
                                                          }),

                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                        ],

                                                        if (ep['info']?['duration'] !=
                                                            null)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 4,

                                                                  vertical: 2,
                                                                ),

                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .grey[800],

                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        2,
                                                                      ),
                                                                ),

                                                            child: Text(
                                                              ep['info']['duration']
                                                                  .toString(),

                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,

                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),

                                                    const SizedBox(height: 6),

                                                    if (epPlot.isNotEmpty)
                                                      Text(
                                                        epPlot,

                                                        maxLines: 2,

                                                        overflow: TextOverflow
                                                            .ellipsis,

                                                        style: const TextStyle(
                                                          color: Colors.grey,

                                                          fontSize: 11,
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

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty || value.toString() == 'null')
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 120,

            child: Text(
              label,

              style: const TextStyle(
                color: Colors.white70,

                fontSize: 14,

                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value.toString(),

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),

          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
