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

  void _showEditProfileDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final nameController = TextEditingController(text: (user?['fullName'] ?? '').toString());
    final phoneController = TextEditingController(text: (user?['phone'] ?? '').toString());
    final addressController = TextEditingController(text: (user?['address'] ?? '').toString());
    final dobController = TextEditingController(text: (user?['dob'] ?? '').toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text('Cập Nhật Thông Tin Cá Nhân', style: TextStyle(color: themeProvider.textColor)),
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
                    labelText: 'Họ và tên đầy đủ',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập họ và tên';
                    final clean = v.trim();
                    if (clean.length < 2 || clean.length > 50) return 'Họ và tên phải từ 2 đến 50 ký tự';
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
                    labelText: 'Số điện thoại (10 chữ số)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final clean = v.trim();
                    if (!RegExp(r'^(\+84|0)[35789][0-9]{8}$').hasMatch(clean)) {
                      return 'Số điện thoại không hợp lệ (ví dụ: 0912345678)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  style: TextStyle(color: themeProvider.textColor),
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ nhà / Cơ quan',
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
                    labelText: 'Ngày sinh (DD/MM/YYYY)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000, 1, 1),
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
                    if (!RegExp(r'^(0[1-9]|[12][0-9]|3[01])\/(0[1-9]|1[0-2])\/\d{4}$').hasMatch(v.trim())) {
                      return 'Ngày sinh không hợp lệ (định dạng DD/MM/YYYY)';
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
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
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
                      const SnackBar(content: Text('Cập nhật thông tin người dùng thành công!'), backgroundColor: Colors.green),
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
            child: const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    HapticService.selectionFeedback();
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text('Đổi Mật Khẩu Đăng Nhập', style: TextStyle(color: themeProvider.textColor)),
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
                  labelText: 'Mật khẩu hiện tại',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().length ?? 0) < 6 ? 'Mật khẩu tối thiểu 6 ký tự (không tính khoảng trắng)' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
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
                    const SnackBar(content: Text('Mật khẩu mới không được trùng với mật khẩu hiện tại!'), backgroundColor: Colors.orangeAccent),
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
                        const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green),
                      );
                    });
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Đổi mật khẩu thất bại'), backgroundColor: Colors.redAccent),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
        title: Text(hasPin ? 'Đổi Mã PIN Bảo Mật' : 'Tạo Mã PIN Bảo Mật', style: TextStyle(color: themeProvider.textColor)),
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
                    labelText: 'Mã PIN hiện tại (6 chữ số)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? 'Mã PIN hiện tại phải gồm đúng 6 chữ số' : null,
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
                  labelText: hasPin ? 'Mã PIN mới (bắt buộc 6 chữ số)' : 'Mã PIN 6 chữ số',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? 'Mã PIN mới phải gồm đúng 6 chữ số' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            },
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                if (hasPin && currentPinController.text.trim() == newPinController.text.trim()) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Mã PIN mới không được trùng với Mã PIN hiện tại!'), backgroundColor: Colors.orangeAccent),
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
                          content: Text(hasPin ? 'Đổi Mã PIN thành công!' : 'Tạo Mã PIN thành công!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    });
                    await authProvider.fetchUserProfile();
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Thao tác thất bại'), backgroundColor: Colors.redAccent),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(hasPin ? 'Đổi Mã PIN' : 'Tạo Mã PIN', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showForgotPinDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    HapticService.selectionFeedback();
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text('Đặt lại Mã PIN (Quên PIN)', style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nhập mật khẩu tài khoản để xác thực:', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13)),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                style: TextStyle(color: themeProvider.textColor),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu tài khoản',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu' : null,
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
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
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
                        const SnackBar(content: Text('Đặt lại Mã PIN thành công!'), backgroundColor: Colors.green),
                      );
                    });
                    await authProvider.fetchUserProfile();
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Đặt lại PIN thất bại'), backgroundColor: Colors.redAccent),
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
            child: const Text('Xác nhận đặt lại PIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                            'SĐT: ${user['phone']}',
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
                    subtitle: Text('Đổi mật khẩu tài khoản đăng nhập', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
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
                          : 'Tạo Mã PIN Bảo Mật',
                      style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      (user?['hasPin'] == true || (user?['hasPin'] != false && user?['pin'] != null))
                          ? 'Đổi Mã PIN bảo mật 6 chữ số'
                          : 'Tạo mới Mã PIN 6 chữ số cho tài khoản',
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
                    subtitle: Text('Xác thực qua mật khẩu để tạo PIN mới', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
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
              'Cấu Hình Ứng Dụng',
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
                          ? 'Tắt'
                          : autoLockService.autoLockSeconds == 60
                              ? '1 phút'
                              : autoLockService.autoLockSeconds == 300
                                  ? '5 phút (Mặc định)'
                                  : autoLockService.autoLockSeconds == 600
                                      ? '10 phút'
                                      : '${autoLockService.autoLockSeconds} giây',
                      style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                    ),
                    trailing: DropdownButton<int>(
                      value: [0, 60, 300, 600].contains(autoLockService.autoLockSeconds)
                          ? autoLockService.autoLockSeconds
                          : 300,
                      dropdownColor: themeProvider.dialogBgColor,
                      style: TextStyle(color: themeProvider.textColor),
                      items: [
                        DropdownMenuItem(value: 0, child: Text('Tắt', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 60, child: Text('1 phút', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 300, child: Text('5 phút', style: TextStyle(color: themeProvider.textColor))),
                        DropdownMenuItem(value: 600, child: Text('10 phút', style: TextStyle(color: themeProvider.textColor))),
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
                    subtitle: Text('Mã hóa AES-256 dữ liệu ví', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
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
