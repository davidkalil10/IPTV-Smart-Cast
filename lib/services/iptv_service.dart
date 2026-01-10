import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  // Lista de proxies para redundância
  final List<String> _proxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
  ];

  Future<Map<String, dynamic>> loginXtream(String url, String username, String password) async {
    String cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final fullUrl = '$cleanUrl/player_api.php?username=$username&password=$password';
    
    // Na Web, usamos o proxy para evitar Mixed Content e CORS
    final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(fullUrl));
    
    try {
      final response = await http.get(finalUrl);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Falha na conexão com o servidor');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Channel>> fetchLiveStreams(String url, String username, String password) async {
    final apiUrl = '$url/player_api.php?username=$username&password=$password&action=get_live_streams';
    return _fetchData(apiUrl, url, username, password, 'live');
  }

  Future<List<Channel>> fetchVodStreams(String url, String username, String password) async {
    final apiUrl = '$url/player_api.php?username=$username&password=$password&action=get_vod_streams';
    return _fetchData(apiUrl, url, username, password, 'movie');
  }

  Future<List<Channel>> fetchSeries(String url, String username, String password) async {
    final apiUrl = '$url/player_api.php?username=$username&password=$password&action=get_series';
    return _fetchData(apiUrl, url, username, password, 'series');
  }

  Future<List<Channel>> _fetchData(String apiUrl, String baseUrl, String user, String pass, String type) async {
    final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(apiUrl));
    try {
      final response = await http.get(finalUrl);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          String streamUrl = '';
          if (type == 'live') {
            streamUrl = '$baseUrl/live/$user/$pass/${item['stream_id']}.ts';
          } else if (type == 'movie') {
            streamUrl = '$baseUrl/movie/$user/$pass/${item['stream_id']}.${item['container_extension'] ?? 'mp4'}';
          }
          
          return Channel(
            id: (item['stream_id'] ?? item['series_id']).toString(),
            name: item['name'],
            streamUrl: streamUrl,
            logoUrl: item['stream_icon'] ?? item['cover'],
            category: item['category_id'].toString(),
          );
        }).toList();
      }
      throw Exception('Falha ao carregar dados');
    } catch (e) {
      rethrow;
    }
  }

  // Mantendo suporte a M3U para compatibilidade
  Future<List<Channel>> fetchChannelsFromM3u(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return _parseM3u(response.body);
    }
    throw Exception('Falha ao carregar M3U');
  }

  List<Channel> _parseM3u(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');
    String? currentName, currentLogo, currentCategory;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        currentName = RegExp(r',([^,]+)$').firstMatch(line)?.group(1)?.trim();
        currentLogo = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line)?.group(1);
        currentCategory = RegExp(r'group-title="([^"]+)"').firstMatch(line)?.group(1);
      } else if (line.startsWith('http') && currentName != null) {
        channels.add(Channel(
          id: DateTime.now().millisecondsSinceEpoch.toString() + channels.length.toString(),
          name: currentName,
          streamUrl: line,
          logoUrl: currentLogo,
          category: currentCategory ?? 'Geral',
        ));
        currentName = null;
      }
    }
    return channels;
  }
}
