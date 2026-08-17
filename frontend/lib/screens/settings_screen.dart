import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_config.dart';
import '../services/autolock_service.dart';
import '../services/backup_service.dart';
import '../services/haptic_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _importController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.fetchUserProfile();
    } catch (_) {}
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

  void _showEditProfileDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final nameController = TextEditingController(text: (user?['fullName'] ?? '').toString());
    final phoneController = TextEditingController(text: (user?['phone'] ?? '').toString());
    final addressController = TextEditingController(text: (user?['address'] ?? '').toString());
    final dobController = TextEditingController(text: _formatDobForDisplay((user?['dob'] ?? '').toString()));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text(localeProvider.getText('update_profile_title'), style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final response = await http.put(
                    Uri.parse('${ApiConfig.baseUrl}/api/user/update-profile'),
                    headers: authProvider.authHeaders,
                    body: json.encode({
                      'fullName': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'address': addressController.text.trim(),
                      'dob': dobController.text.trim(),
                    }),
                  );
                  if (response.statusCode == 200 && mounted) {
                    HapticService.successFeedback();
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(localeProvider.getText('update_profile_success')), backgroundColor: Colors.green),
                    );
                    await authProvider.fetchUserProfile();
                  } else {
                    if (!mounted) return;
                    final resData = json.decode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Cập nhật thất bại. Vui lòng kiểm tra lại!'), backgroundColor: Colors.redAccent),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: Text(localeProvider.getText('save_changes'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    HapticService.selectionFeedback();
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text(localeProvider.getText('change_login_pass'), style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPassController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: localeProvider.getText('current_password'),
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? localeProvider.getText('current_pass_required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: localeProvider.getText('new_password'),
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().length ?? 0) < 6 ? localeProvider.getText('new_pass_min_length') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
            child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                if (currentPassController.text.trim() == newPassController.text.trim()) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text(localeProvider.isVietnamese ? 'Mật khẩu mới không được trùng với mật khẩu hiện tại!' : 'New password cannot match current password!'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }

                try {
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/api/user/update-password'),
                    headers: authProvider.authHeaders,
                    body: jsonEncode({
                      'currentPassword': currentPassController.text.trim(),
                      'newPassword': newPassController.text.trim(),
                    }),
                  );
                  if (response.statusCode == 200) {
                    if (navigator.canPop()) navigator.pop();
                    HapticService.successFeedback();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(content: Text(localeProvider.getText('pass_updated_success')), backgroundColor: Colors.green),
                      );
                    });
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Failed'), backgroundColor: Colors.redAccent),
                    );
                  }
                } catch (e) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: Text(localeProvider.getText('update_password'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    HapticService.selectionFeedback();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final bool hasPin = user?['hasPin'] == true || (user?['hasPin'] != false && user?['pin'] != null);

    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text(hasPin ? localeProvider.getText('change_pin') : localeProvider.getText('create_pin'), style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPin) ...[
                TextFormField(
                  controller: currentPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(color: themeProvider.textColor),
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: localeProvider.getText('current_pin'),
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                    suffixIcon: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showForgotPinDialog();
                      },
                      child: Text(localeProvider.isVietnamese ? 'Quên?' : 'Forgot?', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? localeProvider.getText('pin_required') : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: localeProvider.getText('new_pin'),
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? localeProvider.getText('pin_required') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
            child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                if (hasPin && currentPinController.text.trim() == newPinController.text.trim()) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text(localeProvider.isVietnamese ? 'Mã PIN mới không được trùng với PIN hiện tại!' : 'New PIN cannot match current PIN!'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }

                try {
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/api/user/update-pin'),
                    headers: authProvider.authHeaders,
                    body: jsonEncode({
                      'currentPin': currentPinController.text.trim(),
                      'newPin': newPinController.text.trim(),
                    }),
                  );
                  if (response.statusCode == 200) {
                    if (navigator.canPop()) navigator.pop();
                    HapticService.successFeedback();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(localeProvider.getText('pin_updated_success')),
                          backgroundColor: Colors.green,
                        ),
                      );
                    });
                    await authProvider.fetchUserProfile();
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Failed'), backgroundColor: Colors.redAccent),
                    );
                  }
                } catch (e) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(hasPin ? localeProvider.getText('update_pin') : localeProvider.getText('create_pin'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showForgotPinDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    HapticService.selectionFeedback();
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text(localeProvider.getText('forgot_pin'), style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localeProvider.getText('enter_password_to_reset_pin'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13)),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: localeProvider.getText('account_password'),
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? localeProvider.getText('current_pass_required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: localeProvider.getText('new_pin'),
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? localeProvider.getText('pin_required') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
            child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
                    if (navigator.canPop()) navigator.pop();
                    HapticService.successFeedback();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(content: Text(localeProvider.getText('pin_reset_success')), backgroundColor: Colors.green),
                      );
                    });
                    await authProvider.fetchUserProfile();
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Reset PIN failed'), backgroundColor: Colors.redAccent),
                    );
                  }
                } catch (e) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: Text(localeProvider.getText('reset_pin'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context, String encryptedData) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text('Mã Sao Lưu Ví NFC', style: TextStyle(color: themeProvider.textColor)),
        content: SelectableText(
          encryptedData,
          style: TextStyle(color: themeProvider.textColor, fontSize: 12),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: encryptedData));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép mã sao lưu vào bộ nhớ tạm!'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Sao chép mã', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text('Khôi Phục Thẻ Từ Sao Lưu', style: TextStyle(color: themeProvider.textColor)),
        content: TextField(
          controller: _importController,
          maxLines: 4,
          style: TextStyle(color: themeProvider.textColor),
          decoration: InputDecoration(
            hintText: 'Dán đoạn mã sao lưu đã mã hóa vào đây...',
            hintStyle: TextStyle(color: themeProvider.subtitleColor),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _importController.text.trim();
              if (text.isEmpty) return;
              final cards = BackupService.importEncryptedCards(text);
              Navigator.pop(ctx);
              if (cards != null) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Khôi phục thành công ${cards.length} thẻ!'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mã sao lưu không hợp lệ hoặc bị lỗi mã hóa!'), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Khôi phục', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final autoLockService = Provider.of<AutoLockService>(context);

    final user = authProvider.user;

    return Container(
      color: themeProvider.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------------
            // 1. ACCOUNT PROFILE SUMMARY CARD
            // -------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeProvider.cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: themeProvider.accentColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user?['fullName'] ?? user?['username'] ?? 'Người dùng').toString(),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (user?['email'] ?? '').toString(),
                          style: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
                        ),
                        if (user?['phone'] != null && user!['phone'].toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${localeProvider.isVietnamese ? "SĐT" : "Tel"}: ${user['phone']}',
                            style: TextStyle(fontSize: 12, color: themeProvider.accentColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: themeProvider.accentColor),
                    onPressed: _showEditProfileDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -------------------------------------------------------------
            // 2. ACCOUNT SECURITY & AUTHENTICATION
            // -------------------------------------------------------------
            Text(
              localeProvider.getText('account_security'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 10),

            Card(
              color: themeProvider.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeProvider.cardBorderColor)),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.lock, color: Colors.white, size: 18),
                    ),
                    title: Text(localeProvider.getText('update_password'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text(localeProvider.getText('update_pass_sub'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: themeProvider.subtitleColor),
                    onTap: _showChangePasswordDialog,
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                      child: const Icon(Icons.pin, color: Colors.white, size: 18),
                    ),
                    title: Text(
                      (user?['hasPin'] == true || (user?['hasPin'] != false && user?['pin'] != null))
                          ? localeProvider.getText('change_pin')
                          : localeProvider.getText('create_pin'),
                      style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      (user?['hasPin'] == true || (user?['hasPin'] != false && user?['pin'] != null))
                          ? localeProvider.getText('change_pin_sub')
                          : localeProvider.getText('create_pin_sub'),
                      style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right, color: themeProvider.subtitleColor),
                    onTap: _showChangePinDialog,
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.help_center, color: Colors.white, size: 18),
                    ),
                    title: Text(localeProvider.getText('forgot_pin'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text(localeProvider.getText('forgot_pin_sub'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: themeProvider.subtitleColor),
                    onTap: _showForgotPinDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------------------------------------------
            // 3. APP SETTINGS & PREFERENCES
            // -------------------------------------------------------------
            Text(
              localeProvider.getText('app_config'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 10),

            Card(
              color: themeProvider.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeProvider.cardBorderColor)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dark_mode, color: Colors.purpleAccent),
                    title: Text(localeProvider.getText('dark_mode'), style: TextStyle(color: themeProvider.textColor)),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (val) {
                        HapticService.selectionFeedback();
                        themeProvider.toggleTheme(val);
                      },
                    ),
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.blueAccent),
                    title: Text(localeProvider.getText('language'), style: TextStyle(color: themeProvider.textColor)),
                    subtitle: Text(localeProvider.isVietnamese ? 'Tiếng Việt' : 'English', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
                    trailing: DropdownButton<String>(
                      value: localeProvider.locale.languageCode,
                      dropdownColor: themeProvider.dialogBgColor,
                      style: TextStyle(color: themeProvider.textColor),
                      items: [
                        DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: themeProvider.textColor))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          HapticService.selectionFeedback();
                          localeProvider.setLocale(val);
                        }
                      },
                    ),
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: const Icon(Icons.attach_money, color: Colors.greenAccent),
                    title: Text(localeProvider.getText('currency_unit'), style: TextStyle(color: themeProvider.textColor)),
                    subtitle: Text(
                      localeProvider.isVND ? 'VND (₫)' : 'USD (\$)',
                      style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: localeProvider.currency,
                      dropdownColor: themeProvider.dialogBgColor,
                      style: TextStyle(color: themeProvider.textColor),
                      items: [
                        DropdownMenuItem(value: 'VND', child: Text(localeProvider.getText('currency_vnd'), style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 'USD', child: Text(localeProvider.getText('currency_usd'), style: TextStyle(color: themeProvider.textColor))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          HapticService.selectionFeedback();
                          localeProvider.setCurrency(val);
                        }
                      },
                    ),
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                    title: Text(localeProvider.getText('auto_lock'), style: TextStyle(color: themeProvider.textColor)),
                    subtitle: Text(
                      autoLockService.autoLockSeconds == 0
                          ? (localeProvider.isVietnamese ? 'Tắt' : 'Disabled')
                          : autoLockService.autoLockSeconds == 60
                              ? (localeProvider.isVietnamese ? '1 phút' : '1 minute')
                              : autoLockService.autoLockSeconds == 300
                                  ? (localeProvider.isVietnamese ? '5 phút (Mặc định)' : '5 minutes (Default)')
                                  : autoLockService.autoLockSeconds == 600
                                      ? (localeProvider.isVietnamese ? '10 phút' : '10 minutes')
                                      : '${autoLockService.autoLockSeconds} s',
                      style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                    ),
                    trailing: DropdownButton<int>(
                      value: [0, 60, 300, 600].contains(autoLockService.autoLockSeconds)
                          ? autoLockService.autoLockSeconds
                          : 300,
                      dropdownColor: themeProvider.dialogBgColor,
                      style: TextStyle(color: themeProvider.textColor),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(localeProvider.isVietnamese ? 'Tắt' : 'Disabled', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 60, child: Text(localeProvider.isVietnamese ? '1 phút' : '1 min', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 300, child: Text(localeProvider.isVietnamese ? '5 phút' : '5 mins', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 600, child: Text(localeProvider.isVietnamese ? '10 phút' : '10 mins', style: TextStyle(color: themeProvider.textColor))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          HapticService.selectionFeedback();
                          autoLockService.setAutoLockSeconds(val);
                        }
                      },
                    ),
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: const Icon(Icons.security, color: Colors.green),
                    title: Text(localeProvider.getText('export_backup'), style: TextStyle(color: themeProvider.textColor)),
                    subtitle: Text(localeProvider.isVietnamese ? 'Mã hóa AES-256 dữ liệu ví' : 'AES-256 wallet data encryption', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
                    onTap: () {
                      HapticService.successFeedback();
                      final sampleCards = [
                        {'id': 1, 'cardName': 'Visa Gold', 'cardNumber': '4111222233334444'},
                        {'id': 2, 'cardName': 'Mastercard Platinum', 'cardNumber': '5500000000000004'}
                      ];
                      final encrypted = BackupService.exportEncryptedCards(sampleCards);
                      _showBackupDialog(context, encrypted);
                    },
                  ),
                  Divider(color: themeProvider.cardBorderColor, height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.teal),
                    title: Text(localeProvider.getText('import_backup'), style: TextStyle(color: themeProvider.textColor)),
                    subtitle: Text(localeProvider.isVietnamese ? 'Khôi phục thẻ từ đoạn mã đã sao lưu' : 'Restore cards from backup payload', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
                    onTap: () {
                      HapticService.selectionFeedback();
                      _showImportDialog(context);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final autoLockService = Provider.of<AutoLockService>(context, listen: false);
                  autoLockService.unlock();
                  authProvider.logout();
                  navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                },
                icon: const Icon(Icons.logout),
                label: Text(localeProvider.getText('logout')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
