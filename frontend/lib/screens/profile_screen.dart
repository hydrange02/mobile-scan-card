import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_config.dart';
import '../services/autolock_service.dart';
import '../main.dart';

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

    if (_passwordController.text.trim() == _newPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới không được trùng với mật khẩu hiện tại!'), backgroundColor: Colors.red),
      );
      return;
    }

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

    if (_currentPinController.text.trim().isNotEmpty &&
        _currentPinController.text.trim() == _newPinController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã PIN mới không được trùng với Mã PIN hiện tại!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoadingPin = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool hasPin = authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null);

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
          SnackBar(
            content: Text(hasPin ? 'Đổi Mã PIN thành công!' : 'Tạo Mã PIN thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        _currentPinController.clear();
        _newPinController.clear();
        await authProvider.fetchUserProfile();
      } else {
        final resData = jsonDecode(response.body);
        throw Exception(resData['error'] ?? 'Không thể cập nhật PIN');
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
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu đăng nhập',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu' : null,
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
            onPressed: () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
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
                  if (response.statusCode == 200) {
                    if (navigator.canPop()) navigator.pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đặt lại Mã PIN thành công!'), backgroundColor: Colors.green),
                      );
                    });
                    await authProvider.fetchUserProfile();
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Xác nhận đặt lại PIN', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(AuthProvider authProvider) {
    final user = authProvider.user ?? {};
    final fullNameController = TextEditingController(text: user['fullName']?.toString() ?? '');
    final usernameController = TextEditingController(text: user['username']?.toString() ?? '');
    final phoneController = TextEditingController(text: user['phone']?.toString() ?? '');
    final addressController = TextEditingController(text: user['address']?.toString() ?? '');
    final dobController = TextEditingController(text: user['dob']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.cyanAccent, size: 28),
              SizedBox(width: 8),
              Text('Cập Nhật Thông Tin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fullNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập họ và tên' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Tên người dùng (Username)',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập username' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại (10 chữ số)',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final clean = v.trim();
                      if (!RegExp(r'^(\+84|0)[35789][0-9]{8}$').hasMatch(clean)) {
                        return 'Số ĐT không hợp lệ (ví dụ: 0912345678)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dobController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Ngày sinh (DD/MM/YYYY)',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                        setDialogState(() => isSubmitting = true);
                        try {
                          final response = await http.put(
                            Uri.parse('${ApiConfig.baseUrl}/api/user/update-profile'),
                            headers: authProvider.authHeaders,
                            body: jsonEncode({
                              'fullName': fullNameController.text.trim(),
                              'username': usernameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'address': addressController.text.trim(),
                              'dob': dobController.text.trim(),
                            }),
                          );

                          if (response.statusCode == 200) {
                            final navState = navigatorKey.currentState;
                            if (navState != null && navState.canPop()) {
                              navState.pop();
                            }
                            await authProvider.fetchUserProfile();
                            final currentCtx = navigatorKey.currentContext;
                            if (currentCtx != null && currentCtx.mounted) {
                              ScaffoldMessenger.of(currentCtx).showSnackBar(
                                const SnackBar(content: Text('Cập nhật thông tin cá nhân thành công!'), backgroundColor: Colors.green),
                              );
                            }
                          } else {
                            final resData = jsonDecode(response.body);
                            final currentCtx = navigatorKey.currentContext;
                            if (currentCtx != null && currentCtx.mounted) {
                              ScaffoldMessenger.of(currentCtx).showSnackBar(
                                SnackBar(content: Text(resData['error'] ?? 'Cập nhật thất bại'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        } catch (e) {
                          final currentCtx = navigatorKey.currentContext;
                          if (currentCtx != null && currentCtx.mounted) {
                            ScaffoldMessenger.of(currentCtx).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

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
            // User Profile Card Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent]),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.black, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (authProvider.user?['fullName']?.toString().isNotEmpty == true)
                              ? authProvider.user!['fullName'].toString()
                              : (authProvider.user?['username'] ?? 'Người Dùng NFC'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authProvider.user?['email'] ?? 'user@nfcwallet.com',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        if (authProvider.user?['phone']?.toString().isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            'SĐT: ${authProvider.user!['phone']}',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Colors.cyanAccent, size: 28),
                    tooltip: 'Cập nhật thông tin cá nhân',
                    onPressed: () => _showEditProfileDialog(authProvider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? localeProvider.getText('required') : null,
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
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (v) => (v?.trim().length ?? 0) < 6 ? 'Tối thiểu 6 ký tự (không tính khoảng trắng)' : null,
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
                                (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null))
                                    ? localeProvider.getText('change_pin')
                                    : 'Tạo Mã PIN Bảo Mật',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          if (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null))
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
                      if (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null)) ...[
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
                          validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? 'Vui lòng nhập đúng 6 chữ số Mã PIN hiện tại' : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _newPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null))
                              ? localeProvider.getText('new_pin')
                              : 'Mã PIN 6 chữ số',
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
                              : Text(
                                  (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null))
                                      ? localeProvider.getText('update_pin')
                                      : 'Tạo Mã PIN',
                                  style: const TextStyle(color: Colors.white),
                                ),
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
                  final autoLockService = Provider.of<AutoLockService>(context, listen: false);
                  autoLockService.unlock();
                  authProvider.logout();
                  navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
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
