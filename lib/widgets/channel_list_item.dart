import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../screens/player_screen.dart';

class ChannelListItem extends StatelessWidget {
  final Channel channel;

  const ChannelListItem({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: channel.logoUrl != null
          ? CachedNetworkImage(
              imageUrl: channel.logoUrl!,
              width: 50,
              height: 50,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.tv),
            )
          : const Icon(Icons.tv, size: 40),
      title: Text(channel.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      subtitle: Text(channel.category),
      trailing: const Icon(Icons.play_arrow),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(channel: channel),
          ),
        );
      },
    );
  }
}
