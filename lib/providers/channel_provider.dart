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
        loadXtream(_savedUrl!, _savedUser!, _savedPass!);
      } else {
        loadM3u(_savedUrl!);
      }
    }
  }

  Future<void> loadM3u(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _channels = await _service.fetchChannelsFromM3u(url);
      _savedUrl = url;
      _isXtream = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iptv_url', url);
      await prefs.setBool('is_xtream', false);
    } catch (e) {
      _error = 'Falha ao carregar lista M3U.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadXtream(String url, String user, String pass) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authData = await _service.loginXtream(url, user, pass);
      if (authData['auth'] == 1) {
        _channels = await _service.fetchLiveStreams(url, user, pass);
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
      _error = 'Falha na autenticação Xtream Codes.';
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
