import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/channel_list_item.dart';

class ContentListScreen extends StatefulWidget {
  final String type; // 'live', 'movie', 'series'
  final String title;

  const ContentListScreen({super.key, required this.type, required this.title});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ChannelProvider>();
    final user = auth.currentUser;
    
    if (user != null) {
      if (widget.type == 'live') {
        provider.loadXtream(user.url, user.username, user.password);
      } else if (widget.type == 'movie') {
        // Aqui chamaria o fetchVodStreams no provider
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadContent),
        ],
      ),
      body: Consumer<ChannelProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          if (provider.error != null) return Center(child: Text(provider.error!));
          
          return ListView.builder(
            itemCount: provider.channels.length,
            itemBuilder: (context, index) => ChannelListItem(channel: provider.channels[index]),
          );
        },
      ),
    );
  }
}
