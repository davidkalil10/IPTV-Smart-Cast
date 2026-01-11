import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../models/channel.dart';
import '../providers/channel_provider.dart';
import '../services/iptv_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Channel channel;

  const MovieDetailScreen({super.key, required this.channel});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _info = {};

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

                                        // Play Button (Only Play)
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PlayerScreen(
                                                      channel: widget.channel,
                                                    ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[900],
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(140, 45),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            side: const BorderSide(
                                              color: Colors.white24,
                                            ),
                                          ),
                                          child: const Text(
                                            'Play',
                                            style: TextStyle(fontSize: 16),
                                          ),
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
                                          return IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              isFav
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFav
                                                  ? Colors.red
                                                  : Colors.white,
                                              size: 32,
                                            ),
                                            onPressed: () {
                                              provider.toggleFavorite(
                                                widget.channel,
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
