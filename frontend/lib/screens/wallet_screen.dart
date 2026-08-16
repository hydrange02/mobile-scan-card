import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_config.dart';
import '../services/haptic_service.dart';
import '../services/nfc_service.dart';
import 'card_detail_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<dynamic> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/cards'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _cards = json.decode(response.body);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _cards = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cards = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setDefaultCard(int id) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/cards/$id/default'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        HapticService.successFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đặt làm thẻ mặc định!'), backgroundColor: Colors.green),
        );
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCard(int id) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/cards/$id'),
        headers: authProvider.authHeaders,
      );
      if ((response.statusCode == 200 || response.statusCode == 204) && mounted) {
        HapticService.successFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa thẻ khỏi ví thành công')),
        );
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa thẻ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addCardApi(String name, String number) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/cards'),
        headers: authProvider.authHeaders,
        body: json.encode({
          'cardName': name,
          'cardNumber': number,
        }),
      );
      if (response.statusCode == 201 && mounted) {
        HapticService.successFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm thẻ mới thành công!'), backgroundColor: Colors.green),
        );
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm thẻ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scanNfcCard() async {
    Navigator.pop(context); // Close selection modal
    
    // Show scanning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 12),
            Icon(Icons.nfc, size: 60, color: Colors.cyanAccent),
            SizedBox(height: 16),
            Text(
              'Đang quét thẻ NFC...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Vui lòng đưa thẻ NFC chạm vào lưng thiết bị',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Colors.cyanAccent),
          ],
        ),
      ),
    );

    final result = await NfcService().readAndValidateTag();
    if (mounted) Navigator.pop(context); // Close scanning dialog

    if (result.containsKey('error') && !result.containsKey('id')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thiết bị không hỗ trợ NFC hoặc chưa bật NFC (${result['error']})'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (result.containsKey('id') && result['id'] != null) {
      final String tagId = result['id'].toString();
      final String cleanTag = tagId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final String suffix = cleanTag.length >= 4
          ? cleanTag.substring(cleanTag.length - 4).toUpperCase()
          : cleanTag.padLeft(4, '0').toUpperCase();
      _addCardApi('Thẻ NFC ($suffix)', '411122223333$suffix');
    }
  }

  void _showManualInputDialog() {
    Navigator.pop(context); // Close selection modal

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Nhập Thông Tin Thẻ Thủ Công', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tên thẻ (vd: Visa Gold, Mastercard)',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên thẻ' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: numberController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: const InputDecoration(
                  labelText: 'Số thẻ ngân hàng (12-19 chữ số, chuẩn 16 số)',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'Ví dụ: 4111222233334444',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final clean = (v ?? '').replaceAll(RegExp(r'\s+'), '');
                  if (clean.isEmpty) return 'Vui lòng nhập số thẻ ngân hàng';
                  if (!RegExp(r'^\d+$').hasMatch(clean)) return 'Số thẻ chỉ được chứa chữ số';
                  if (clean.length < 12 || clean.length > 19) return 'Số thẻ phải từ 12 đến 19 chữ số (chuẩn 16 số)';
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cleanNumber = numberController.text.replaceAll(RegExp(r'\s+'), '');
                Navigator.pop(ctx);
                _addCardApi(nameController.text.trim(), cleanNumber);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text('Thêm thẻ'),
          ),
        ],
      ),
    );
  }

  void _showAddCardOptions() {
    HapticService.selectionFeedback();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn phương thức thêm thẻ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.nfc, color: Colors.cyanAccent),
              ),
              title: const Text('Quét thẻ bằng NFC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Chạm thẻ NFC vào thiết bị để tự động đọc', style: TextStyle(color: Colors.white70, fontSize: 12)),
              onTap: _scanNfcCard,
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.edit_note, color: Colors.purpleAccent),
              ),
              title: const Text('Nhập thông tin thủ công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Tự nhập Tên thẻ và Số thẻ ngân hàng', style: TextStyle(color: Colors.white70, fontSize: 12)),
              onTap: _showManualInputDialog,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ví Điện Tử',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Quản lý ${_cards.length} thẻ trong ví',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddCardOptions,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('THÊM THẺ MỚI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Card List or Empty State
                if (_cards.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.wallet, size: 64, color: Colors.purpleAccent),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có thẻ trong ví',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Thêm thẻ ngay để bắt đầu trải nghiệm thanh toán NFC 1-Chạm nhanh chóng và an toàn!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showAddCardOptions,
                          icon: const Icon(Icons.add_card),
                          label: const Text('Thêm thẻ ngay'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._cards.map((card) {
                    final bool isDefault = card['isDefault'] == true;
                    final String number = card['cardNumber'].toString();
                    final maskedNumber = number.length > 4
                        ? "**** **** **** ${number.substring(number.length - 4)}"
                        : number;
                    final double balance = (card['balance']?.toDouble() ?? 0.0);

                    return InkWell(
                      onTap: () {
                        HapticService.selectionFeedback();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(cardData: card)));
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDefault
                                ? [const Color(0xFF6200EE), const Color(0xFF3700B3)]
                                : [const Color(0xFF2C3E50), const Color(0xFF000000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: isDefault ? Border.all(color: Colors.amber, width: 1.5) : null,
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        card['cardName'].toString().toUpperCase(),
                                        style: TextStyle(
                                          color: isDefault ? Colors.amber : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.amber, width: 0.8),
                                          ),
                                          child: const Text(
                                            'MẶC ĐỊNH',
                                            style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (!isDefault)
                                        IconButton(
                                          icon: const Icon(Icons.star_border, color: Colors.amber),
                                          tooltip: 'Đặt làm mặc định',
                                          onPressed: () => _setDefaultCard(card['id']),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: 'Xóa thẻ khỏi ví',
                                        onPressed: () => _deleteCard(card['id']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Số dư: \$${balance.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    maskedNumber,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2),
                                  ),
                                  const Icon(Icons.nfc, color: Colors.cyanAccent, size: 26),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
