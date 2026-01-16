import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/epg_program.dart';
import 'dns_service.dart';

import 'package:flutter/foundation.dart'; // For kIsWeb

// Helper to create a client that ignores bad certificates (Mobile/Desktop only)
// On Web, the browser handles SSL, so we can't ignore errors programmatically in the same way.
// Helper removed in favor of internal logic inside _makeRequest or use of conditional imports if strictly needed.
// Leaving empty or removing.

class IptvService {
  final List<String> _proxies = [
    'https://api.codetabs.com/v1/proxy?quest=', // Primary: User confirmed this works for API Lists
    'https://corsproxy.io/?', // Backup
    'https://api.allorigins.win/raw?url=', // Fallback
  ];

  // Helper to wrap URLs in a proxy for Web to bypass CORS/Mixed Content
  String _proxyUrl(String url) {
    if (kIsWeb &&
        !url.startsWith('https') &&
        !url.contains('corsproxy') &&
        !url.contains('allorigins')) {
      // Use corsproxy.io by default for images/content as it's reliable for binaries
      return 'https://corsproxy.io/?' + Uri.encodeComponent(url);
    }
    return url;
  }

  // Centralized Request Helper
  Future<http.Response> _makeRequest(String url) async {
    try {
      if (kIsWeb) {
        // Web: Direct http get
        return await http.get(Uri.parse(url));
      } else {
        // Native: Advanced logic with DNS & SSL Bypass
        final cleanUrl = url;
        final uri = Uri.parse(cleanUrl);

        // DNS Resolve
        final resolvedIp = await DnsService().resolve(uri.host);
        String requestUrl = cleanUrl;
        if (resolvedIp != uri.host) {
          requestUrl = cleanUrl.replaceFirst(uri.host, resolvedIp);
        }

        // HttpClient (Native)
        final httpClient = HttpClient();
        httpClient.badCertificateCallback = (cert, host, port) => true;

        try {
          final request = await httpClient.getUrl(Uri.parse(requestUrl));
          if (resolvedIp != uri.host) {
            request.headers.set('Host', uri.host);
          }
          final ioResponse = await request.close();
          final responseBody = await ioResponse.transform(utf8.decoder).join();
          httpClient.close();

          return http.Response(responseBody, ioResponse.statusCode);
        } catch (e) {
          httpClient.close();
          rethrow;
        }
      }
    } catch (e) {
      print('❌ Erro na conexão direta (${kIsWeb ? "Web" : "Native"}): $e');
      // Proxy Fallback logic
      if (kIsWeb) {
        try {
          for (var proxy in _proxies) {
            try {
              final proxyUrl = Uri.parse(proxy + Uri.encodeComponent(url));
              print('🔄 Tentando proxy: $proxy');
              final response = await http.get(proxyUrl);
              if (response.statusCode == 200) {
                // Force UTF-8 decoding as proxies often mess up headers
                final body = utf8.decode(response.bodyBytes);
                return http.Response(body, 200);
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
      // Last attempt
      try {
        final proxyUrl = Uri.parse(_proxies[0] + Uri.encodeComponent(url));
        return await http.get(proxyUrl);
      } catch (proxyError) {
        print('❌ Erro no proxy final: $proxyError');
        throw Exception('Falha na conexão (Direta e Proxy)');
      }
    }
  }

  Future<Map<String, dynamic>> loginXtream(
    String url,
    String username,
    String password,
  ) async {
    String cleanUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;

    final fullUrl =
        '$cleanUrl/player_api.php?username=$username&password=$password';

    final response = await _makeRequest(fullUrl);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Falha no login: ${response.statusCode}');
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
      final response = await _makeRequest(apiUrl);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
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
      final response = await _makeRequest(apiUrl);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ Erro ao buscar info da Série: $e');
      return {};
    }
  }

  // NEW: Fetch short EPG for a specific channel
  Future<List<EpgProgram>> fetchShortEpg(
    String streamId,
    String url,
    String user,
    String password, {
    int limit = 10,
  }) async {
    final apiUrl =
        '$url/player_api.php?username=$user&password=$password&action=get_short_epg&stream_id=$streamId&limit=$limit';

    try {
      final response = await _makeRequest(apiUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // EPG response format can vary.
        // Usually: { "epg_listings": [ ... ] } or simple list depending on endpoint.
        // get_short_epg standard is: { "epg_listings": [ ... ] }

        List<dynamic> listings = [];
        if (data is Map && data.containsKey('epg_listings')) {
          listings = data['epg_listings'];
        } else if (data is List) {
          listings = data;
        }

        return listings.map((e) => EpgProgram.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Erro ao buscar EPG: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCategories(String apiUrl) async {
    try {
      final response = await _makeRequest(apiUrl);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Erro ao buscar categorias: $e');
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
      final response = await _makeRequest(apiUrl);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => _mapItemToChannel(item, baseUrl, user, pass, type))
            .toList();
      }
      throw Exception('Falha ao carregar dados');
    } catch (e) {
      print('❌ Erro ao buscar dados: $e');
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
      // Browsers don't support MPEG-TS (.ts), use HLS (.m3u8) for Web
      final extension = kIsWeb ? 'm3u8' : 'ts';
      streamUrl = '$baseUrl/live/$user/$pass/${item['stream_id']}.$extension';
    } else if (type == 'movie') {
      streamUrl =
          '$baseUrl/movie/$user/$pass/${item['stream_id']}.${item['container_extension'] ?? 'mp4'}';
    }

    // WEB NOTE: HTTP streams on HTTPS sites will be blocked by Mixed Content.
    // Public proxies (corsproxy/allorigins) fail for video streaming (Format Error / 403).
    // The only solution is for the user to "Allow Insecure Content" in browser settings.
    // if (kIsWeb && !streamUrl.startsWith('https')) { ... }

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
      logoUrl: kIsWeb && (item['stream_icon'] != null || item['cover'] != null)
          ? _proxyUrl(item['stream_icon'] ?? item['cover'])
          : item['stream_icon'] ?? item['cover'],
      category: item['category_id']?.toString() ?? '0',
      rating: rating,
      type: type, // New field
    );
  }

  Future<List<Channel>> fetchChannelsFromM3u(String url) async {
    try {
      final response = await _makeRequest(url);
      if (response.statusCode == 200) {
        return _parseM3u(response.body);
      }
      throw Exception('Falha ao carregar M3U');
    } catch (e) {
      print('❌ Erro ao buscar M3U: $e');
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
