import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_config.dart';
import '../services/autolock_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    final rawEmail = _emailController.text;
    final email = rawEmail.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Vui lòng nhập Email và Mật khẩu'), backgroundColor: Colors.orangeAccent));
      return;
    }

    if (rawEmail.contains(' ')) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Địa chỉ Email không được chứa khoảng trắng'), backgroundColor: Colors.orangeAccent));
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Định dạng Email không hợp lệ'), backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        final responseData = jsonDecode(response.body);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.login(
          token: responseData['token'],
          user: responseData['user'],
        );
        _emailController.clear();
        _passwordController.clear();
        Provider.of<AutoLockService>(context, listen: false).unlock();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(content: Text('Đăng nhập thành công!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        if (!mounted) return;
        final resData = jsonDecode(response.body);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(resData['error'] ?? 'Email hoặc mật khẩu không chính xác'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Lỗi kết nối máy chủ: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: Container(
        color: themeProvider.backgroundColor,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.nfc, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text('Secure NFC Wallet', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              style: TextStyle(color: themeProvider.textColor),
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: themeProvider.subtitleColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.subtitleColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              style: TextStyle(color: themeProvider.textColor),
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Mật khẩu / Password',
                labelStyle: TextStyle(color: themeProvider.subtitleColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.subtitleColor)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                      child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text('Register Account', style: TextStyle(color: themeProvider.subtitleColor)),
            )
          ],
        ),
      ),
    );
  }
}
