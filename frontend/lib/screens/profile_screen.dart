import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _pinFormKey = GlobalKey<FormState>();

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();

  bool _isLoadingPassword = false;
  bool _isLoadingPin = false;
  bool _notificationsEnabled = true;

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoadingPassword = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/user/update-password'),
        headers: authProvider.authHeaders,
        body: jsonEncode({
          'currentPassword': _passwordController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localeProvider.getText('update_password')} thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        _passwordController.clear();
        _newPasswordController.clear();
      } else {
        final resData = jsonDecode(response.body);
        throw Exception(resData['error'] ?? 'Cập nhật thất bại');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  Future<void> _updatePin() async {
    if (!_pinFormKey.currentState!.validate()) return;

    setState(() => _isLoadingPin = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/user/update-pin'),
        headers: authProvider.authHeaders,
        body: jsonEncode({
          'currentPin': _currentPinController.text.trim(),
          'newPin': _newPinController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đổi Mã PIN thành công!'), backgroundColor: Colors.green),
        );
        _currentPinController.clear();
        _newPinController.clear();
      } else {
        final resData = jsonDecode(response.body);
        throw Exception(resData['error'] ?? 'Không thể đổi PIN');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPin = false);
    }
  }

  void _showForgotPinDialog() {
    final resetPasswordController = TextEditingController();
    final resetNewPinController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Đặt lại Mã PIN (Quên PIN)', style: TextStyle(color: Colors.white)),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nhập mật khẩu tài khoản để xác thực và tạo Mã PIN mới:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: resetPasswordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu đăng nhập',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: resetNewPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mã PIN mới (bắt buộc 6 chữ số)',
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
              if (resetFormKey.currentState!.validate()) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/api/user/reset-pin'),
                    headers: authProvider.authHeaders,
                    body: jsonEncode({
                      'password': resetPasswordController.text.trim(),
                      'newPin': resetNewPinController.text.trim(),
                    }),
                  );
                  navigator.pop();
                  if (response.statusCode == 200) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đặt lại Mã PIN thành công!'), backgroundColor: Colors.green),
                    );
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Đặt lại PIN thất bại'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Xác nhận đặt lại PIN', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Security Section
            Text(
              localeProvider.getText('account_security'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Card 1: Change Password
            Card(
              color: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          Text(
                            localeProvider.getText('update_password'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: localeProvider.getText('current_password'),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => v!.isEmpty ? localeProvider.getText('required') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: localeProvider.getText('new_password'),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => (v?.length ?? 0) < 6 ? 'Tối thiểu 6 ký tự' : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoadingPassword ? null : _updatePassword,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                          child: _isLoadingPassword
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(localeProvider.getText('update_password'), style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Card 2: Manage PIN (Change & Forgot PIN)
            Card(
              color: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _pinFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pin_outlined, color: Colors.cyanAccent),
                              const SizedBox(width: 8),
                              Text(
                                localeProvider.getText('change_pin'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _showForgotPinDialog,
                            child: Text(
                              localeProvider.getText('forgot_pin'),
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _currentPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: localeProvider.getText('current_pin'),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: localeProvider.getText('new_pin'),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? localeProvider.getText('pin_required') : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoadingPin ? null : _updatePin,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          child: _isLoadingPin
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(localeProvider.getText('update_pin'), style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Preferences Section
            Text(
              localeProvider.getText('preferences'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: Text(localeProvider.getText('enable_notifications'), style: const TextStyle(color: Colors.white)),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            DropdownButtonFormField<String>(
              initialValue: localeProvider.isVietnamese ? 'vi' : 'en',
              dropdownColor: const Color(0xFF16213E),
              decoration: InputDecoration(
                labelText: localeProvider.getText('language'),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) {
                if (val != null) {
                  localeProvider.setLocale(val);
                }
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                icon: const Icon(Icons.logout),
                label: Text(localeProvider.getText('logout')),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
