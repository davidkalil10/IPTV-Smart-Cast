import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_android_tv_text_field/native_textfield_tv.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';
import '../models/channel.dart';
import '../widgets/channel_grid_item.dart';
import '../widgets/category_list_item.dart';
import '../widgets/focusable_action_wrapper.dart';
import '../services/playback_service.dart';
import '../services/iptv_service.dart';
import 'player_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  bool _isAndroidTV = false;

  late NativeTextFieldController _categorySearchController;
  late NativeTextFieldController _contentSearchController;

  late FocusNode _categorySearchFocus;

  late FocusNode _contentSearchFocus;
  late FocusNode _firstCategoryFocus;
  late FocusNode _firstContentFocus; // Focus for the channel list

  // Preview Player State
  late final Player _previewPlayer;
  late final VideoController _previewController;
  Channel? _previewChannel;

  @override
  void initState() {
    super.initState();
    _firstContentFocus = FocusNode();

    // Initialize Preview Player
    _previewPlayer = Player();
    _previewController = VideoController(_previewPlayer);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });

    _checkDeviceType();

    _categorySearchController = NativeTextFieldController();
    _contentSearchController = NativeTextFieldController();
    _firstCategoryFocus = FocusNode();

    // Initialize FocusNodes with Key Events for D-Pad Navigation
    _categorySearchFocus = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(() {
        // Sync text if needed, mostly for Native field if it behaves oddly
      });
    _contentSearchFocus = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(() {});

    _categorySearchController.addListener(() {
      setState(() {
        _categorySearchQuery = _categorySearchController.text;
      });
    });

    _contentSearchController.addListener(() {
      setState(() {
        _contentSearchQuery = _contentSearchController.text;
      });
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;
      }

      // ENTER/Select -> Close Keyboard (User Request)
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        return KeyEventResult.handled;
      }

      // BACK/Escape -> Exit Editing manually
      if (event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        node.unfocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Set<String> _resumeIds = {};

  @override
  void dispose() {
    _categorySearchController.dispose();
    _contentSearchController.dispose();
    _categorySearchFocus.dispose();
    _contentSearchFocus.dispose();
    _firstCategoryFocus.dispose();
    _firstContentFocus.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ChannelProvider>();
    final user = auth.currentUser;

    if (user != null) {
      if (widget.type == ContentType.live) {
        await provider.loadXtream(
          user.url,
          user.username,
          user.password,
          forceRefresh: widget.forceRefresh,
        );
      } else if (widget.type == ContentType.movie) {
        await provider.loadVod(
          user.url,
          user.username,
          user.password,
          forceRefresh: widget.forceRefresh,
        );
      } else if (widget.type == ContentType.series) {
        await provider.loadSeries(
          user.url,
          user.username,
          user.password,
          forceRefresh: widget.forceRefresh,
        );
      }

      /*  // Print Category Analysis Table (One Block for Excel)
      Map<String, String> selectedMap = {};
      if (widget.type == ContentType.live) {
        selectedMap = provider.liveCategoryMap;
      } else if (widget.type == ContentType.movie) {
        selectedMap = provider.movieCategoryMap;
      } else if (widget.type == ContentType.series) {
        selectedMap = provider.seriesCategoryMap;
      }

      final buffer = StringBuffer();
      buffer.writeln(
        '\n--- CATEGORY ANALYSIS TABLE (${widget.type.toString()}) ---',
      );
      buffer.writeln('ID\t|\tNAME');
      buffer.writeln('----------------------------------------');

      final sortedEntries = selectedMap.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (var entry in sortedEntries) {
        buffer.writeln('${entry.key}\t|\t${entry.value}');
      }
      buffer.writeln('----------------------------------------\n');

      // Print as one large string
      debugPrint(buffer.toString()); */

      // Load Playback Service
      PlaybackService().init().then((_) {
        if (mounted) {
          setState(() {
            _resumeIds = PlaybackService().getInProgressContentIds().toSet();
          });
        }
      });

      // Request Focus on First Category after load
      _requestInitialFocus();
    }
  }

  void _requestInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstCategoryFocus.requestFocus();
      }
    });
  }

  Future<void> _checkDeviceType() async {
    if (kIsWeb || !Platform.isAndroid) {
      setState(() => _isAndroidTV = false);
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // Check for Leanback feature (TV)
      final isTV = androidInfo.systemFeatures.contains(
        'android.software.leanback',
      );
      if (mounted) {
        setState(() => _isAndroidTV = isTV);
      }
    } catch (e) {
      debugPrint('Error checking device type: $e');
    }
  }

  List<String> _getCategories(List<Channel> channels) {
    if (channels.isEmpty) return ['TODOS', 'FAVORITOS'];

    // Get unique category names present in the current channel list
    final presentCategories = channels.map((c) => c.category).toSet();

    // Get the Ordered List from Provider (Server Order)
    final provider = context.read<ChannelProvider>();
    Map<String, String> sourceMap = {};
    if (widget.type == ContentType.live) {
      sourceMap = provider.liveCategoryMap;
    } else if (widget.type == ContentType.movie) {
      sourceMap = provider.movieCategoryMap;
    } else if (widget.type == ContentType.series) {
      sourceMap = provider.seriesCategoryMap;
    }

    // Filter the ordered values by what is actually present
    final orderedCategories = sourceMap.values
        .where((name) => presentCategories.contains(name))
        .toList();

    // If there are categories in 'channels' not in the map (fallback), add them at the end
    final unmapped = presentCategories
        .where((name) => !orderedCategories.contains(name))
        .toList();
    // Sort unmapped alphabetically just to be tidy
    unmapped.sort();

    // Check if we have items to resume
    final hasResumeItems = channels.any((c) => _resumeIds.contains(c.id));

    return [
      'TODOS',
      'FAVORITOS',
      if (hasResumeItems) 'RETOMAR',
      ...orderedCategories,
      ...unmapped,
    ];
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
              scrollable: true,
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
                // --- CHECK DISPLAY MODE ---
                final bool isSmallScreen = constraints.maxWidth < 900;
                final double sidebarWidth = isSmallScreen ? 250.0 : 300.0;

                bool useStandardTextField = true;
                if (_isAndroidTV) {
                  useStandardTextField = false;
                }

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
                                FocusableActionWrapper(
                                  showFocusHighlight: _isAndroidTV,
                                  onTap: () => Navigator.pop(context),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                    ),
                                  ),
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
                            child: _buildResponsiveSearchField(
                              controller: _categorySearchController,
                              focusNode: _categorySearchFocus,
                              hintText: 'Pesquisa...',
                              isStandard: useStandardTextField,
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

                                return CategoryListItem(
                                  showFocusHighlight: _isAndroidTV,
                                  focusNode: index == 0
                                      ? _firstCategoryFocus
                                      : null,
                                  title: category,
                                  count: '$count',
                                  isSelected: isSelected,
                                  onTap: () => setState(
                                    () => _selectedCategory = category,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Content (Grid)
                    // Right Content
                    Expanded(
                      child: widget.type == ContentType.live
                          ? _buildLiveLayout(displayedContent)
                          : _buildGridLayout(displayedContent),
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

  Future<void> _handleChannelTap(Channel channel) async {
    final provider = context.read<ChannelProvider>();

    if (_selectedCategory == 'RETOMAR') {
      // --- RESUME LOGIC ---
      if (channel.type == 'series') {
        // SERIES RESUME
        final lastEpId = PlaybackService().getLastEpisodeId(channel.id);
        if (lastEpId != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          try {
            final service = IptvService();
            final data = await service.getSeriesInfo(
              channel.id,
              provider.savedUrl!,
              provider.savedUser!,
              provider.savedPass!,
            );

            if (mounted) Navigator.pop(context);

            // Find Episode
            Map<String, dynamic>? episode;
            List<dynamic> episodeList = [];
            String? season;
            List<String> seasons = [];
            Map<String, dynamic> episodesMap = {};

            final episodesData = data['episodes'];
            if (episodesData is Map<String, dynamic>) {
              episodesMap = episodesData;
              seasons = episodesMap.keys.toList();
              // Simple Sort
              seasons.sort(
                (a, b) =>
                    (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
              );

              for (var k in seasons) {
                final list = episodesMap[k] as List;
                final found = list.firstWhere(
                  (e) => e['id'].toString() == lastEpId,
                  orElse: () => null,
                );
                if (found != null) {
                  episode = found;
                  season = k;
                  episodeList = list;
                  break;
                }
              }
            }

            if (episode != null && mounted) {
              final ext = episode['container_extension'] ?? 'mp4';
              final url =
                  '${provider.savedUrl}/series/${provider.savedUser}/${provider.savedPass}/$lastEpId.$ext';
              final epName = 'S${season}E${episode['episode_num']}';

              final epChannel = Channel(
                id: lastEpId,
                name: '${channel.name} - $epName',
                streamUrl: url,
                logoUrl: episode['info']?['movie_image'] ?? channel.logoUrl,
                category: channel.category,
                type: 'series_episode',
              );

              final progress = PlaybackService().getProgress(lastEpId);

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    channel: epChannel,
                    startPosition: Duration(seconds: progress),
                    seriesId: channel.id,
                    episodes: episodeList,
                    currentEpisodeIndex: episodeList.indexOf(episode),
                    currentSeason: season,
                    seasons: seasons,
                    allEpisodesMap: episodesMap,
                  ),
                ),
              );
            } else if (mounted) {
              // Fallback if episode not found
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeriesDetailScreen(channel: channel),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Close dialog if error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Erro ao carregar série: $e")),
              );
            }
          }
        } else {
          // No history? Detail
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SeriesDetailScreen(channel: channel),
            ),
          );
        }
      } else {
        // MOVIE / LIVE RESUME
        final progress = PlaybackService().getProgress(channel.id);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              channel: channel,
              startPosition: Duration(seconds: progress),
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
            builder: (context) => MovieDetailScreen(channel: channel),
          ),
        );
      } else if (channel.type == 'series') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SeriesDetailScreen(channel: channel),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(channel: channel),
          ),
        );
      }
    }

    // --- REFRESH ON RETURN ---
    if (mounted) {
      setState(() {
        _resumeIds = PlaybackService().getInProgressContentIds().toSet();
      });
    }
  }

  Widget _buildGridLayout(List<Channel> displayedContent) {
    bool useStandardTextField = !_isAndroidTV;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildHeader(useStandardTextField),
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
                      int crossAxisCount = 5;
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: displayedContent.length,
                        itemBuilder: (context, index) {
                          return ChannelGridItem(
                            channel: displayedContent[index],
                            onTap: () =>
                                _handleChannelTap(displayedContent[index]),
                            onLongPress: (_selectedCategory == 'RETOMAR')
                                ? () async {
                                    final channel = displayedContent[index];
                                    await PlaybackService().removeProgress(
                                      channel.id,
                                      seriesId: channel.type == 'series'
                                          ? channel.id
                                          : null,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _resumeIds = PlaybackService()
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
                                          duration: const Duration(seconds: 1),
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
    );
  }

  Widget _buildLiveLayout(List<Channel> displayedContent) {
    bool useStandardTextField = !_isAndroidTV;

    return Row(
      children: [
        // Column 2: Channel List
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFF151515),
            child: Column(
              children: [
                _buildHeader(useStandardTextField),
                Expanded(
                  child: displayedContent.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum canal',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: displayedContent.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final channel = displayedContent[index];
                            final isPreviewing =
                                _previewChannel?.id == channel.id;

                            return FocusableActionWrapper(
                              showFocusHighlight: true,
                              focusNode: index == 0 ? _firstContentFocus : null,
                              onTap: () {
                                if (isPreviewing) {
                                  _handleChannelTap(channel);
                                } else {
                                  setState(() {
                                    _previewChannel = channel;
                                    _previewPlayer.open(
                                      Media(channel.streamUrl),
                                    );
                                  });
                                }
                              },
                              child: Container(
                                color: isPreviewing
                                    ? Colors.blue.withOpacity(0.2)
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: (channel.logoUrl != null && channel.logoUrl!.isNotEmpty)
                                            ? Image.network(
                                                channel.logoUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.tv, color: Colors.grey),
                                              )
                                            : const Icon(Icons.tv, color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        channel.name,
                                        style: TextStyle(
                                          color: isPreviewing
                                              ? Colors.blue
                                              : Colors.white,
                                          fontWeight: isPreviewing
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isPreviewing)
                                      const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.blue,
                                        size: 20,
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
          ),
        ),
        // Column 3: Preview Area
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Video Preview
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _previewChannel == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tv, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                "Selecione um canal para visualizar",
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : Video(controller: _previewController),
                ),
              ),
              // EPG Placeholder
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0A0A0A),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_previewChannel != null) ...[
                        Text(
                          _previewChannel!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Categoria: ${_previewChannel!.category}",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Guia de Programação (EPG)",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Informações detalhadas do programa atual não estão disponíveis no momento.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool useStandardTextField) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
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
                  child: _buildResponsiveSearchField(
                    controller: _contentSearchController,
                    focusNode: _contentSearchFocus,
                    hintText: 'Procurar ${_selectedCategory}...',
                    isStandard: useStandardTextField,
                    autofocus: true,
                    onChanged: (value) =>
                        setState(() => _contentSearchQuery = value),
                  ),
                ),
              if (!_isContentSearchVisible)
                FocusableActionWrapper(
                  showFocusHighlight: _isAndroidTV,
                  onTap: () {
                    setState(() => _isContentSearchVisible = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _contentSearchFocus.requestFocus();
                      SystemChannels.textInput.invokeMethod('TextInput.show');
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.search, size: 28, color: Colors.white),
                  ),
                ),
              if (_isContentSearchVisible)
                FocusableActionWrapper(
                  showFocusHighlight: _isAndroidTV,
                  onTap: () {
                    setState(() {
                      _contentSearchQuery = '';
                      _contentSearchController.clear();
                      _isContentSearchVisible = false;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                ),
              const SizedBox(width: 8),
              FocusableActionWrapper(
                showFocusHighlight: _isAndroidTV,
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 28,
                    color: Colors.white,
                  ),
                  color: Colors.grey[900],
                  onSelected: (value) {
                    if (value == 'refresh') {
                      final auth = context.read<AuthProvider>();
                      final provider = context.read<ChannelProvider>();
                      final user = auth.currentUser;
                      if (user != null) {
                        if (widget.type == ContentType.live) {
                          provider.loadXtream(
                            user.url,
                            user.username,
                            user.password,
                            forceRefresh: true,
                          );
                        } else if (widget.type == ContentType.movie) {
                          provider.loadVod(
                            user.url,
                            user.username,
                            user.password,
                            forceRefresh: true,
                          );
                        } else if (widget.type == ContentType.series) {
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
                          Icon(Icons.sort, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Ordenar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Atualizar Lista',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveSearchField({
    required NativeTextFieldController controller,
    required FocusNode focusNode,
    required String hintText,
    required bool isStandard,
    required Function(String) onChanged,
    bool autofocus = false,
  }) {
    if (isStandard) {
      // Standard TextField (Mobile/Web)
      return TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: _isAndroidTV
                ? const BorderSide(color: Colors.tealAccent, width: 2)
                : BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      );
    } else {
      // Android TV Native Field
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(4),
        ),
        child: AndroidTVTextField(
          controller: controller,
          focusNode: focusNode,
          hint: hintText,
          textColor: Colors.white,
          backgroundColor: Colors.transparent,
          focuesedBorderColor: Colors.tealAccent,
          onSubmitted: (_) {
            FocusScope.of(context).unfocus();
            FocusScope.of(context).nextFocus();
          },
        ),
      );
    }
  }
}
