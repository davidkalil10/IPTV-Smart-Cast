import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import 'dns_service.dart';

// ⚠️ FUNÇÃO PARA IGNORAR VERIFICAÇÃO DE CERTIFICADO SSL
HttpClient _createHttpClient() {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback =
      (X509Certificate cert, String host, int port) {
        print('⚠️ Certificado inválido aceito para: $host:$port');
        return true;
      };
  return httpClient;
}

class IptvService {
  final List<String> _proxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
  ];

  Future<Map<String, dynamic>> loginXtream(
    String url,
    String username,
    String password,
  ) async {
    String cleanUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;

    // DNS Resolution
    final uri = Uri.parse(cleanUrl);
    final resolvedIp = await DnsService().resolve(uri.host);
    final finalUrlStr = cleanUrl.replaceFirst(uri.host, resolvedIp);
    final fullUrl =
        '$finalUrlStr/player_api.php?username=$username&password=$password';

    try {
      final httpClient = _createHttpClient();
      final request = await httpClient.getUrl(Uri.parse(fullUrl));

      // Critical: Set Host header if we replaced the IP
      if (resolvedIp != uri.host) {
        request.headers.set('Host', uri.host);
      }

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

  Future<List<Map<String, dynamic>>> fetchLiveCategories(
    String url,
    String username,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$username&password=$password&action=get_live_categories';
    return _fetchCategories(apiUrl);
  }

  Future<List<Channel>> fetchLiveStreams(
    String url,
    String username,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$username&password=$password&action=get_live_streams';
    return _fetchData(apiUrl, url, username, password, 'live');
  }

  Future<List<Map<String, dynamic>>> fetchVodCategories(
    String url,
    String username,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$username&password=$password&action=get_vod_categories';
    return _fetchCategories(apiUrl);
  }

  Future<List<Channel>> fetchVodStreams(
    String url,
    String username,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$username&password=$password&action=get_vod_streams';
    return _fetchData(apiUrl, url, username, password, 'movie');
  }

  Future<List<Map<String, dynamic>>> fetchSeriesCategories(
    String url,
    String username,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$username&password=$password&action=get_series_categories';
    return _fetchCategories(apiUrl);
  }

  Future<List<Channel>> fetchSeries(
    String url,
    String username,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$username&password=$password&action=get_series';
    return _fetchData(apiUrl, url, username, password, 'series');
  }

  // NEW: Fetch detailed info for a specific VOD (Movie)
  Future<Map<String, dynamic>> getVodInfo(
    String vodId,
    String url,
    String user,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$user&password=$password&action=get_vod_info&vod_id=$vodId';

    try {
      final httpClient = _createHttpClient();

      // DNS Logic
      Uri uri = Uri.parse(apiUrl);
      final resolvedIp = await DnsService().resolve(uri.host);
      String requestUrl = apiUrl;
      if (resolvedIp != uri.host) {
        requestUrl = apiUrl.replaceFirst(uri.host, resolvedIp);
      }

      final request = await httpClient.getUrl(Uri.parse(requestUrl));
      if (resolvedIp != uri.host) {
        request.headers.set('Host', uri.host);
      }

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();
        return json.decode(responseBody);
      }
      httpClient.close();
      return {};
    } catch (e) {
      print('❌ Erro ao buscar info do VOD: $e');
      return {};
    }
  }

  // NEW: Fetch detailed info for a specific Series
  Future<Map<String, dynamic>> getSeriesInfo(
    String seriesId,
    String url,
    String user,
    String password,
  ) async {
    final apiUrl =
        '$url/player_api.php?username=$user&password=$password&action=get_series_info&series_id=$seriesId';

    try {
      final httpClient = _createHttpClient();

      // DNS Logic
      Uri uri = Uri.parse(apiUrl);
      final resolvedIp = await DnsService().resolve(uri.host);
      String requestUrl = apiUrl;
      if (resolvedIp != uri.host) {
        requestUrl = apiUrl.replaceFirst(uri.host, resolvedIp);
      }

      final request = await httpClient.getUrl(Uri.parse(requestUrl));
      if (resolvedIp != uri.host) {
        request.headers.set('Host', uri.host);
      }

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();
        return json.decode(responseBody);
      }
      httpClient.close();
      return {};
    } catch (e) {
      print('❌ Erro ao buscar info da Série: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCategories(String apiUrl) async {
    try {
      final httpClient = _createHttpClient();

      // DNS Resolution Implementation for generic calls
      Uri uri = Uri.parse(apiUrl);
      final resolvedIp = await DnsService().resolve(uri.host);
      String requestUrl = apiUrl;

      if (resolvedIp != uri.host) {
        requestUrl = apiUrl.replaceFirst(uri.host, resolvedIp);
      }

      final request = await httpClient.getUrl(Uri.parse(requestUrl));

      if (resolvedIp != uri.host) {
        request.headers.set('Host', uri.host);
      }

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();
        final List<dynamic> data = json.decode(responseBody);
        return data.cast<Map<String, dynamic>>();
      }
      httpClient.close();
      return [];
    } catch (e) {
      print('❌ Erro ao buscar categorias: $e');
      try {
        final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(apiUrl));
        final response = await http.get(finalUrl);
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.cast<Map<String, dynamic>>();
        }
      } catch (proxyError) {
        print('❌ Erro no proxy (categorias): $proxyError');
      }
      return [];
    }
  }

  Future<List<Channel>> _fetchData(
    String apiUrl,
    String baseUrl,
    String user,
    String pass,
    String type,
  ) async {
    try {
      final httpClient = _createHttpClient();

      // DNS Resolution Implementation for generic calls
      Uri uri = Uri.parse(apiUrl);
      final resolvedIp = await DnsService().resolve(uri.host);
      String requestUrl = apiUrl;

      if (resolvedIp != uri.host) {
        requestUrl = apiUrl.replaceFirst(uri.host, resolvedIp);
      }

      final request = await httpClient.getUrl(Uri.parse(requestUrl));

      if (resolvedIp != uri.host) {
        request.headers.set('Host', uri.host);
      }

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        httpClient.close();

        final List<dynamic> data = json.decode(responseBody);
        return data
            .map((item) => _mapItemToChannel(item, baseUrl, user, pass, type))
            .toList();
      }
      httpClient.close();
      throw Exception('Falha ao carregar dados');
    } catch (e) {
      print('❌ Erro ao buscar dados: $e');
      try {
        final finalUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(apiUrl));
        final response = await http.get(finalUrl);
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map((item) => _mapItemToChannel(item, baseUrl, user, pass, type))
              .toList();
        }
      } catch (proxyError) {
        print('❌ Erro no proxy: $proxyError');
      }
      rethrow;
    }
  }

  Channel _mapItemToChannel(
    Map<String, dynamic> item,
    String baseUrl,
    String user,
    String pass,
    String type,
  ) {
    String streamUrl = '';
    if (type == 'live') {
      streamUrl = '$baseUrl/live/$user/$pass/${item['stream_id']}.ts';
    } else if (type == 'movie') {
      streamUrl =
          '$baseUrl/movie/$user/$pass/${item['stream_id']}.${item['container_extension'] ?? 'mp4'}';
    }

    // Parse rating
    double? rating;
    if (item['rating'] != null && item['rating'].toString().isNotEmpty) {
      rating = double.tryParse(item['rating'].toString());
    } else if (item['rating_5based'] != null &&
        item['rating_5based'].toString().isNotEmpty) {
      rating = double.tryParse(item['rating_5based'].toString());
    }

    return Channel(
      id: (item['stream_id'] ?? item['series_id']).toString(),
      name: item['name'] ?? 'Sem nome',
      streamUrl: streamUrl,
      logoUrl: item['stream_icon'] ?? item['cover'],
      category: item['category_id']?.toString() ?? '0',
      rating: rating,
      type: type, // New field
    );
  }

  Future<List<Channel>> fetchChannelsFromM3u(String url) async {
    try {
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

  List<Channel> _parseM3u(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');
    String? currentName, currentLogo, currentCategory;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        currentName = RegExp(r',([^,]+)$').firstMatch(line)?.group(1)?.trim();
        currentLogo = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line)?.group(1);
        currentCategory = RegExp(
          r'group-title="([^"]+)"',
        ).firstMatch(line)?.group(1);
      } else if (line.startsWith('http') && currentName != null) {
        channels.add(
          Channel(
            id:
                DateTime.now().millisecondsSinceEpoch.toString() +
                channels.length.toString(),
            name: currentName,
            streamUrl: line,
            logoUrl: currentLogo,
            category: currentCategory ?? 'Geral',
            type: 'live', // Default to live for M3U for now
          ),
        );
        currentName = null;
      }
    }
    return channels;
  }
}
