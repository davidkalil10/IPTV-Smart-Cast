import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../services/iptv_service.dart';

class ChannelProvider with ChangeNotifier {
  List<Channel> _channels = [];
  bool _isLoading = false;
  String? _error;

  String? _savedUrl;
  String? _savedUser;
  String? _savedPass;
  bool _isXtream = false;

  // Cache separate lists
  List<Channel> _cachedLive = [];
  List<Channel> _cachedMovies = [];
  List<Channel> _cachedSeries = [];

  // Timestamps
  DateTime? _lastLiveUpdate;
  DateTime? _lastMovieUpdate;
  DateTime? _lastSeriesUpdate;

  DateTime? get lastLiveUpdate => _lastLiveUpdate;
  DateTime? get lastMovieUpdate => _lastMovieUpdate;
  DateTime? get lastSeriesUpdate => _lastSeriesUpdate;

  Map<String, String> _categoryMap = {};
  Set<String> _favoriteIds = {};

  List<Channel> get channels => _channels;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get savedUrl => _savedUrl;
  String? get savedUser => _savedUser;
  String? get savedPass => _savedPass;
  bool get isXtream => _isXtream;

  final IptvService _service = IptvService();

  ChannelProvider() {
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _savedUrl = prefs.getString('iptv_url');
    _savedUser = prefs.getString('iptv_user');
    _savedPass = prefs.getString('iptv_pass');
    _isXtream = prefs.getBool('is_xtream') ?? false;
    _favoriteIds = (prefs.getStringList('favorites') ?? []).toSet();

    if (_savedUrl != null) {
      if (_isXtream && _savedUser != null && _savedPass != null) {
        // Carrega streams ao vivo por padrão
        loadXtream(_savedUrl!, _savedUser!, _savedPass!);
      } else {
        loadM3u(_savedUrl!);
      }
    }
  }

  Future<void> toggleFavorite(Channel channel) async {
    if (_favoriteIds.contains(channel.id)) {
      _favoriteIds.remove(channel.id);
    } else {
      _favoriteIds.add(channel.id);
    }

    _channels = _channels.map((c) {
      if (c.id == channel.id) {
        return Channel(
          id: c.id,
          name: c.name,
          streamUrl: c.streamUrl,
          logoUrl: c.logoUrl,
          category: c.category,
          isFavorite: _favoriteIds.contains(c.id),
          rating: c.rating,
          type: c.type,
        );
      }
      return c;
    }).toList();

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favoriteIds.toList());
  }

  Future<void> loadM3u(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando M3U de: $url');
      final fetchedChannels = await _service.fetchChannelsFromM3u(url);
      _channels = _mapChannelsWithFavorites(fetchedChannels);
      _savedUrl = url;
      _isXtream = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iptv_url', url);
      await prefs.setBool('is_xtream', false);
      print(
        '✅ M3U carregado com sucesso. Total de canais: ${_channels.length}',
      );
    } catch (e) {
      print('❌ Erro ao carregar M3U: $e');
      _error = 'Falha ao carregar lista M3U: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadXtream(
    String url,
    String user,
    String pass, {
    bool forceRefresh = false,
  }) async {
    // If not forced and we have cache, use it (assumes caller checked staleness if they cared)
    if (!forceRefresh && _cachedLive.isNotEmpty) {
      _channels = _cachedLive;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando streams ao vivo de: $url');
      final authData = await _service.loginXtream(url, user, pass);

      if (authData['user_info']['auth'] == 1) {
        print('✅ Autenticação bem-sucedida. Buscando categorias...');
        final categories = await _service.fetchLiveCategories(url, user, pass);
        _updateCategoryMap(categories);

        final streams = await _service.fetchLiveStreams(url, user, pass);
        _cachedLive = _mapChannelsWithCategoriesAndFavorites(streams);
        _channels = _cachedLive;
        _lastLiveUpdate = DateTime.now();

        print('✅ Streams ao vivo carregados. Total: ${_channels.length}');
      } else {
        throw Exception('Falha na autenticação');
      }

      _saveCredentials(url, user, pass);
    } catch (e) {
      print('❌ Erro ao carregar streams ao vivo: $e');
      _error = 'Falha na autenticação Xtream Codes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVod(
    String url,
    String user,
    String pass, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedMovies.isNotEmpty) {
      _channels = _cachedMovies;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando filmes (VOD) de: $url');
      final authData = await _service.loginXtream(url, user, pass);

      if (authData['user_info']['auth'] == 1) {
        print('✅ Autenticação bem-sucedida. Buscando categorias de filmes...');
        final categories = await _service.fetchVodCategories(url, user, pass);
        _updateCategoryMap(categories);

        final streams = await _service.fetchVodStreams(url, user, pass);
        _cachedMovies = _mapChannelsWithCategoriesAndFavorites(streams);
        _channels = _cachedMovies;
        _lastMovieUpdate = DateTime.now();

        print('✅ Filmes carregados. Total: ${_channels.length}');
      } else {
        throw Exception('Falha na autenticação');
      }

      _saveCredentials(url, user, pass);
    } catch (e) {
      print('❌ Erro ao carregar filmes: $e');
      _error = 'Falha ao carregar filmes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSeries(
    String url,
    String user,
    String pass, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedSeries.isNotEmpty) {
      _channels = _cachedSeries;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando séries de: $url');
      final authData = await _service.loginXtream(url, user, pass);

      if (authData['user_info']['auth'] == 1) {
        print('✅ Autenticação bem-sucedida. Buscando categorias de séries...');
        final categories = await _service.fetchSeriesCategories(
          url,
          user,
          pass,
        );
        _updateCategoryMap(categories);

        final streams = await _service.fetchSeries(url, user, pass);
        _cachedSeries = _mapChannelsWithCategoriesAndFavorites(streams);
        _channels = _cachedSeries;
        _lastSeriesUpdate = DateTime.now();

        print('✅ Séries carregadas. Total: ${_channels.length}');
      } else {
        throw Exception('Falha na autenticação');
      }

      _saveCredentials(url, user, pass);
    } catch (e) {
      print('❌ Erro ao carregar séries: $e');
      _error = 'Falha ao carregar séries: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if updates are needed (older than 1 day) and refresh separately
  Future<void> checkAndBackgroundRefresh() async {
    if (_savedUrl == null || _savedUser == null || _savedPass == null) return;

    final now = DateTime.now();
    const oneDay = Duration(days: 1);

    // We won't block UI with _isLoading here, maybe just update silently or handle specifically?
    // Since the user wants "Content to be updated upon opening home screen if > 1 day",
    // we can just clear the cache for those items, forcing the next click/load to refresh.
    // Or we can actively fetch. Actively fetching 3 types might be heavy.
    // Let's clear cache if expired, so the user sees "Updated: [Old Date]" until they click?
    // No, "ao abrir a home screen o conteudo deve ser atualizado".
    // This implies an active update.

    // Let's implement active refresh for stale content.
    bool needsRefresh = false;
    if (_lastLiveUpdate == null || now.difference(_lastLiveUpdate!) > oneDay)
      needsRefresh = true;
    if (_lastMovieUpdate == null || now.difference(_lastMovieUpdate!) > oneDay)
      needsRefresh = true;
    if (_lastSeriesUpdate == null ||
        now.difference(_lastSeriesUpdate!) > oneDay)
      needsRefresh = true;

    if (!needsRefresh) return;

    // We run this sequentially to avoid overwhelming.
    // Also we DO NOT set _isLoading globally to avoid blocking the whole Home Screen if unwanted.
    // But if we don't set loading, the UI won't show it's updating.
    // The requirement "content must be updated" suggests we should just do it.

    if (_lastLiveUpdate == null || now.difference(_lastLiveUpdate!) > oneDay) {
      await loadXtream(
        _savedUrl!,
        _savedUser!,
        _savedPass!,
        forceRefresh: true,
      );
    }
    if (_lastMovieUpdate == null ||
        now.difference(_lastMovieUpdate!) > oneDay) {
      await loadVod(_savedUrl!, _savedUser!, _savedPass!, forceRefresh: true);
    }
    if (_lastSeriesUpdate == null ||
        now.difference(_lastSeriesUpdate!) > oneDay) {
      await loadSeries(
        _savedUrl!,
        _savedUser!,
        _savedPass!,
        forceRefresh: true,
      );
    }
  }

  void _updateCategoryMap(List<Map<String, dynamic>> categories) {
    _categoryMap.clear();
    for (var cat in categories) {
      final id = cat['category_id']?.toString();
      final name = cat['category_name']?.toString();
      if (id != null && name != null) {
        _categoryMap[id] = name;
      }
    }
  }

  List<Channel> _mapChannelsWithFavorites(List<Channel> channels) {
    return channels.map((c) {
      return Channel(
        id: c.id,
        name: c.name,
        streamUrl: c.streamUrl,
        logoUrl: c.logoUrl,
        category: c.category,
        isFavorite: _favoriteIds.contains(c.id),
        rating: c.rating,
        type: c.type,
      );
    }).toList();
  }

  List<Channel> _mapChannelsWithCategoriesAndFavorites(List<Channel> channels) {
    return channels.map((c) {
      final categoryName = _categoryMap[c.category] ?? c.category;
      return Channel(
        id: c.id,
        name: c.name,
        streamUrl: c.streamUrl,
        logoUrl: c.logoUrl,
        category: categoryName,
        isFavorite: _favoriteIds.contains(c.id),
        rating: c.rating,
        type: c.type,
      );
    }).toList();
  }

  Future<void> _saveCredentials(String url, String user, String pass) async {
    _savedUrl = url;
    _savedUser = user;
    _savedPass = pass;
    _isXtream = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('iptv_url', url);
    await prefs.setString('iptv_user', user);
    await prefs.setString('iptv_pass', pass);
    await prefs.setBool('is_xtream', true);
  }

  void clearList() async {
    _channels = [];
    _cachedLive = [];
    _cachedMovies = [];
    _cachedSeries = [];
    _lastLiveUpdate = null;
    _lastMovieUpdate = null;
    _lastSeriesUpdate = null;
    _savedUrl = null;
    _savedUser = null;
    _savedPass = null;
    _isXtream = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
