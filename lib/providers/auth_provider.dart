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
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    loadUsers();
  }

  Future<void> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList('user_profiles') ?? [];
    _users = usersJson
        .map((u) => UserProfile.fromJson(json.decode(u)))
        .toList();

    // Auto-login logic
    final lastUserId = prefs.getString('last_user_id');
    if (lastUserId != null && _users.isNotEmpty) {
      try {
        final lastUser = _users.firstWhere((u) => u.id == lastUserId);
        _currentUser = lastUser;
      } catch (e) {
        // User not found (maybe deleted)
        await prefs.remove('last_user_id');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(
    String name,
    String url,
    String user,
    String pass, {
    String? userIdToUpdate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service.loginXtream(url, user, pass);
      print("vamos ver: " + data.toString());
      print("vamos ver: " + data['user_info']['auth'].toString());
      if (data['user_info']['auth'] == 1) {
        final expiry = data['user_info']['exp_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                int.parse(data['user_info']['exp_date']) * 1000,
                isUtc: true,
              )
            : null;

        // Use existing ID if updating, otherwise generate new
        final id =
            userIdToUpdate ?? DateTime.now().millisecondsSinceEpoch.toString();

        final newUser = UserProfile(
          id: id,
          name: name,
          url: url,
          username: user,
          password: pass,
          expiryDate: expiry,
        );

        if (userIdToUpdate != null) {
          // Update existing
          final index = _users.indexWhere((u) => u.id == userIdToUpdate);
          if (index != -1) {
            _users[index] = newUser;
          } else {
            _users.add(newUser);
          }
        } else {
          // Add new
          _users.add(newUser);
        }

        _currentUser = newUser;
        await _saveUsers();
        await _saveLastUser(newUser.id); // Save as last user
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
    await _saveLastUser(user.id);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_user_id');
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

  Future<void> _saveLastUser(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_id', id);
  }
}
