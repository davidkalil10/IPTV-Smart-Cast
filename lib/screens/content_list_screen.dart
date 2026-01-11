import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';
import '../models/channel.dart';
import '../widgets/channel_grid_item.dart';
import '../services/playback_service.dart';
import '../services/iptv_service.dart';
import 'player_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

enum SortOption { defaultSort, topAdded, az, za }

enum ContentType { live, movie, series }

class ContentListScreen extends StatefulWidget {
  final ContentType type;
  final String title;
  final bool forceRefresh;

  const ContentListScreen({
    super.key,
    required this.type,
    required this.title,
    this.forceRefresh = false,
  });

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  String _selectedCategory = 'TODOS';
  String _categorySearchQuery = '';
  String _contentSearchQuery = '';
  bool _isContentSearchVisible = false;
  SortOption _currentSort = SortOption.defaultSort;

  final TextEditingController _categorySearchController =
      TextEditingController();
  final TextEditingController _contentSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });
  }

  Set<String> _resumeIds = {};

  @override
  void dispose() {
    _categorySearchController.dispose();
    _contentSearchController.dispose();
    super.dispose();
  }

  void _loadContent() {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ChannelProvider>();
    final user = auth.currentUser;

    if (user != null) {
      if (widget.type == ContentType.live) {
        provider.loadXtream(
          user.url,
          user.username,
          user.password,
          forceRefresh: widget.forceRefresh,
        );
      } else if (widget.type == ContentType.movie) {
        provider.loadVod(
          user.url,
          user.username,
          user.password,
          forceRefresh: widget.forceRefresh,
        );
      } else if (widget.type == ContentType.series) {
        provider.loadSeries(
          user.url,
          user.username,
          user.password,
          forceRefresh: widget.forceRefresh,
        );
      }

      // Load Playback Service
      PlaybackService().init().then((_) {
        if (mounted) {
          setState(() {
            _resumeIds = PlaybackService().getInProgressContentIds().toSet();
          });
        }
      });
    }
  }

  List<String> _getCategories(List<Channel> channels) {
    if (channels.isEmpty) return ['TODOS', 'FAVORITOS'];
    final categories = channels.map((c) => c.category).toSet().toList();
    categories.sort((a, b) => a.compareTo(b));

    // Check if we have items to resume
    final hasResumeItems = channels.any((c) => _resumeIds.contains(c.id));

    return ['TODOS', 'FAVORITOS', if (hasResumeItems) 'RETOMAR', ...categories];
  }

  List<Channel> _getFilteredChannels(List<Channel> channels) {
    // 1. Filter
    var filtered = channels.where((channel) {
      bool matchesCategory = false;
      if (_selectedCategory == 'TODOS') {
        matchesCategory = true;
      } else if (_selectedCategory == 'FAVORITOS') {
        matchesCategory = channel.isFavorite;
      } else if (_selectedCategory == 'RETOMAR') {
        matchesCategory = _resumeIds.contains(channel.id);
      } else {
        matchesCategory = channel.category == _selectedCategory;
      }

      final matchesSearch =
          _contentSearchQuery.isEmpty ||
          channel.name.toLowerCase().contains(
            _contentSearchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();

    // 2. Sort
    switch (_currentSort) {
      case SortOption.az:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.za:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.topAdded:
        filtered = filtered.reversed.toList();
        break;
      case SortOption.defaultSort:
      default:
        break;
    }

    return filtered;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        SortOption tempSort = _currentSort;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.sort, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    'Ordenar de acordo com :',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRadioTile(
                    'Padrão',
                    SortOption.defaultSort,
                    tempSort,
                    setState,
                  ),
                  _buildRadioTile(
                    'Top Adicionado',
                    SortOption.topAdded,
                    tempSort,
                    setState,
                  ),
                  _buildRadioTile('A-Z', SortOption.az, tempSort, setState),
                  _buildRadioTile('Z-A', SortOption.za, tempSort, setState),
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'FECHAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      _currentSort = tempSort;
                    });
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'SALVAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRadioTile(
    String title,
    SortOption value,
    SortOption groupValue,
    StateSetter setState,
  ) {
    return RadioListTile<SortOption>(
      title: Text(
        title,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
      activeColor: Colors.blue,
      value: value,
      groupValue: groupValue,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) => setState(() => groupValue = val!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<ChannelProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final allCategories = _getCategories(provider.channels);

            final filteredCategories = allCategories.where((cat) {
              return _categorySearchQuery.isEmpty ||
                  cat.toLowerCase().contains(
                    _categorySearchQuery.toLowerCase(),
                  );
            }).toList();

            final displayedContent = _getFilteredChannels(provider.channels);

            return LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                // If screen is "small" (like mobile landscape), reduce sidebar width
                final bool isMobile = totalWidth < 900;
                final double sidebarWidth = isMobile ? 250.0 : 300.0;

                return Row(
                  children: [
                    // Left Sidebar (Categories)
                    Container(
                      width: sidebarWidth,
                      color: const Color(0xFF101010),
                      child: Column(
                        children: [
                          // Header Left
                          Container(
                            height: 60,
                            color: const Color(0xFF101010),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.title.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: TextField(
                              controller: _categorySearchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Pesquisa...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 40,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                filled: true,
                                fillColor: Colors.grey[850],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => _categorySearchQuery = value),
                            ),
                          ),

                          Expanded(
                            child: ListView.separated(
                              itemCount: filteredCategories.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: Colors.grey[800]),
                              itemBuilder: (context, index) {
                                final category = filteredCategories[index];
                                final isSelected =
                                    category == _selectedCategory;

                                int count = 0;
                                if (category == 'FAVORITOS') {
                                  count = provider.channels
                                      .where((c) => c.isFavorite)
                                      .length;
                                } else if (category == 'TODOS') {
                                  count = provider.channels.length;
                                } else if (category == 'RETOMAR') {
                                  count = provider.channels
                                      .where((c) => _resumeIds.contains(c.id))
                                      .length;
                                } else {
                                  count = provider.channels
                                      .where((c) => c.category == category)
                                      .length;
                                }

                                return Container(
                                  color: isSelected
                                      ? const Color(0xFF00838F)
                                      : Colors
                                            .transparent, // Cyan 800 for selection
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                    title: Text(
                                      category,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[300],
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    trailing: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onTap: () => setState(
                                      () => _selectedCategory = category,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Content (Grid)
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Column(
                          children: [
                            // Header Right
                            Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[800]!),
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Centered Title
                                  if (!_isContentSearchVisible)
                                    Center(
                                      child: Text(
                                        _selectedCategory.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                  // Right Actions
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_isContentSearchVisible)
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                _contentSearchController,
                                            autofocus: true,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Procurar ${_selectedCategory}...',
                                              hintStyle: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                              border: InputBorder.none,
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            onChanged: (value) => setState(
                                              () => _contentSearchQuery = value,
                                            ),
                                          ),
                                        ),

                                      if (!_isContentSearchVisible)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.search,
                                            size: 28,
                                            color: Colors.white,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _isContentSearchVisible = true,
                                          ),
                                        ),

                                      if (_isContentSearchVisible)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _contentSearchQuery = '';
                                              _contentSearchController.clear();
                                              _isContentSearchVisible = false;
                                            });
                                          },
                                        ),

                                      const SizedBox(width: 8),

                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                        color: Colors.grey[900],
                                        onSelected: (value) {
                                          if (value == 'refresh') {
                                            // Force refresh when manually clicking refresh in the list
                                            final auth = context
                                                .read<AuthProvider>();
                                            final provider = context
                                                .read<ChannelProvider>();
                                            final user = auth.currentUser;

                                            if (user != null) {
                                              if (widget.type ==
                                                  ContentType.live) {
                                                provider.loadXtream(
                                                  user.url,
                                                  user.username,
                                                  user.password,
                                                  forceRefresh: true,
                                                );
                                              } else if (widget.type ==
                                                  ContentType.movie) {
                                                provider.loadVod(
                                                  user.url,
                                                  user.username,
                                                  user.password,
                                                  forceRefresh: true,
                                                );
                                              } else if (widget.type ==
                                                  ContentType.series) {
                                                provider.loadSeries(
                                                  user.url,
                                                  user.username,
                                                  user.password,
                                                  forceRefresh: true,
                                                );
                                              }
                                            }
                                          } else if (value == 'sort') {
                                            _showSortDialog();
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'sort',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.sort,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Ordenar',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'refresh',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.refresh,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Atualizar Lista',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Grid
                            Expanded(
                              child: displayedContent.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Nenhum conteúdo',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Force 5 columns even on mobile as requested
                                        // The user says "3 instead of 5" on mobile, meaning they want 5.
                                        int crossAxisCount = 5;

                                        return GridView.builder(
                                          padding: const EdgeInsets.all(8),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                childAspectRatio:
                                                    0.70, // Slightly taller aspect ratio since width is tighter
                                                crossAxisSpacing: 8,
                                                mainAxisSpacing: 8,
                                              ),
                                          itemCount: displayedContent.length,
                                          itemBuilder: (context, index) {
                                            return ChannelGridItem(
                                              channel: displayedContent[index],
                                              onTap: () async {
                                                final channel =
                                                    displayedContent[index];
                                                final provider = context
                                                    .read<ChannelProvider>();

                                                if (_selectedCategory ==
                                                    'RETOMAR') {
                                                  // --- RESUME LOGIC ---
                                                  if (channel.type ==
                                                      'series') {
                                                    // SERIES RESUME
                                                    final lastEpId =
                                                        PlaybackService()
                                                            .getLastEpisodeId(
                                                              channel.id,
                                                            );
                                                    if (lastEpId != null) {
                                                      showDialog(
                                                        context: context,
                                                        barrierDismissible:
                                                            false,
                                                        builder: (_) =>
                                                            const Center(
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            ),
                                                      );
                                                      try {
                                                        final service =
                                                            IptvService();
                                                        final data = await service
                                                            .getSeriesInfo(
                                                              channel.id,
                                                              provider
                                                                  .savedUrl!,
                                                              provider
                                                                  .savedUser!,
                                                              provider
                                                                  .savedPass!,
                                                            );

                                                        if (mounted)
                                                          Navigator.pop(
                                                            context,
                                                          );

                                                        // Find Episode
                                                        Map<String, dynamic>?
                                                        episode;
                                                        List<dynamic>
                                                        episodeList = [];
                                                        String? season;
                                                        List<String> seasons =
                                                            [];
                                                        Map<String, dynamic>
                                                        episodesMap = {};

                                                        final episodesData =
                                                            data['episodes'];
                                                        if (episodesData
                                                            is Map<
                                                              String,
                                                              dynamic
                                                            >) {
                                                          episodesMap =
                                                              episodesData;
                                                          seasons = episodesMap
                                                              .keys
                                                              .toList();
                                                          // Simple Sort
                                                          seasons.sort(
                                                            (a, b) =>
                                                                (int.tryParse(
                                                                          a,
                                                                        ) ??
                                                                        0)
                                                                    .compareTo(
                                                                      int.tryParse(
                                                                            b,
                                                                          ) ??
                                                                          0,
                                                                    ),
                                                          );

                                                          for (var k
                                                              in seasons) {
                                                            final list =
                                                                episodesMap[k]
                                                                    as List;
                                                            final found = list
                                                                .firstWhere(
                                                                  (e) =>
                                                                      e['id']
                                                                          .toString() ==
                                                                      lastEpId,
                                                                  orElse: () =>
                                                                      null,
                                                                );
                                                            if (found != null) {
                                                              episode = found;
                                                              season = k;
                                                              episodeList =
                                                                  list;
                                                              break;
                                                            }
                                                          }
                                                        }

                                                        if (episode != null &&
                                                            mounted) {
                                                          final ext =
                                                              episode['container_extension'] ??
                                                              'mp4';
                                                          final url =
                                                              '${provider.savedUrl}/series/${provider.savedUser}/${provider.savedPass}/$lastEpId.$ext';
                                                          final epName =
                                                              'S${season}E${episode['episode_num']}';

                                                          final epChannel = Channel(
                                                            id: lastEpId,
                                                            name:
                                                                '${channel.name} - $epName',
                                                            streamUrl: url,
                                                            logoUrl:
                                                                episode['info']?['movie_image'] ??
                                                                channel.logoUrl,
                                                            category: channel
                                                                .category,
                                                            type:
                                                                'series_episode',
                                                          );

                                                          final progress =
                                                              PlaybackService()
                                                                  .getProgress(
                                                                    lastEpId,
                                                                  );

                                                          await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) => PlayerScreen(
                                                                channel:
                                                                    epChannel,
                                                                startPosition:
                                                                    Duration(
                                                                      seconds:
                                                                          progress,
                                                                    ),
                                                                seriesId:
                                                                    channel.id,
                                                                episodes:
                                                                    episodeList,
                                                                currentEpisodeIndex:
                                                                    episodeList
                                                                        .indexOf(
                                                                          episode,
                                                                        ),
                                                                currentSeason:
                                                                    season,
                                                                seasons:
                                                                    seasons,
                                                                allEpisodesMap:
                                                                    episodesMap,
                                                              ),
                                                            ),
                                                          );
                                                        } else if (mounted) {
                                                          // Fallback if episode not found
                                                          await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  SeriesDetailScreen(
                                                                    channel:
                                                                        channel,
                                                                  ),
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          Navigator.pop(
                                                            context,
                                                          ); // Close dialog if error
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                "Erro ao carregar série: $e",
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    } else {
                                                      // No history? Detail
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SeriesDetailScreen(
                                                                channel:
                                                                    channel,
                                                              ),
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    // MOVIE / LIVE RESUME
                                                    final progress =
                                                        PlaybackService()
                                                            .getProgress(
                                                              channel.id,
                                                            );
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            PlayerScreen(
                                                              channel: channel,
                                                              startPosition:
                                                                  Duration(
                                                                    seconds:
                                                                        progress,
                                                                  ),
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  // --- STANDARD NAVIGATION ---
                                                  if (channel.type == 'movie') {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            MovieDetailScreen(
                                                              channel: channel,
                                                            ),
                                                      ),
                                                    );
                                                  } else if (channel.type ==
                                                      'series') {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            SeriesDetailScreen(
                                                              channel: channel,
                                                            ),
                                                      ),
                                                    );
                                                  } else {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            PlayerScreen(
                                                              channel: channel,
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                }

                                                // --- REFRESH ON RETURN ---
                                                if (mounted) {
                                                  setState(() {
                                                    _resumeIds = PlaybackService()
                                                        .getInProgressContentIds()
                                                        .toSet();
                                                  });
                                                }
                                              },
                                              onLongPress:
                                                  (_selectedCategory ==
                                                      'RETOMAR')
                                                  ? () async {
                                                      final channel =
                                                          displayedContent[index];
                                                      await PlaybackService()
                                                          .removeProgress(
                                                            channel.id,
                                                            seriesId:
                                                                channel.type ==
                                                                    'series'
                                                                ? channel.id
                                                                : null,
                                                          );
                                                      if (mounted) {
                                                        setState(() {
                                                          _resumeIds =
                                                              PlaybackService()
                                                                  .getInProgressContentIds()
                                                                  .toSet();
                                                        });
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              "${channel.name} removido de Retomar",
                                                            ),
                                                            duration:
                                                                const Duration(
                                                                  seconds: 1,
                                                                ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  : null,
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
