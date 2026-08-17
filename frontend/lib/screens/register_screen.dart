import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;

  Future<void> _register() async {
    final messenger = ScaffoldMessenger.of(context);
    final rawUsername = _usernameController.text;
    final rawEmail = _emailController.text;
    final rawPassword = _passwordController.text;
    final rawPin = _pinController.text;

    final username = rawUsername.trim();
    final email = rawEmail.trim();
    final pin = rawPin.trim();

    if (username.isEmpty || email.isEmpty || rawPassword.isEmpty || pin.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ tất cả thông tin (bao gồm Mã PIN)'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    if (rawEmail.contains(' ')) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Địa chỉ Email không được chứa khoảng trắng. Vui lòng kiểm tra lại!'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Định dạng Email không hợp lệ (ví dụ: name@domain.com)'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    if (rawPassword.startsWith(' ') || rawPassword.endsWith(' ')) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mật khẩu không được chứa khoảng trắng ở đầu hoặc cuối'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    final password = rawPassword;

    if (password.length < 6) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mật khẩu phải có ít nhất 6 ký tự'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mã PIN phải gồm đúng 6 chữ số (chỉ chứa số)'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'pin': pin,
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        _usernameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _pinController.clear();
        // Purge any lingering session from previous accounts
        Provider.of<AuthProvider>(context, listen: false).logout();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Đăng ký tài khoản thành công! Vui lòng đăng nhập.'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        if (!mounted) return;
        final resData = jsonDecode(response.body);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(resData['error'] ?? 'Đăng ký thất bại. Vui lòng kiểm tra lại thông tin.'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)),
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
      appBar: AppBar(
        title: Text('Đăng Ký Tài Khoản', style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeProvider.textColor),
      ),
      body: Container(
        color: themeProvider.backgroundColor,
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                style: TextStyle(color: themeProvider.textColor),
                decoration: InputDecoration(
                  labelText: 'Tên người dùng',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                ),
              ),
              const SizedBox(height: 12),
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
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
                ],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: _obscurePin,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Mã PIN bảo mật (6 chữ số)',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  hintText: 'Ví dụ: 123456',
                  hintStyle: TextStyle(color: themeProvider.subtitleColor.withValues(alpha: 0.5)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                        child: const Text('Tạo Tài Khoản', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
