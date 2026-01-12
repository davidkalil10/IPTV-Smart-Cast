import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../screens/player_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/series_detail_screen.dart';
import '../providers/channel_provider.dart';

class ChannelGridItem extends StatefulWidget {
  final Channel channel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChannelGridItem({
    super.key,
    required this.channel,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ChannelGridItem> createState() => _ChannelGridItemState();
}

class _ChannelGridItemState extends State<ChannelGridItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Card(
        elevation: _isFocused ? 12 : 4,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: _isFocused
              ? const BorderSide(color: Colors.purpleAccent, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap:
              widget.onTap ??
              () {
                if (widget.channel.type == 'movie') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MovieDetailScreen(channel: widget.channel),
                    ),
                  );
                } else if (widget.channel.type == 'series') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SeriesDetailScreen(channel: widget.channel),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PlayerScreen(channel: widget.channel),
                    ),
                  );
                }
              },
          onLongPress:
              widget.onLongPress ??
              () {
                context.read<ChannelProvider>().toggleFavorite(widget.channel);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.channel.isFavorite
                          ? '${widget.channel.name} removido dos favoritos'
                          : '${widget.channel.name} adicionado aos favoritos',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
          onFocusChange: (value) {
            setState(() {
              _isFocused = value;
            });
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child:
                          widget.channel.logoUrl != null &&
                              widget.channel.logoUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.channel.logoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Center(
                                    child: Icon(
                                      Icons.tv,
                                      size: 50,
                                      color: Colors.white54,
                                    ),
                                  ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.tv,
                                size: 50,
                                color: Colors.white54,
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      widget.channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.channel.rating != null && widget.channel.rating! > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.channel.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (widget.channel.isFavorite)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 20,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
