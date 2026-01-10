import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/iptv_service.dart';

class AuthProvider with ChangeNotifier {
  List<UserProfile> _users = [];
  UserProfile? _currentUser;
  bool _isLoading = false;
  final IptvService _service = IptvService();

  List<UserProfile> get users => _users;
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthProvider() {
    loadUsers();
  }

  Future<void> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList('user_profiles') ?? [];
    _users = usersJson.map((u) => UserProfile.fromJson(json.decode(u))).toList();
    notifyListeners();
  }

  Future<bool> login(String name, String url, String user, String pass) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service.loginXtream(url, user, pass);
      print("vamos ver: " + data.toString() );
      print("vamos ver: " + data['user_info']['auth'].toString() );
      if (data['user_info']['auth'] == 1) {
        final expiry = data['user_info']['exp_date'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(data['user_info']['exp_date']) * 1000)
            : null;
            
        final newUser = UserProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          url: url,
          username: user,
          password: pass,
          expiryDate: expiry,
        );

        _users.add(newUser);
        _currentUser = newUser;
        await _saveUsers();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> selectUser(UserProfile user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> removeUser(String id) async {
    _users.removeWhere((u) => u.id == id);
    await _saveUsers();
    notifyListeners();
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = _users.map((u) => json.encode(u.toJson())).toList();
    await prefs.setStringList('user_profiles', usersJson);
  }
}
