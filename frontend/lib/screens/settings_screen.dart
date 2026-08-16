import 'package:flutter/material.dart';
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.fetchUserProfile();
  }

  void _showEditProfileDialog() {
    HapticService.selectionFeedback();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final nameController = TextEditingController(text: (user?['fullName'] ?? '').toString());
    final phoneController = TextEditingController(text: (user?['phone'] ?? '').toString());
    final addressController = TextEditingController(text: (user?['address'] ?? '').toString());
    final dobController = TextEditingController(text: (user?['dob'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Cập Nhật Thông Tin Cá Nhân', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Họ và tên đầy đủ',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ nhà / Cơ quan',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cập nhật thông tin người dùng thành công!'), backgroundColor: Colors.green),
                  );
                  _fetchUserProfile();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Lưu thông tin', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    HapticService.selectionFeedback();
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Đổi Mật Khẩu Đăng Nhập', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPassController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
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
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
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
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green),
                      );
                    });
                  } else {
                    final resData = jsonDecode(response.body);
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Đổi mật khẩu thất bại'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
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
        backgroundColor: const Color(0xFF16213E),
        title: Text(hasPin ? 'Đổi Mã PIN Bảo Mật' : 'Tạo Mã PIN Bảo Mật', style: const TextStyle(color: Colors.white)),
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
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mã PIN hiện tại (6 chữ số)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '') ? 'Mã PIN hiện tại phải gồm đúng 6 chữ số' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: hasPin ? 'Mã PIN mới (bắt buộc 6 chữ số)' : 'Mã PIN 6 chữ số',
                  labelStyle: const TextStyle(color: Colors.white70),
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
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
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
                    messenger.showSnackBar(
                      SnackBar(content: Text(resData['error'] ?? 'Thao tác thất bại'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(hasPin ? 'Đổi Mã PIN' : 'Tạo Mã PIN', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showForgotPinDialog() {
    HapticService.selectionFeedback();
    final passwordController = TextEditingController();
    final newPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Đặt lại Mã PIN (Quên PIN)', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập mật khẩu tài khoản để xác thực:', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập mật khẩu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPinController,
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

  void _showBackupDialog(BuildContext context, String encryptedData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AES Encrypted Backup Data'),
        content: SingleChildScrollView(
          child: SelectableText(encryptedData, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticService.selectionFeedback();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import AES Backup'),
        content: TextField(
          controller: _importController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Paste AES encrypted string here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cards = BackupService.importEncryptedCards(_importController.text.trim());
              Navigator.pop(ctx);
              if (cards != null && cards.isNotEmpty) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                int count = 0;
                for (var card in cards) {
                  try {
                    final res = await http.post(
                      Uri.parse('${ApiConfig.baseUrl}/api/cards'),
                      headers: authProvider.authHeaders,
                      body: json.encode({
                        'cardName': card['cardName'] ?? 'Thẻ Khôi Phục',
                        'cardNumber': card['cardNumber'] ?? '4111222233339999',
                      }),
                    );
                    if (res.statusCode == 201) count++;
                  } catch (_) {}
                }
                if (context.mounted) {
                  HapticService.successFeedback();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully restored $count cards to server!'), backgroundColor: Colors.green),
                  );
                }
              } else {
                if (context.mounted) {
                  HapticService.errorFeedback();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid or corrupted AES backup data.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final autoLockService = Provider.of<AutoLockService>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final user = authProvider.user;
    final String username = (user?['username'] ?? 'User').toString();
    final String email = (user?['email'] ?? 'user@example.com').toString();
    final String fullName = (user?['fullName'] ?? '').toString();
    final String phone = (user?['phone'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // -------------------------------------------------------------
        // 1. INTEGRATED USER PROFILE HEADER CARD
        // -------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8E2DE2).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : username,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        if (phone.isNotEmpty)
                          Text('SĐT: $phone', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.cyanAccent),
                    tooltip: 'Sửa thông tin cá nhân',
                    onPressed: _showEditProfileDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.badge, size: 18),
                  label: const Text('Cập Nhật / Thêm Thông Tin Cá Nhân'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // -------------------------------------------------------------
        // 2. SECURITY BUTTONS SECTION (MODAL POPUP DIALOGS)
        // -------------------------------------------------------------
        const Text(
          'Bảo Mật Tài Khoản & Mã PIN',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),

        Card(
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.lock, color: Colors.white, size: 18),
                ),
                title: Text(localeProvider.getText('update_password'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Đổi mật khẩu tài khoản đăng nhập', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: _showChangePasswordDialog,
              ),
              const Divider(color: Colors.white12, height: 1),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  (user?['hasPin'] == true || (user?['hasPin'] != false && user?['pin'] != null))
                      ? 'Đổi Mã PIN bảo mật 6 chữ số'
                      : 'Tạo mới Mã PIN 6 chữ số cho tài khoản',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: _showChangePinDialog,
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.help_center, color: Colors.white, size: 18),
                ),
                title: Text(localeProvider.getText('forgot_pin'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Xác thực qua mật khẩu để tạo PIN mới', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: _showForgotPinDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // -------------------------------------------------------------
        // 3. APP SETTINGS & PREFERENCES
        // -------------------------------------------------------------
        const Text(
          'Cấu Hình Ứng Dụng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),

        Card(
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode, color: Colors.purpleAccent),
                title: Text(localeProvider.getText('dark_mode'), style: const TextStyle(color: Colors.white)),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (val) {
                    HapticService.selectionFeedback();
                    themeProvider.toggleTheme(val);
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.language, color: Colors.blueAccent),
                title: Text(localeProvider.getText('language'), style: const TextStyle(color: Colors.white)),
                subtitle: Text(localeProvider.isVietnamese ? 'Tiếng Việt' : 'English', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: DropdownButton<String>(
                  value: localeProvider.locale.languageCode,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      HapticService.selectionFeedback();
                      localeProvider.setLocale(val);
                    }
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.greenAccent),
                title: Text(localeProvider.getText('currency_unit'), style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  localeProvider.isVND ? 'VND (₫)' : 'USD (\$)',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: DropdownButton<String>(
                  value: localeProvider.currency,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    DropdownMenuItem(value: 'VND', child: Text(localeProvider.getText('currency_vnd'))),
                    DropdownMenuItem(value: 'USD', child: Text(localeProvider.getText('currency_usd'))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      HapticService.selectionFeedback();
                      localeProvider.setCurrency(val);
                    }
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                title: Text(localeProvider.getText('auto_lock'), style: const TextStyle(color: Colors.white)),
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
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: DropdownButton<int>(
                  value: [0, 60, 300, 600].contains(autoLockService.autoLockSeconds)
                      ? autoLockService.autoLockSeconds
                      : 300,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Tắt')),
                    DropdownMenuItem(value: 60, child: Text('1 phút')),
                    DropdownMenuItem(value: 300, child: Text('5 phút')),
                    DropdownMenuItem(value: 600, child: Text('10 phút')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      HapticService.selectionFeedback();
                      autoLockService.setAutoLockSeconds(val);
                    }
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: Text(localeProvider.getText('export_backup'), style: const TextStyle(color: Colors.white)),
                subtitle: const Text('Mã hóa AES-256 dữ liệu ví', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.teal),
                title: Text(localeProvider.getText('import_backup'), style: const TextStyle(color: Colors.white)),
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
    );
  }
}
