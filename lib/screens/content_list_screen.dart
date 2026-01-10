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
      print('📺 Carregando conteúdo do tipo: ${widget.type}');
      print('👤 Usuário: ${user.username}');
      print('🔗 URL: ${user.url}');

      if (widget.type == 'live') {
        print('📡 Chamando loadXtream para streams ao vivo');
        provider.loadXtream(user.url, user.username, user.password);
      } else if (widget.type == 'movie') {
        print('📡 Chamando loadVod para filmes');
        provider.loadVod(user.url, user.username, user.password);
      } else if (widget.type == 'series') {
        print('📡 Chamando loadSeries para séries');
        provider.loadSeries(user.url, user.username, user.password);
      }
    } else {
      print('❌ Erro: Usuário não encontrado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContent,
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: Consumer<ChannelProvider>(
        builder: (context, provider, child) {
          // Mostrar indicador de carregamento
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando conteúdo...'),
                ],
              ),
            );
          }

          // Mostrar erro se houver
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadContent,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          // Mostrar lista vazia
          if (provider.channels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nenhum conteúdo disponível'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadContent,
                    child: const Text('Recarregar'),
                  ),
                ],
              ),
            );
          }

          // Mostrar lista de canais
          return ListView.builder(
            itemCount: provider.channels.length,
            itemBuilder: (context, index) {
              final channel = provider.channels[index];
              return ChannelListItem(channel: channel);
            },
          );
        },
      ),
    );
  }
}
