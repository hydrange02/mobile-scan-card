import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'services/autolock_service.dart';
import 'services/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/help_screen.dart';
import 'screens/wallet_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AutoLockService()),
      ],
      child: const NFCWalletApp(),
    ),
  );
}

class NFCWalletApp extends StatelessWidget {
  const NFCWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final autoLockService = Provider.of<AutoLockService>(context);

    return Listener(
      onPointerDown: (_) => autoLockService.resetTimer(),
      onPointerMove: (_) => autoLockService.resetTimer(),
      child: MaterialApp(
        title: 'Secure NFC Wallet',
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.themeMode,
        theme: ThemeProvider.lightTheme,
        darkTheme: ThemeProvider.darkTheme,
        initialRoute: '/login',
        builder: (context, child) {
          final authProvider = Provider.of<AuthProvider>(context);
          final shouldShowLock = autoLockService.isLocked && authProvider.isAuthenticated;
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (shouldShowLock) const LockOverlayScreen(),
            ],
          );
        },
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/dashboard': (context) => const HomeScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/reports': (context) => const ReportsScreen(),
          '/help': (context) => const HelpScreen(),
        },
      ),
    );
  }
}

class LockOverlayScreen extends StatefulWidget {
  const LockOverlayScreen({super.key});

  @override
  State<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends State<LockOverlayScreen> {
  final _pinController = TextEditingController();
  bool _isVerifying = false;

  void _showUnlockDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Nhập Mã PIN Để Mở Khóa', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 4),
            decoration: const InputDecoration(
              labelText: 'Mã PIN bảo mật',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: _isVerifying
                  ? null
                  : () async {
                      final pin = _pinController.text.trim();
                      if (pin.length != 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập đủ 6 chữ số Mã PIN'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => _isVerifying = true);
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final autoLockService = Provider.of<AutoLockService>(context, listen: false);
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        final response = await http.post(
                          Uri.parse('${ApiConfig.baseUrl}/api/user/verify-pin'),
                          headers: authProvider.authHeaders,
                          body: jsonEncode({'pin': pin}),
                        );

                        if (response.statusCode == 200) {
                          navigator.pop();
                          autoLockService.unlock();
                        } else {
                          final resData = jsonDecode(response.body);
                          messenger.showSnackBar(
                            SnackBar(content: Text(resData['error'] ?? 'Mã PIN không chính xác'), backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        navigator.pop();
                        autoLockService.unlock();
                      } finally {
                        setDialogState(() => _isVerifying = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: _isVerifying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Mở khóa'),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPinDialogOnLock() {
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Mở Khóa Qua Mật Khẩu', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập mật khẩu tài khoản để mở khóa & tạo PIN mới (6 số):', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu tài khoản',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Vui lòng nhập mật khẩu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mã PIN mới (đúng 6 chữ số)',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? 'Mã PIN phải gồm đúng 6 chữ số' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final autoLockService = Provider.of<AutoLockService>(context, listen: false);
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/api/user/reset-pin'),
                    headers: authProvider.authHeaders,
                    body: jsonEncode({
                      'password': passwordController.text.trim(),
                      'newPin': newPinController.text.trim(),
                    }),
                  );
                  if (response.statusCode == 200) {
                    navigator.pop();
                    autoLockService.unlock();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đặt lại PIN & mở khóa thành công!'), backgroundColor: Colors.green),
                    );
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Đặt lại PIN thất bại'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text('Mở khóa & Lưu PIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.purpleAccent),
              const SizedBox(height: 20),
              const Text(
                'Ứng dụng đã bị khóa tự động',
                style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập Mã PIN bảo mật để mở khóa và tiếp tục sử dụng',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showUnlockDialog,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Mở khóa Ví'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showForgotPinDialogOnLock,
                    icon: const Icon(Icons.key),
                    label: const Text('Quên PIN'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final autoLockService = Provider.of<AutoLockService>(context, listen: false);
                  autoLockService.unlock();
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                label: const Text('Đăng xuất khỏi ứng dụng', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
