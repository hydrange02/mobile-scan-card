import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    if (!_passwordFormKey.currentState!.validate()) return;

    if (_passwordController.text.trim() == _newPasswordController.text.trim()) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới không được trùng với mật khẩu hiện tại!'), backgroundColor: Colors.orangeAccent),
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
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${localeProvider.getText('update_password')} thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        _passwordController.clear();
        _newPasswordController.clear();
      } else {
        final resData = jsonDecode(response.body);
        throw Exception(resData['error'] ?? 'Cập nhật mật khẩu thất bại');
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  Future<void> _updatePin() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_pinFormKey.currentState!.validate()) return;

    if (_currentPinController.text.trim().isNotEmpty &&
        _currentPinController.text.trim() == _newPinController.text.trim()) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Mã PIN mới không được trùng với Mã PIN hiện tại!'), backgroundColor: Colors.orangeAccent),
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
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
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
        throw Exception(resData['error'] ?? 'Không thể cập nhật Mã PIN');
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPin = false);
    }
  }

  void _showForgotPinDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final resetPasswordController = TextEditingController();
    final resetNewPinController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text('Đặt lại Mã PIN (Quên PIN)', style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nhập mật khẩu tài khoản để xác thực và tạo Mã PIN mới:',
                style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: resetPasswordController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu đăng nhập',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: resetNewPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Mã PIN mới (bắt buộc 6 chữ số)',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
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
            child: TextStyle(color: themeProvider.subtitleColor) == TextStyle(color: Colors.white70)
                ? const Text('Hủy', style: TextStyle(color: Colors.white54))
                : const Text('Hủy', style: TextStyle(color: Colors.black54)),
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
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đặt lại Mã PIN thành công!'), backgroundColor: Colors.green),
                    );
                    await authProvider.fetchUserProfile();
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Đặt lại Mã PIN thất bại'), backgroundColor: Colors.redAccent),
                    );
                  }
                } catch (e) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Xác Nhận Đặt Lại PIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDobForDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final s = raw.trim();
    if (RegExp(r'^\d{1,2}\/\d{1,2}\/\d{4}$').hasMatch(s)) {
      final parts = s.split('/');
      final d = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$d/$m/${parts[2]}';
    }
    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}').hasMatch(s)) {
      final datePart = s.split('T')[0];
      final parts = datePart.split('-');
      if (parts.length == 3) {
        final y = parts[0];
        final m = parts[1].padLeft(2, '0');
        final d = parts[2].padLeft(2, '0');
        return '$d/$m/$y';
      }
    }
    if (RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(s)) {
      final parts = s.split('-');
      final d = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$d/$m/${parts[2]}';
    }
    return s;
  }

  bool _isValidDob(String? input) {
    if (input == null || input.trim().isEmpty) return true;
    final s = input.trim();
    if (RegExp(r'^\d{1,2}\/\d{1,2}\/\d{4}$').hasMatch(s)) {
      final parts = s.split('/');
      final day = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final year = int.tryParse(parts[2]) ?? 0;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1900 && year <= DateTime.now().year) {
        return true;
      }
    }
    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}').hasMatch(s)) {
      final datePart = s.split('T')[0];
      final parts = datePart.split('-');
      final year = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2]) ?? 0;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1900 && year <= DateTime.now().year) {
        return true;
      }
    }
    if (RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(s)) {
      final parts = s.split('-');
      final day = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final year = int.tryParse(parts[2]) ?? 0;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1900 && year <= DateTime.now().year) {
        return true;
      }
    }
    return false;
  }

  void _showEditProfileDialog(AuthProvider authProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final user = authProvider.user;
    final fullNameController = TextEditingController(text: user?['fullName']?.toString() ?? '');
    final usernameController = TextEditingController(text: user?['username']?.toString() ?? '');
    final phoneController = TextEditingController(text: user?['phone']?.toString() ?? '');
    final addressController = TextEditingController(text: user?['address']?.toString() ?? '');
    final dobController = TextEditingController(text: _formatDobForDisplay(user?['dob']?.toString()));
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: themeProvider.dialogBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.cyanAccent, size: 28),
              const SizedBox(width: 8),
              Text(localeProvider.getText('update_profile_title'), style: TextStyle(color: themeProvider.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    style: TextStyle(color: themeProvider.textColor),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('full_name_label'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return localeProvider.getText('required');
                      final clean = v.trim();
                      if (clean.length < 2 || clean.length > 50) return localeProvider.getText('full_name_label');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameController,
                    style: TextStyle(color: themeProvider.textColor),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('username_label'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return localeProvider.getText('required');
                      final clean = v.trim();
                      if (clean.length < 3 || clean.length > 30) return localeProvider.getText('username_label');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: themeProvider.textColor),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                    ],
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('phone_label'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final clean = v.trim();
                      if (!RegExp(r'^(\+84|0)[35789][0-9]{8}$').hasMatch(clean)) {
                        return localeProvider.getText('phone_invalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    style: TextStyle(color: themeProvider.textColor),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('address_label'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dobController,
                    readOnly: true,
                    style: TextStyle(color: themeProvider.textColor),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('dob_label'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      DateTime initialPickerDate = DateTime(2000, 1, 1);
                      if (dobController.text.isNotEmpty && _isValidDob(dobController.text)) {
                        final parts = dobController.text.split('/');
                        if (parts.length == 3) {
                          final d = int.tryParse(parts[0]);
                          final m = int.tryParse(parts[1]);
                          final y = int.tryParse(parts[2]);
                          if (d != null && m != null && y != null) {
                            initialPickerDate = DateTime(y, m, d);
                          }
                        }
                      }
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialPickerDate,
                        firstDate: DateTime(1920),
                        lastDate: now,
                      );
                      if (picked != null) {
                        final day = picked.day.toString().padLeft(2, '0');
                        final month = picked.month.toString().padLeft(2, '0');
                        final year = picked.year;
                        dobController.text = '$day/$month/$year';
                      }
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!_isValidDob(v.trim())) {
                        return localeProvider.getText('dob_invalid');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.grey)),
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
                              ScaffoldMessenger.of(currentCtx).hideCurrentSnackBar();
                              ScaffoldMessenger.of(currentCtx).showSnackBar(
                                SnackBar(content: Text(localeProvider.getText('update_profile_success')), backgroundColor: Colors.green),
                              );
                            }
                          } else {
                            final resData = jsonDecode(response.body);
                            final currentCtx = navigatorKey.currentContext;
                            if (currentCtx != null && currentCtx.mounted) {
                              ScaffoldMessenger.of(currentCtx).hideCurrentSnackBar();
                              ScaffoldMessenger.of(currentCtx).showSnackBar(
                                SnackBar(content: Text(resData['error'] ?? 'Cập nhật thất bại. Vui lòng kiểm tra lại!'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        } catch (e) {
                          final currentCtx = navigatorKey.currentContext;
                          if (currentCtx != null && currentCtx.mounted) {
                            ScaffoldMessenger.of(currentCtx).hideCurrentSnackBar();
                            ScaffoldMessenger.of(currentCtx).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
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
                  : Text(localeProvider.getText('save_changes'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      color: themeProvider.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: themeProvider.cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
                      gradient: LinearGradient(colors: [themeProvider.accentColor, themeProvider.primaryColor]),
                      border: Border.all(color: themeProvider.cardBorderColor, width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (authProvider.user?['fullName']?.toString().isNotEmpty == true)
                              ? authProvider.user!['fullName'].toString()
                              : (authProvider.user?['username'] ?? localeProvider.getText('user_default_name')),
                          style: TextStyle(color: themeProvider.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authProvider.user?['email'] ?? 'user@nfcwallet.com',
                          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
                        ),
                        if (authProvider.user?['phone']?.toString().isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${localeProvider.isVietnamese ? "SĐT" : "Tel"}: ${authProvider.user!['phone']}',
                            style: TextStyle(color: themeProvider.accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded, color: themeProvider.accentColor, size: 28),
                    tooltip: localeProvider.getText('edit_profile_tooltip'),
                    onPressed: () => _showEditProfileDialog(authProvider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Header Security Section
            Text(
              localeProvider.getText('account_security'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 16),

            // Card 1: Change Password
            Card(
              color: themeProvider.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeProvider.cardBorderColor)),
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
                            style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        style: TextStyle(color: themeProvider.textColor),
                        decoration: InputDecoration(
                          labelText: localeProvider.getText('current_password'),
                          labelStyle: TextStyle(color: themeProvider.subtitleColor),
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
                        style: TextStyle(color: themeProvider.textColor),
                        decoration: InputDecoration(
                          labelText: localeProvider.getText('new_password'),
                          labelStyle: TextStyle(color: themeProvider.subtitleColor),
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
                              : Text(localeProvider.getText('update_password'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              color: themeProvider.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeProvider.cardBorderColor)),
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
                                style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 16),
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
                      if (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null)) ...[
                        TextFormField(
                          controller: _currentPinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: TextStyle(color: themeProvider.textColor),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: localeProvider.getText('current_pin'),
                            labelStyle: TextStyle(color: themeProvider.subtitleColor),
                            border: const OutlineInputBorder(),
                            suffixIcon: TextButton(
                              onPressed: _showForgotPinDialog,
                              child: const Text('Quên?', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                            ),
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
                        style: TextStyle(color: themeProvider.textColor),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: (authProvider.user?['hasPin'] == true || (authProvider.user?['hasPin'] != false && authProvider.user?['pin'] != null))
                              ? localeProvider.getText('new_pin')
                              : 'Mã PIN 6 chữ số',
                          labelStyle: TextStyle(color: themeProvider.subtitleColor),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: Text(localeProvider.getText('enable_notifications'), style: TextStyle(color: themeProvider.textColor)),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            DropdownButtonFormField<String>(
              initialValue: localeProvider.isVietnamese ? 'vi' : 'en',
              dropdownColor: themeProvider.dialogBgColor,
              decoration: InputDecoration(
                labelText: localeProvider.getText('language'),
                labelStyle: TextStyle(color: themeProvider.subtitleColor),
              ),
              items: [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt', style: TextStyle(color: themeProvider.textColor))),
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: themeProvider.textColor))),
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
