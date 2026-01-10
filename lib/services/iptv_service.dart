import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

// ⚠️ FUNÇÃO PARA IGNORAR VERIFICAÇÃO DE CERTIFICADO SSL
// Use apenas em desenvolvimento! Para produção, implemente validação de certificado.
HttpClient _createHttpClient() {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
    // Retorna true para aceitar certificados inválidos
    print('⚠️ Certificado inválido aceito para: $host:$port');
    return true;
  };
  return httpClient;
}

class IptvService {
  // Lista de proxies para redundância (usado como fallback)
  final List<String> _proxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
  ];

  /// Login Xtream - Corrigido para aceitar certificados inválidos
  Future<Map<String, dynamic>> loginXtream(String url, String username, String password) async {
    String cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final fullUrl = '$cleanUrl/player_api.php?username=$username&password=$password';

    try {
      // Tenta conexão direta primeiro (com certificado inválido aceito)
      final httpClient = _createHttpClient();
      final request = await httpClient.getUrl(Uri.parse(fullUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();
        return json.decode(responseBody);
      }
      httpClient.close();
      throw Exception('Falha na conexão com o servidor');
    } catch (e) {
      print('❌ Erro na conexão direta: $e');
      // Fallback: tenta com proxy
      try {
        final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(fullUrl));
        final response = await http.get(finalUrl);
        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
      } catch (proxyError) {
        print('❌ Erro no proxy: $proxyError');
      }
      rethrow;
    }
  }

  /// Buscar streams ao vivo - Corrigido
  Future<List<Channel>> fetchLiveStreams(String url, String username, String password) async {
    final apiUrl = '$url/player_api.php?username=$username&password=$password&action=get_live_streams';
    return _fetchData(apiUrl, url, username, password, 'live');
  }

  /// Buscar streams VOD - Corrigido
  Future<List<Channel>> fetchVodStreams(String url, String username, String password) async {
    final apiUrl = '$url/player_api.php?username=$username&password=$password&action=get_vod_streams';
    return _fetchData(apiUrl, url, username, password, 'movie');
  }

  /// Buscar séries - Corrigido
  Future<List<Channel>> fetchSeries(String url, String username, String password) async {
    final apiUrl = '$url/player_api.php?username=$username&password=$password&action=get_series';
    return _fetchData(apiUrl, url, username, password, 'series');
  }

  /// Método interno para buscar dados - Corrigido para aceitar certificados inválidos
  Future<List<Channel>> _fetchData(String apiUrl, String baseUrl, String user, String pass, String type) async {
    try {
      // Tenta conexão direta primeiro
      final httpClient = _createHttpClient();
      final request = await httpClient.getUrl(Uri.parse(apiUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();

        final List<dynamic> data = json.decode(responseBody);
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
      httpClient.close();
      throw Exception('Falha ao carregar dados');
    } catch (e) {
      print('❌ Erro ao buscar dados: $e');
      // Fallback: tenta com proxy
      try {
        final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(apiUrl));
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
      } catch (proxyError) {
        print('❌ Erro no proxy: $proxyError');
      }
      rethrow;
    }
  }

  /// Buscar canais de arquivo M3U - Corrigido
  Future<List<Channel>> fetchChannelsFromM3u(String url) async {
    try {
      // Tenta conexão direta primeiro
      final httpClient = _createHttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();
        return _parseM3u(responseBody);
      }
      httpClient.close();
      throw Exception('Falha ao carregar M3U');
    } catch (e) {
      print('❌ Erro ao buscar M3U: $e');
      // Fallback: tenta com proxy
      try {
        final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(url));
        final response = await http.get(finalUrl);
        if (response.statusCode == 200) {
          return _parseM3u(response.body);
        }
      } catch (proxyError) {
        print('❌ Erro no proxy: $proxyError');
      }
      rethrow;
    }
  }

  /// Parser de arquivo M3U
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
