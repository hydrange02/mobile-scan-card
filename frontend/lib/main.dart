import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'services/autolock_service.dart';
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
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (autoLockService.isLocked) const LockOverlayScreen(),
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

  void _showUnlockDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () {
              final autoLockService = Provider.of<AutoLockService>(context, listen: false);
              final pin = _pinController.text.trim();
              if (pin.length >= 4) {
                Navigator.pop(ctx);
                autoLockService.unlock();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập mã PIN từ 4-6 chữ số'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Mở khóa'),
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
              ElevatedButton.icon(
                onPressed: _showUnlockDialog,
                icon: const Icon(Icons.lock_open),
                label: const Text('Mở khóa Ví'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
