import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_config.dart';
import '../services/haptic_service.dart';
import '../services/nfc_service.dart';
import '../services/card_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController(text: '25.00');
  final TextEditingController _noteController = TextEditingController(text: 'Thanh toán NFC 1-Chạm');

  List<dynamic> _cards = [];
  Map<String, dynamic>? _selectedCard;
  bool _isLoadingCards = true;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _amountController.addListener(_onAmountChanged);
    _fetchCards();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCards() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/cards'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final list = json.decode(response.body) as List;
        setState(() {
          _cards = list;
          _isLoadingCards = false;
          if (list.isNotEmpty) {
            _selectedCard = list.firstWhere((c) => c['isDefault'] == true, orElse: () => list.first);
          } else {
            _selectedCard = null;
          }
        });
      } else if (mounted) {
        setState(() {
          _cards = [];
          _selectedCard = null;
          _isLoadingCards = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cards = [];
          _selectedCard = null;
          _isLoadingCards = false;
        });
      }
    }
  }

  Future<void> _simulateNfcScanAndPay() async {
    HapticService.selectionFeedback();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 12),
            Icon(Icons.nfc, size: 70, color: Colors.cyanAccent),
            SizedBox(height: 16),
            Text(
              'Đang Kết Nối Sóng NFC 1-Chạm...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Giữ thiết bị gần thẻ hoặc máy POS...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            SizedBox(height: 20),
            LinearProgressIndicator(color: Colors.cyanAccent),
            SizedBox(height: 12),
          ],
        ),
      ),
    );

    try {
      final nfcRes = await NfcService().readAndValidateTag();
      if (nfcRes.containsKey('error')) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    await _processPaymentApi(method: 'Chạm NFC 1-Chạm');
  }

  Future<void> _processPaymentApi({required String method}) async {
    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc thêm thẻ thanh toán vào ví trước!'), backgroundColor: Colors.red),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền thanh toán hợp lệ (lớn hơn 0)')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/transactions'),
        headers: authProvider.authHeaders,
        body: json.encode({
          'cardId': _selectedCard?['id'],
          'title': _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : 'Thanh toán $method',
          'category': 'Thanh toán $method',
          'amount': amount,
          'isExpense': true,
          'status': 'Success',
        }),
      );

      if (response.statusCode == 201 && mounted) {
        HapticService.successFeedback();
        _showSuccessPaymentDialog(amount, method);
      } else {
        final resBody = json.decode(response.body);
        throw Exception(resBody['error'] ?? 'Giao dịch thất bại');
      }
    } catch (e) {
      if (mounted) {
        HapticService.errorFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thanh toán thất bại: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _verifyPinBeforePayment({
    required String method,
    required VoidCallback onSuccess,
  }) async {
    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc thêm thẻ thanh toán vào ví trước!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (CardUtils.isCardExpired(_selectedCard?['expiryDate'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thẻ này đã hết hạn sử dụng! Vui lòng cập nhật hạn thẻ hoặc chọn thẻ khác.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền thanh toán hợp lệ (lớn hơn 0)')),
      );
      return;
    }

    HapticService.selectionFeedback();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool hasPin = false;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: authProvider.authHeaders,
      );
      if (res.statusCode == 200) {
        final profile = json.decode(res.body);
        hasPin = profile['hasPin'] == true;
      }
    } catch (_) {}

    if (!mounted) return;

    if (!hasPin) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Cần Cập Nhật PIN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Tài khoản của bạn chưa cài đặt Mã PIN bảo mật.\n\nVui lòng cập nhật Mã PIN trong Cài đặt trước khi thực hiện giao dịch thanh toán!',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/settings');
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Cập nhật PIN ngay'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            ),
          ],
        ),
      );
      return;
    }

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final pinController = TextEditingController();
    final pinFormKey = GlobalKey<FormState>();
    bool isVerifyingPin = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.cyanAccent, size: 40),
              const SizedBox(height: 8),
              const Text(
                'Xác Nhận Mã PIN Thanh Toán',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Số tiền: ${localeProvider.formatAmount(amount)} - ${_selectedCard?['cardName'] ?? ''}',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 13),
              ),
            ],
          ),
          content: Form(
            key: pinFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập Mã PIN bảo mật (6 chữ số) để xác nhận thanh toán:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '******',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => (v?.length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v ?? '')
                      ? 'Mã PIN phải gồm đúng 6 chữ số'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showResetPinDialogInPayment();
              },
              child: const Text('Quên PIN?', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy bỏ', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isVerifyingPin
                  ? null
                  : () async {
                      if (pinFormKey.currentState!.validate()) {
                        setModalState(() => isVerifyingPin = true);
                        try {
                          final response = await http.post(
                            Uri.parse('${ApiConfig.baseUrl}/api/user/verify-pin'),
                            headers: authProvider.authHeaders,
                            body: jsonEncode({'pin': pinController.text.trim()}),
                          );
                          if (response.statusCode == 200) {
                            if (context.mounted) Navigator.pop(ctx);
                            onSuccess();
                          } else {
                            final resData = jsonDecode(response.body);
                            if (context.mounted) {
                              HapticService.errorFeedback();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(resData['error'] ?? 'Mã PIN không chính xác'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi xác thực PIN: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        } finally {
                          setModalState(() => isVerifyingPin = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isVerifyingPin
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Xác Nhận & Thanh Toán', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPinDialogInPayment() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nhập mật khẩu đăng nhập để tạo Mã PIN mới (6 chữ số):',
                  style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
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
                  controller: newPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(color: themeProvider.textColor),
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Mã PIN mới (6 chữ số)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) != 6 || !RegExp(r'^\d+$').hasMatch(v?.trim() ?? '') ? 'Mã PIN phải gồm đúng 6 chữ số' : null,
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
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
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
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đặt lại Mã PIN thành công! Bạn có thể sử dụng PIN mới để thanh toán.'), backgroundColor: Colors.green),
                    );
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text('Lưu PIN Mới', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessPaymentDialog(double amount, String method) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 60, color: Colors.greenAccent),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thanh Toán Thành Công!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '-${localeProvider.formatAmount(amount)}',
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 28),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phương thức: $method\nNguồn tiền: ${_selectedCard?['cardName'] ?? 'Thẻ NFC'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text('Hoàn Tất'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final activeColor = themeProvider.isDarkMode ? Colors.cyanAccent : const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        title: Text(
          localeProvider.getText('payment_title'),
          style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: activeColor,
          labelColor: activeColor,
          unselectedLabelColor: themeProvider.subtitleColor,
          tabs: [
            Tab(icon: const Icon(Icons.nfc), text: localeProvider.getText('nfc_tab')),
            Tab(icon: const Icon(Icons.qr_code_scanner), text: localeProvider.getText('qr_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: NFC Tap to Pay
          _buildNfcPaymentTab(localeProvider, themeProvider),
          // Tab 2: QR Code Payment
          _buildQrPaymentTab(localeProvider, themeProvider),
        ],
      ),
    );
  }

  Widget _buildNfcPaymentTab(LocaleProvider localeProvider, ThemeProvider themeProvider) {
    final accentText = themeProvider.isDarkMode ? Colors.cyanAccent : const Color(0xFF0284C7);
    final btnBg = themeProvider.isDarkMode ? Colors.cyanAccent : const Color(0xFF6366F1);
    final btnFg = themeProvider.isDarkMode ? Colors.black : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Card Selection Dropdown
        Text(
          'Chọn Nguồn Thẻ Thanh Toán',
          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _isLoadingCards
            ? CircularProgressIndicator(color: themeProvider.primaryColor)
            : DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: _selectedCard,
                dropdownColor: themeProvider.dialogBgColor,
                style: TextStyle(color: themeProvider.textColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: themeProvider.inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: themeProvider.cardBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: themeProvider.cardBorderColor),
                  ),
                ),
                items: _cards.map((c) {
                  final String name = c['cardName']?.toString() ?? 'Thẻ';
                  final String numStr = c['cardNumber']?.toString() ?? '0000';
                  final String last4 = numStr.length >= 4 ? numStr.substring(numStr.length - 4) : numStr;
                  final bool isExp = CardUtils.isCardExpired(c['expiryDate']);
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: c,
                    child: Text(
                      '$name (**** $last4)${isExp ? " [ĐÃ HẾT HẠN]" : ""}',
                      style: TextStyle(
                        color: isExp ? Colors.redAccent : themeProvider.textColor,
                        fontWeight: isExp ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCard = val),
              ),

        const SizedBox(height: 20),

        // Amount Input
        Text(
          'Số Tiền Thanh Toán (${localeProvider.currencySymbol})',
          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: accentText, fontSize: 26, fontWeight: FontWeight.bold),
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            prefixText: '${localeProvider.currencySymbol} ',
            prefixStyle: TextStyle(color: accentText, fontSize: 26, fontWeight: FontWeight.bold),
            filled: true,
            fillColor: themeProvider.inputFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: themeProvider.cardBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: themeProvider.cardBorderColor),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Quick Amount Chips (Horizontally Scrollable)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: (localeProvider.isVND
                    ? ['50000', '100000', '200000', '500000', '1000000']
                    : ['10.00', '25.00', '50.00', '100.00'])
                .map((amt) {
              final double currentVal = double.tryParse(_amountController.text.trim()) ?? -1.0;
              final double chipVal = double.tryParse(amt) ?? -2.0;
              final bool isSelected = currentVal == chipVal;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(localeProvider.formatAmount(chipVal)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _amountController.text = amt),
                  selectedColor: themeProvider.primaryColor,
                  backgroundColor: themeProvider.cardColor,
                  side: BorderSide(color: isSelected ? Colors.transparent : themeProvider.cardBorderColor),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : themeProvider.textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Note Input
        TextField(
          controller: _noteController,
          style: TextStyle(color: themeProvider.textColor),
          decoration: InputDecoration(
            labelText: 'Nội dung / Ghi chú thanh toán',
            labelStyle: TextStyle(color: themeProvider.subtitleColor),
            filled: true,
            fillColor: themeProvider.inputFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeProvider.cardBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeProvider.cardBorderColor),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Big Action Button: Start NFC Payment
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isProcessingPayment
                ? null
                : () => _verifyPinBeforePayment(
                      method: 'Chạm NFC 1-Chạm',
                      onSuccess: _simulateNfcScanAndPay,
                    ),
            icon: const Icon(Icons.nfc, size: 28),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('CHẠM THẺ NFC ĐỂ THANH TOÁN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  void _showQrScannerModal() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: themeProvider.dialogBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: themeProvider.subtitleColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: themeProvider.accentColor, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Ống Kính Quét Mã QR',
                          style: TextStyle(color: themeProvider.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: themeProvider.subtitleColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Camera Scanner Viewfinder Frame
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: themeProvider.accentColor.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Viewfinder Grid Overlay
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.cyanAccent, width: 3),
                          ),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 200,
                                  height: 2,
                                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.center_focus_weak_rounded, size: 64, color: Colors.cyanAccent),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Đang quét... Hướng máy ảnh vào Mã QR',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Simulated QR Scan & PIN Verification Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _verifyPinBeforePayment(
                        method: 'Quét Mã QR',
                        onSuccess: () => _processPaymentApi(method: 'Quét Mã QR'),
                      );
                    },
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('XÁC THỰC PIN & THANH TOÁN (MÁY ẢO / MÁY THẬT)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.accentColor,
                      foregroundColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQrPaymentTab(LocaleProvider localeProvider, ThemeProvider themeProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: themeProvider.cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'MÃ QR THANH TOÁN',
                style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Quét mã này bằng ví điện tử để chuyển tiền đến ví',
                style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Styled QR Code Graphic Container
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.white),
                      Text('HYDRANGE NFC PAY', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  localeProvider.formatAmount(double.tryParse(_amountController.text) ?? 0),
                  style: TextStyle(color: themeProvider.primaryColor, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _showQrScannerModal,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QUÉT MÃ QR KHÁCH HÀNG / CỬA HÀNG'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
