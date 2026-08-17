import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        navigatorKey: navigatorKey,
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
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() => _errorMessage = 'Vui lòng nhập đúng 6 chữ số Mã PIN');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final autoLockService = Provider.of<AutoLockService>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/user/verify-pin'),
        headers: authProvider.authHeaders,
        body: jsonEncode({'pin': pin}),
      );

      if (response.statusCode == 200) {
        _pinController.clear();
        autoLockService.unlock();
      } else {
        final resData = jsonDecode(response.body);
        setState(() {
          _errorMessage = resData['error'] ?? 'Mã PIN không chính xác';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối khi xác thực mã PIN';
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showForgotPinDialogOnLock() {
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final targetContext = navigatorKey.currentContext ?? context;

    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: targetContext,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.lock_reset_rounded, color: Colors.cyanAccent, size: 28),
              SizedBox(width: 8),
              Text('Mở Khóa Qua Mật Khẩu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nhập mật khẩu tài khoản để mở khóa và cài đặt lại Mã PIN mới (6 chữ số):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu đăng nhập',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mã PIN mới (đúng 6 chữ số)',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v?.trim() ?? '')
                        ? 'Mã PIN phải gồm đúng 6 chữ số'
                        : null,
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final autoLockService = Provider.of<AutoLockService>(context, listen: false);

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
                            final navState = navigatorKey.currentState;
                            if (navState != null && navState.canPop()) {
                              navState.pop();
                            }
                            autoLockService.unlock();
                            await authProvider.fetchUserProfile();
                            final currentCtx = navigatorKey.currentContext;
                            if (currentCtx != null && currentCtx.mounted) {
                              ScaffoldMessenger.of(currentCtx).showSnackBar(
                                const SnackBar(content: Text('Đặt lại Mã PIN & mở khóa thành công!'), backgroundColor: Colors.green),
                              );
                            }
                          } else {
                            final resData = jsonDecode(response.body);
                            setDialogState(() {
                              dialogError = resData['error'] ?? 'Mật khẩu không chính xác hoặc đặt lại PIN thất bại';
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            dialogError = 'Lỗi kết nối máy chủ';
                          });
                        } finally {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Mở khóa & Lưu PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final autoLockService = Provider.of<AutoLockService>(context, listen: false);
    autoLockService.unlock();
    authProvider.logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 64, color: Colors.purpleAccent),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ứng dụng đã bị khóa',
                  style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập Mã PIN 6 chữ số của bạn để mở khóa',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // Substantial PIN input field directly on screen
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 10),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.purpleAccent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.purpleAccent, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.length == 6) {
                        _verifyPin();
                      } else if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => _verifyPin(),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: 260,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isVerifying
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Mở khóa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _showForgotPinDialogOnLock,
                      icon: const Icon(Icons.key_outlined, size: 18, color: Colors.cyanAccent),
                      label: const Text('Quên Mã PIN?', style: TextStyle(color: Colors.cyanAccent)),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                      label: const Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
