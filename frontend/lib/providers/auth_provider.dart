import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_config.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  void login({String? token, Map<String, dynamic>? user}) {
    _isAuthenticated = true;
    _token = token;
    _user = user;
    notifyListeners();
    fetchUserProfile();
  }

  void setUser(Map<String, dynamic>? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    if (_token == null || _token!.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: authHeaders,
      );
      if (response.statusCode == 200) {
        _user = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user profile in AuthProvider: $e');
    }
  }

  void logout() {
    _isAuthenticated = false;
    _token = null;
    _user = null;
    notifyListeners();
  }
}

