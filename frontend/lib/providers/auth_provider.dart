import 'package:flutter/material.dart';

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
  }

  void logout() {
    _isAuthenticated = false;
    _token = null;
    _user = null;
    notifyListeners();
  }
}
