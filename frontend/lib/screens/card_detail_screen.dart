import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/api_config.dart';
import '../services/haptic_service.dart';
import '../services/card_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class CardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cardData;

  const CardDetailScreen({super.key, required this.cardData});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late Map<String, dynamic> _card;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _card = Map<String, dynamic>.from(widget.cardData);
    _refreshCardDetails();
  }

  Future<void> _refreshCardDetails() async {
    final int? id = _card['id'];
    if (id == null) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/cards/$id'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _card = json.decode(response.body);
        });
      }
    } catch (_) {}
  }

  void _showEditCardDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    HapticService.selectionFeedback();
    final holderController = TextEditingController(text: _card['cardHolder']?.toString() ?? (localeProvider.isVietnamese ? 'Chủ Thẻ NFC' : 'NFC Cardholder'));
    final expiryController = TextEditingController(text: _card['expiryDate']?.toString() ?? '12/28');
    final phoneController = TextEditingController(text: _card['phone']?.toString() ?? '');
    final nameController = TextEditingController(text: _card['cardName']?.toString() ?? '');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        title: Text(localeProvider.isVietnamese ? 'Cập Nhật Thông Tin Thẻ' : 'Update Card Information', style: TextStyle(color: themeProvider.textColor)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  keyboardType: TextInputType.text,
                  enableSuggestions: true,
                  autocorrect: true,
                  style: TextStyle(color: themeProvider.textColor),
                  decoration: InputDecoration(
                    labelText: localeProvider.isVietnamese ? 'Tên thẻ (Vd: Visa Gold, Ví Tiêu Dùng)' : 'Card Name (e.g. Visa Gold, Salary)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return localeProvider.isVietnamese ? 'Vui lòng nhập tên thẻ' : 'Card name is required';
                    final clean = v.trim();
                    if (clean.length < 2 || clean.length > 50) return '2 - 50 chars';
                    if (RegExp(r'[<>{}]').hasMatch(clean)) {
                      return 'Invalid characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: holderController,
                  keyboardType: TextInputType.name,
                  enableSuggestions: true,
                  autocorrect: true,
                  style: TextStyle(color: themeProvider.textColor),
                  decoration: InputDecoration(
                    labelText: localeProvider.isVietnamese ? 'Tên chủ sở hữu (Vd: Nguyễn Văn A)' : 'Cardholder Name (e.g. John Doe)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return localeProvider.isVietnamese ? 'Vui lòng nhập tên chủ thẻ' : 'Cardholder name required';
                    final clean = v.trim();
                    if (clean.length < 2 || clean.length > 50) return '2 - 50 chars';
                    if (RegExp(r'[<>{}]').hasMatch(clean)) {
                      return 'Invalid characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: expiryController,
                  style: TextStyle(color: themeProvider.textColor),
                  decoration: InputDecoration(
                    labelText: '${localeProvider.getText('expiry_date')} (MM/YY)',
                    labelStyle: TextStyle(color: themeProvider.subtitleColor),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(v.trim())) {
                      return localeProvider.isVietnamese ? 'Định dạng hạn thẻ không hợp lệ (ví dụ: 12/28)' : 'Invalid expiry format (e.g. 12/28)';
                    }
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
                    labelText: localeProvider.isVietnamese ? 'Số điện thoại liên kết (Vd: 0912345678)' : 'Linked Phone Number (e.g. 0912345678)',
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final response = await http.put(
                    Uri.parse('${ApiConfig.baseUrl}/api/cards/${_card['id']}'),
                    headers: authProvider.authHeaders,
                    body: json.encode({
                      'cardName': nameController.text.trim(),
                      'cardHolder': holderController.text.trim(),
                      'expiryDate': expiryController.text.trim(),
                      'phone': phoneController.text.trim(),
                    }),
                  );
                  if (response.statusCode == 200 && mounted) {
                    HapticService.successFeedback();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localeProvider.isVietnamese ? 'Cập nhật thông tin thẻ thành công!' : 'Card info updated successfully!'), backgroundColor: Colors.green),
                    );
                    _refreshCardDetails();
                  } else {
                    final resBody = json.decode(response.body);
                    throw Exception(resBody['error'] ?? 'Update failed');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${localeProvider.getText('error_prefix')}: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: Text(localeProvider.getText('save_changes')),
          ),
        ],
      ),
    );
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  void _showTopUpDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    if (CardUtils.isCardExpired(_card['expiryDate'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localeProvider.isVietnamese ? 'Thẻ này đã hết hạn sử dụng. Vui lòng bấm ✏️ ở góc trên để cập nhật hạn thẻ trước khi nạp tiền!' : 'This card is expired. Please tap ✏️ to update expiry date before top up!'), backgroundColor: Colors.red),
      );
      return;
    }

    HapticService.selectionFeedback();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final accentCol = Colors.greenAccent;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.add_card, color: accentCol, size: 28),
            const SizedBox(width: 8),
            Text(localeProvider.isVietnamese ? 'Nạp Tiền Vào Thẻ' : 'Top Up Card Balance', style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localeProvider.isVietnamese
                    ? 'Nạp tiền trực tiếp vào ${_card['cardName'] ?? 'Thẻ'}. Số dư hiện tại: ${localeProvider.formatAmount(_parseNum(_card['balance']))}'
                    : 'Top up balance directly for ${_card['cardName'] ?? 'Card'}. Current balance: ${localeProvider.formatAmount(_parseNum(_card['balance']))}',
                style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: accentCol, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: localeProvider.isVietnamese ? 'Số tiền nạp (${localeProvider.currencySymbol})' : 'Top Up Amount (${localeProvider.currencySymbol})',
                  labelStyle: TextStyle(color: themeProvider.subtitleColor),
                  prefixText: '${localeProvider.currencySymbol} ',
                  prefixStyle: TextStyle(color: accentCol, fontSize: 24, fontWeight: FontWeight.bold),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final amt = double.tryParse(v?.trim() ?? '');
                  if (amt == null || amt <= 0) return localeProvider.isVietnamese ? 'Số tiền nạp phải lớn hơn 0' : 'Amount must be greater than 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localeProvider.getText('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final double amt = double.parse(amountController.text.trim());
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/api/transactions'),
                    headers: authProvider.authHeaders,
                    body: json.encode({
                      'cardId': _card['id'],
                      'title': localeProvider.isVietnamese ? 'Nạp tiền vào ví' : 'Top up balance',
                      'category': localeProvider.isVietnamese ? 'Nạp tiền' : 'Top up',
                      'amount': amt,
                      'isExpense': false,
                      'status': 'Success',
                    }),
                  );
                  if (response.statusCode == 201 && mounted) {
                    HapticService.successFeedback();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localeProvider.isVietnamese ? 'Nạp tiền thành công +${localeProvider.formatAmount(amt)}!' : 'Top up successful +${localeProvider.formatAmount(amt)}!'), backgroundColor: Colors.green),
                    );
                    _refreshCardDetails();
                  } else {
                    final resBody = json.decode(response.body);
                    throw Exception(resBody['error'] ?? 'Top up failed');
                  }
                } catch (e) {
                  if (mounted) {
                    HapticService.errorFeedback();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${localeProvider.getText('error_prefix')}: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            child: Text(localeProvider.isVietnamese ? 'Xác Nhận Nạp Tiền' : 'Confirm Top Up', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final bool isDefault = _card['isDefault'] == true;
    final String cardNumber = _card['cardNumber']?.toString() ?? '4111222233339999';
    final String maskedNumber = cardNumber.length > 4
        ? "**** **** **** ${cardNumber.substring(cardNumber.length - 4)}"
        : cardNumber;

    final String holder = (_card['cardHolder'] != null && _card['cardHolder'].toString().isNotEmpty)
        ? _card['cardHolder'].toString()
        : 'NGUYEN VAN A';
    final String expiry = (_card['expiryDate'] != null && _card['expiryDate'].toString().isNotEmpty)
        ? _card['expiryDate'].toString()
        : '12/28';
    final String phone = (_card['phone'] != null && _card['phone'].toString().isNotEmpty)
        ? _card['phone'].toString()
        : 'Chưa cập nhật';
    final double balance = _parseNum(_card['balance']);
    final bool isExpired = CardUtils.isCardExpired(expiry);

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        title: Text(
          _card['cardName']?.toString() ?? 'Chi Tiết Thẻ',
          style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: themeProvider.textColor),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.cyanAccent),
            tooltip: 'Sửa thông tin thẻ',
            onPressed: _showEditCardDialog,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Sleek Realistic Card View
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExpired
                          ? [const Color(0xFF37474F), const Color(0xFF212121)]
                          : isDefault
                              ? [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)]
                              : [const Color(0xFF2C3E50), const Color(0xFF000000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: isDefault ? Border.all(color: Colors.amber, width: 1.5) : (isExpired ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1) : null),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  (_card['cardName'] ?? 'NFC CARD').toString().toUpperCase(),
                                  style: TextStyle(
                                    color: isExpired ? Colors.white70 : (isDefault ? Colors.amber : Colors.white),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isExpired) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.redAccent, width: 0.8),
                                    ),
                                    child: const Text(
                                      'ĐÃ HẾT HẠN',
                                      style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Icon(Icons.nfc, color: Colors.cyanAccent, size: 30),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          maskedNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CHỦ THẺ / HOLDER', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                  holder.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('HẠN THẺ / EXPIRY', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                  expiry,
                                  style: TextStyle(
                                    color: isExpired ? Colors.redAccent : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (isExpired)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Thẻ này đã hết hạn sử dụng. Vui lòng bấm biểu tượng ✏️ ở góc trên để cập nhật hạn thẻ mới!',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // 2. Details List Group
                Text(
                  localeProvider.isVietnamese ? 'Thông Tin Chi Tiết Thẻ' : 'Card Information Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: themeProvider.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeProvider.cardBorderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(Icons.person, localeProvider.isVietnamese ? 'Chủ sở hữu' : 'Cardholder', holder, themeProvider),
                      Divider(color: themeProvider.cardBorderColor, height: 1),
                      _buildInfoTile(Icons.credit_card, localeProvider.isVietnamese ? 'Số thẻ đầy đủ' : 'Full Card Number', cardNumber, themeProvider),
                      Divider(color: themeProvider.cardBorderColor, height: 1),
                      _buildInfoTile(Icons.calendar_today, localeProvider.isVietnamese ? 'Ngày hết hạn' : 'Expiry Date', expiry, themeProvider),
                      Divider(color: themeProvider.cardBorderColor, height: 1),
                      _buildInfoTile(Icons.phone, localeProvider.isVietnamese ? 'Số ĐT liên kết' : 'Linked Phone', phone, themeProvider),
                      Divider(color: themeProvider.cardBorderColor, height: 1),
                      _buildInfoTile(
                        Icons.account_balance_wallet,
                        localeProvider.getText('available_balance'),
                        localeProvider.formatAmount(balance),
                        themeProvider,
                        valueColor: Colors.green,
                      ),
                      Divider(color: themeProvider.cardBorderColor, height: 1),
                      _buildInfoTile(
                        Icons.star,
                        localeProvider.getText('status'),
                        isExpired
                            ? (localeProvider.isVietnamese ? 'Đã hết hạn (Cần gia hạn)' : 'Expired (Renewal Needed)')
                            : (isDefault
                                ? (localeProvider.isVietnamese ? 'Thẻ mặc định' : 'Default Card')
                                : (localeProvider.isVietnamese ? 'Thẻ phụ' : 'Secondary Card')),
                        themeProvider,
                        valueColor: isExpired ? Colors.redAccent : (isDefault ? Colors.amber : themeProvider.subtitleColor),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showTopUpDialog,
                        icon: const Icon(Icons.add_card),
                        label: Text(localeProvider.isVietnamese ? 'NẠP TIỀN VÀO THẺ' : 'TOP UP CARD', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showEditCardDialog,
                        icon: const Icon(Icons.edit_note),
                        label: Text(localeProvider.isVietnamese ? 'Chỉnh Sửa Thẻ' : 'Edit Card Info'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, ThemeProvider themeProvider, {Color? valueColor}) {
    return ListTile(
      leading: Icon(icon, color: themeProvider.accentColor, size: 22),
      title: Text(label, style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13)),
      trailing: Text(
        value,
        style: TextStyle(color: valueColor ?? themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
