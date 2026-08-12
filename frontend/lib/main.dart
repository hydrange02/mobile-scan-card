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
          '/profile': (context) => const ProfileScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/reports': (context) => const ReportsScreen(),
          '/help': (context) => const HelpScreen(),
        },
      ),
    );
  }
}

class LockOverlayScreen extends StatelessWidget {
  const LockOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final autoLockService = Provider.of<AutoLockService>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.purpleAccent),
            const SizedBox(height: 20),
            const Text(
              'App Locked Due to Inactivity',
              style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => autoLockService.unlock(),
              icon: const Icon(Icons.lock_open),
              label: const Text('Unlock Wallet'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            ),
          ],
        ),
      ),
    );
  }
}
