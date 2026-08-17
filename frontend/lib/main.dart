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
  final _passwordController = TextEditingController();
  final _newPinController = TextEditingController();
  GlobalKey<FormState> _forgotFormKey = GlobalKey<FormState>();

  bool _isVerifying = false;
  String? _errorMessage;

  bool _showForgotPinOverlay = false;
  bool _isForgotSubmitting = false;
  String? _forgotDialogError;

  @override
  void dispose() {
    _pinController.dispose();
    _passwordController.dispose();
    _newPinController.dispose();
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

  void _handleLogout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final autoLockService = Provider.of<AutoLockService>(context, listen: false);
    autoLockService.unlock();
    authProvider.logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Widget _buildForgotPinOverlay() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Colors.cyanAccent, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localeProvider.isVietnamese ? 'Mở Khóa Qua Mật Khẩu' : 'Unlock Via Password',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: _forgotFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localeProvider.getText('enter_password_to_reset_pin'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('account_password'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? localeProvider.getText('current_pass_required') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('new_pin'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v?.trim() ?? '')
                        ? localeProvider.getText('pin_required')
                        : null,
                  ),
                  if (_forgotDialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _forgotDialogError!,
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
              onPressed: () {
                setState(() {
                  _showForgotPinOverlay = false;
                  _passwordController.clear();
                  _newPinController.clear();
                  _forgotDialogError = null;
                });
              },
              child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: _isForgotSubmitting
                  ? null
                  : () async {
                      if (_forgotFormKey.currentState!.validate()) {
                        setState(() {
                          _isForgotSubmitting = true;
                          _forgotDialogError = null;
                        });
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final autoLockService = Provider.of<AutoLockService>(context, listen: false);

                        try {
                          final response = await http.post(
                            Uri.parse('${ApiConfig.baseUrl}/api/user/reset-pin'),
                            headers: authProvider.authHeaders,
                            body: jsonEncode({
                              'password': _passwordController.text.trim(),
                              'newPin': _newPinController.text.trim(),
                            }),
                          );

                          if (response.statusCode == 200) {
                            setState(() {
                              _showForgotPinOverlay = false;
                              _passwordController.clear();
                              _newPinController.clear();
                              _forgotDialogError = null;
                            });
                            autoLockService.unlock();
                            await authProvider.fetchUserProfile();
                            final currentCtx = navigatorKey.currentContext ?? context;
                            if (currentCtx.mounted) {
                              ScaffoldMessenger.of(currentCtx).showSnackBar(
                                SnackBar(
                                  content: Text(localeProvider.getText('pin_reset_success')),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            final resData = jsonDecode(response.body);
                            setState(() {
                              _forgotDialogError = resData['error'] ?? (localeProvider.isVietnamese ? 'Mật khẩu không chính xác hoặc đặt lại PIN thất bại' : 'Incorrect password or PIN reset failed');
                            });
                          }
                        } catch (e) {
                          setState(() {
                            _forgotDialogError = localeProvider.isVietnamese ? 'Lỗi kết nối máy chủ' : 'Server connection error';
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isForgotSubmitting = false;
                            });
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: _isForgotSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(localeProvider.isVietnamese ? 'Mở khóa & Lưu PIN' : 'Unlock & Save PIN', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Stack(
      children: [
        Scaffold(
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
                    Text(
                      localeProvider.getText('app_locked_title'),
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localeProvider.getText('enter_pin_to_unlock'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                            : Text(localeProvider.getText('unlock_button'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _forgotFormKey = GlobalKey<FormState>();
                              _showForgotPinOverlay = true;
                              _forgotDialogError = null;
                            });
                          },
                          icon: const Icon(Icons.key_outlined, size: 18, color: Colors.cyanAccent),
                          label: Text(localeProvider.getText('forgot_pin'), style: const TextStyle(color: Colors.cyanAccent)),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                          label: Text(localeProvider.getText('logout'), style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showForgotPinOverlay) _buildForgotPinOverlay(),
      ],
    );
  }
}
