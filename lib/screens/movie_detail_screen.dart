import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../widgets/focusable_action_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../models/channel.dart';
import '../providers/channel_provider.dart';
import '../services/iptv_service.dart';
import '../services/playback_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Channel channel;

  const MovieDetailScreen({super.key, required this.channel});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isLoading = true;
  bool _isAndroidTV = false;
  Map<String, dynamic> _info = {};

  // Focus Nodes
  final FocusNode _playFocus = FocusNode();
  final FocusNode _resumeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _playFocus.addListener(_onFocusChange);
    _resumeFocus.addListener(_onFocusChange);
    _checkDeviceType();
    _fetchDetails();
  }

  @override
  void dispose() {
    _playFocus.dispose();
    _resumeFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  Future<void> _checkDeviceType() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final hasLeanback = androidInfo.systemFeatures.contains(
      'android.software.leanback',
    );

    if (mounted) {
      setState(() {
        _isAndroidTV = hasLeanback;
      });
    }
  }

  Future<void> _fetchDetails() async {
    final provider = context.read<ChannelProvider>();
    final service = IptvService();

    if (provider.savedUrl != null &&
        provider.savedUser != null &&
        provider.savedPass != null) {
      final info = await service.getVodInfo(
        widget.channel.id,
        provider.savedUrl!,
        provider.savedUser!,
        provider.savedPass!,
      );

      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoData = _info['info'] ?? {};
    final backdropUrl = infoData['backdrop_path'] as List<dynamic>?;

    String? backdropImage;
    if (backdropUrl != null && backdropUrl.isNotEmpty && backdropUrl is List) {
      if (backdropUrl.isNotEmpty) backdropImage = backdropUrl[0].toString();
    } else if (infoData['backdrop_path'] is String) {
      backdropImage = infoData['backdrop_path'];
    }

    final bgImage = backdropImage ?? widget.channel.logoUrl;

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
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Back Button & Title & Menu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FocusableActionWrapper(
                              showFocusHighlight: _isAndroidTV,
                              onTap: () {
                                Navigator.maybePop(context);
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
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
                            FocusableActionWrapper(
                              showFocusHighlight: _isAndroidTV,
                              child: PopupMenuButton<String>(
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
                                    // In a real app we might invoke SystemNavigator.pop()
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
                            ),
                          ],
                        ),

                        const SizedBox(height: 10), // Reduced spacing
                        // Main Section: Poster + Info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Poster
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl:
                                    infoData['movie_image'] ??
                                    widget.channel.logoUrl ??
                                    '',
                                width: 180, // Slightly smaller
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 180,
                                  height: 270,
                                  color: Colors.grey[900],
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 180,
                                  height: 270,
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

                            // Details Column + Heart Stack
                            Expanded(
                              child: SizedBox(
                                height:
                                    270, // Match poster height to ensure layout
                                child: Stack(
                                  children: [
                                    // Metadata
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
                                          infoData['releasedate'],
                                        ),
                                        _buildInfoRow(
                                          'Duração:',
                                          infoData['duration'],
                                        ),
                                        _buildInfoRow(
                                          'Gênero:',
                                          infoData['genre'],
                                        ),
                                        _buildInfoRow(
                                          'Elenco:',
                                          infoData['cast'],
                                        ),

                                        const Spacer(),

                                        // Buttons Row
                                        FutureBuilder<int>(
                                          future: Future.value(
                                            PlaybackService().getProgress(
                                              widget.channel.id,
                                            ),
                                          ),
                                          builder: (context, snapshot) {
                                            final progress = snapshot.data ?? 0;
                                            final hasProgress = progress > 5;

                                            return Row(
                                              children: [
                                                // Always "Assistir" (Start from 0)
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    focusNode: _playFocus,
                                                    onPressed: () async {
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              PlayerScreen(
                                                                channel: widget
                                                                    .channel,
                                                                startPosition:
                                                                    null, // Start from 0
                                                              ),
                                                        ),
                                                      );
                                                      setState(() {});
                                                    },
                                                    icon: const Icon(
                                                      Icons.play_arrow,
                                                    ),
                                                    label: const Text(
                                                      'ASSISTIR',
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
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5,
                                                            ),
                                                        side:
                                                            (_isAndroidTV &&
                                                                _playFocus
                                                                    .hasFocus)
                                                            ? const BorderSide(
                                                                color: Colors
                                                                    .tealAccent,
                                                                width: 3,
                                                              )
                                                            : BorderSide.none,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // "Retomar" if progress exists
                                                if (hasProgress) ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      focusNode: _resumeFocus,
                                                      onPressed: () async {
                                                        await Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                PlayerScreen(
                                                                  channel: widget
                                                                      .channel,
                                                                  startPosition:
                                                                      Duration(
                                                                        seconds:
                                                                            progress,
                                                                      ),
                                                                ),
                                                          ),
                                                        );
                                                        setState(() {});
                                                      },
                                                      icon: const Icon(
                                                        Icons.history,
                                                      ),
                                                      label: const Text(
                                                        'RETOMAR',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.grey[800],
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                5,
                                                              ),
                                                          side:
                                                              (_isAndroidTV &&
                                                                  _resumeFocus
                                                                      .hasFocus)
                                                              ? const BorderSide(
                                                                  color: Colors
                                                                      .tealAccent,
                                                                  width: 3,
                                                                )
                                                              : BorderSide.none,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 10),
                                      ],
                                    ),

                                    // Favorite Heart (Top Right of Metadata area)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Consumer<ChannelProvider>(
                                        builder: (context, provider, child) {
                                          final isFav = provider.channels
                                              .firstWhere(
                                                (c) =>
                                                    c.id == widget.channel.id,
                                                orElse: () => widget.channel,
                                              )
                                              .isFavorite;
                                          return FocusableActionWrapper(
                                            showFocusHighlight: _isAndroidTV,
                                            onTap: () {
                                              provider.toggleFavorite(
                                                widget.channel,
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Icon(
                                                isFav
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: isFav
                                                    ? Colors.red
                                                    : Colors.white,
                                                size: 32,
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
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Rating Stars
                        Row(
                          children: List.generate(5, (index) {
                            double rating = (widget.channel.rating ?? 0) / 2;
                            if (index < rating) {
                              return const Icon(
                                Icons.star,
                                color: Colors.yellow,
                                size: 24,
                              );
                            } else {
                              return Icon(
                                Icons.star,
                                color: Colors.grey[800],
                                size: 24,
                              );
                            }
                          }),
                        ),

                        const SizedBox(height: 15),

                        // Plot
                        Text(
                          infoData['plot'] ?? 'Sem descrição.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          const SizedBox(width: 40), // Space for Heart on right side rows
        ],
      ),
    );
  }
}
