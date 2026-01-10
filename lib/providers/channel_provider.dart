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

    if (_savedUrl != null) {
      if (_isXtream && _savedUser != null && _savedPass != null) {
        // Carrega streams ao vivo por padrão
        loadXtream(_savedUrl!, _savedUser!, _savedPass!);
      } else {
        loadM3u(_savedUrl!);
      }
    }
  }

  /// Carrega lista M3U
  Future<void> loadM3u(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando M3U de: $url');
      _channels = await _service.fetchChannelsFromM3u(url);
      _savedUrl = url;
      _isXtream = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iptv_url', url);
      await prefs.setBool('is_xtream', false);
      print('✅ M3U carregado com sucesso. Total de canais: ${_channels.length}');
    } catch (e) {
      print('❌ Erro ao carregar M3U: $e');
      _error = 'Falha ao carregar lista M3U: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carrega streams ao vivo (TV)
  Future<void> loadXtream(String url, String user, String pass) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando streams ao vivo de: $url');
      final authData = await _service.loginXtream(url, user, pass);
      print('🔑 Dados de autenticação: $authData');

      // ✅ CORREÇÃO: Acessar 'auth' dentro de 'user_info'
      if (authData['user_info']['auth'] == 1) {
        print('✅ Autenticação bem-sucedida');
        _channels = await _service.fetchLiveStreams(url, user, pass);
        print('✅ Streams ao vivo carregados. Total: ${_channels.length}');
      } else {
        throw Exception('Falha na autenticação');
      }

      _savedUrl = url;
      _savedUser = user;
      _savedPass = pass;
      _isXtream = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iptv_url', url);
      await prefs.setString('iptv_user', user);
      await prefs.setString('iptv_pass', pass);
      await prefs.setBool('is_xtream', true);
    } catch (e) {
      print('❌ Erro ao carregar streams ao vivo: $e');
      _error = 'Falha na autenticação Xtream Codes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carrega filmes (VOD)
  Future<void> loadVod(String url, String user, String pass) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando filmes (VOD) de: $url');
      final authData = await _service.loginXtream(url, user, pass);

      // ✅ CORREÇÃO: Acessar 'auth' dentro de 'user_info'
      if (authData['user_info']['auth'] == 1) {
        print('✅ Autenticação bem-sucedida');
        _channels = await _service.fetchVodStreams(url, user, pass);
        print('✅ Filmes carregados. Total: ${_channels.length}');
      } else {
        throw Exception('Falha na autenticação');
      }

      _savedUrl = url;
      _savedUser = user;
      _savedPass = pass;
      _isXtream = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iptv_url', url);
      await prefs.setString('iptv_user', user);
      await prefs.setString('iptv_pass', pass);
      await prefs.setBool('is_xtream', true);
    } catch (e) {
      print('❌ Erro ao carregar filmes: $e');
      _error = 'Falha ao carregar filmes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carrega séries
  Future<void> loadSeries(String url, String user, String pass) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Carregando séries de: $url');
      final authData = await _service.loginXtream(url, user, pass);

      // ✅ CORREÇÃO: Acessar 'auth' dentro de 'user_info'
      if (authData['user_info']['auth'] == 1) {
        print('✅ Autenticação bem-sucedida');
        _channels = await _service.fetchSeries(url, user, pass);
        print('✅ Séries carregadas. Total: ${_channels.length}');
      } else {
        throw Exception('Falha na autenticação');
      }

      _savedUrl = url;
      _savedUser = user;
      _savedPass = pass;
      _isXtream = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iptv_url', url);
      await prefs.setString('iptv_user', user);
      await prefs.setString('iptv_pass', pass);
      await prefs.setBool('is_xtream', true);
    } catch (e) {
      print('❌ Erro ao carregar séries: $e');
      _error = 'Falha ao carregar séries: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearList() async {
    _channels = [];
    _savedUrl = null;
    _savedUser = null;
    _savedPass = null;
    _isXtream = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
