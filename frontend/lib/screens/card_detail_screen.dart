import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/api_config.dart';
import '../services/haptic_service.dart';
import '../providers/auth_provider.dart';

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
    HapticService.selectionFeedback();
    final holderController = TextEditingController(text: _card['cardHolder']?.toString() ?? 'Chủ Thẻ NFC');
    final expiryController = TextEditingController(text: _card['expiryDate']?.toString() ?? '12/28');
    final phoneController = TextEditingController(text: _card['phone']?.toString() ?? '');
    final nameController = TextEditingController(text: _card['cardName']?.toString() ?? '');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Cập Nhật Thông Tin Thẻ', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tên thẻ (Vd: Visa Gold)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: holderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ sở hữu',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên chủ thẻ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: expiryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Ngày hết hạn (MM/YY)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(v.trim())) {
                      return 'Định dạng hạn thẻ không hợp lệ (ví dụ: 12/28)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại liên kết',
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
                      const SnackBar(content: Text('Cập nhật thông tin thẻ thành công!'), backgroundColor: Colors.green),
                    );
                    _refreshCardDetails();
                  } else {
                    final resBody = json.decode(response.body);
                    throw Exception(resBody['error'] ?? 'Cập nhật thất bại');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Lưu thông tin'),
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog() {
    HapticService.selectionFeedback();
    final amountController = TextEditingController(text: '50.00');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.add_card, color: Colors.greenAccent, size: 28),
            SizedBox(width: 8),
            Text('Nạp Tiền Vào Thẻ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nạp tiền trực tiếp vào ${_card['cardName'] ?? 'Thẻ'}. Số dư hiện tại: \$${(_card['balance']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Số tiền nạp (\$)',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: Colors.greenAccent, fontSize: 24),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final amt = double.tryParse(v?.trim() ?? '');
                  if (amt == null || amt <= 0) return 'Số tiền nạp phải lớn hơn 0';
                  return null;
                },
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
                      'title': 'Nạp tiền vào ví',
                      'category': 'Nạp tiền',
                      'amount': amt,
                      'isExpense': false,
                      'status': 'Success',
                    }),
                  );
                  if (response.statusCode == 201 && mounted) {
                    HapticService.successFeedback();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Nạp tiền thành công +\$${amt.toStringAsFixed(2)}!'), backgroundColor: Colors.green),
                    );
                    _refreshCardDetails();
                  } else {
                    final resBody = json.decode(response.body);
                    throw Exception(resBody['error'] ?? 'Nạp tiền thất bại');
                  }
                } catch (e) {
                  if (mounted) {
                    HapticService.errorFeedback();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi nạp tiền: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            child: const Text('Xác Nhận Nạp Tiền', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final double balance = (_card['balance']?.toDouble() ?? 0.0);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_card['cardName']?.toString() ?? 'Chi Tiết Thẻ'),
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
                      colors: isDefault
                          ? [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)]
                          : [const Color(0xFF2C3E50), const Color(0xFF000000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: isDefault ? Border.all(color: Colors.amber, width: 1.5) : null,
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
                            Text(
                              (_card['cardName'] ?? 'NFC CARD').toString().toUpperCase(),
                              style: TextStyle(
                                color: isDefault ? Colors.amber : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Details List Group
                const Text(
                  'Thông Tin Chi Tiết Thẻ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(Icons.person, 'Chủ sở hữu', holder),
                      const Divider(color: Colors.white12, height: 1),
                      _buildInfoTile(Icons.credit_card, 'Số thẻ đầy đủ', cardNumber),
                      const Divider(color: Colors.white12, height: 1),
                      _buildInfoTile(Icons.calendar_today, 'Ngày hết hạn', expiry),
                      const Divider(color: Colors.white12, height: 1),
                      _buildInfoTile(Icons.phone, 'Số ĐT liên kết', phone),
                      const Divider(color: Colors.white12, height: 1),
                      _buildInfoTile(
                        Icons.account_balance_wallet,
                        'Số dư khả dụng',
                        '\$${balance.toStringAsFixed(2)}',
                        valueColor: Colors.greenAccent,
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildInfoTile(
                        Icons.star,
                        'Trạng thái thẻ',
                        isDefault ? 'Thẻ mặc định' : 'Thẻ phụ',
                        valueColor: isDefault ? Colors.amber : Colors.white70,
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
                        label: const Text('NẠP TIỀN VÀO THẺ', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
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
                        label: const Text('Chỉnh Sửa Thẻ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
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

  Widget _buildInfoTile(IconData icon, String label, String value, {Color? valueColor}) {
    return ListTile(
      leading: Icon(icon, color: Colors.cyanAccent, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: Text(
        value,
        style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
