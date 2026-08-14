import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_config.dart';
import '../services/haptic_service.dart';
import '../services/nfc_service.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

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
    _fetchCards();
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
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCards = false);
    }
  }

  Future<void> _processPaymentApi({required String method}) async {
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền thanh toán hợp lệ')),
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

  void _startNfcPayment() async {
    HapticService.selectionFeedback();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(height: 12),
            Icon(Icons.nfc, size: 64, color: Colors.cyanAccent),
            SizedBox(height: 16),
            Text(
              'Đang chờ chạm NFC...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Đưa thiết bị hoặc thẻ NFC chạm vào mặt lưng để thanh toán',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.cyanAccent),
          ],
        ),
      ),
    );

    final result = await NfcService().readAndValidateTag();
    if (mounted) Navigator.pop(context); // Close scanning dialog

    if (result.containsKey('id') || result['valid'] == true) {
      _processPaymentApi(method: 'Chạm NFC 1-Chạm');
    } else {
      if (mounted) {
        HapticService.errorFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Không nhận diện được thẻ NFC. Vui lòng thử lại.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSuccessPaymentDialog(double amount, String method) {
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
            Text(
              '-\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 28),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Thanh Toán NFC & Quét QR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.nfc), text: 'Chạm NFC'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Quét Mã QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: NFC Tap to Pay
          _buildNfcPaymentTab(localeProvider),
          // Tab 2: QR Code Payment
          _buildQrPaymentTab(localeProvider),
        ],
      ),
    );
  }

  Widget _buildNfcPaymentTab(LocaleProvider localeProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Card Selection Dropdown
        const Text('Chọn Nguồn Thẻ Thanh Toán', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _isLoadingCards
            ? const LinearProgressIndicator(color: Colors.purpleAccent)
            : DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedCard,
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: _cards.map((c) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: c,
                    child: Text('${c['cardName']} (${c['cardNumber'].toString().substring(c['cardNumber'].toString().length - 4)})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCard = val),
              ),

        const SizedBox(height: 20),

        // Amount Input
        const Text('Số Tiền Thanh Toán (\$)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 26, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 26),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),

        const SizedBox(height: 12),

        // Quick Amount Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['10.00', '25.00', '50.00', '100.00'].map((amt) {
            return ChoiceChip(
              label: Text('\$$amt'),
              selected: _amountController.text == amt,
              onSelected: (_) => setState(() => _amountController.text = amt),
              selectedColor: Colors.purpleAccent,
              labelStyle: TextStyle(color: _amountController.text == amt ? Colors.white : Colors.white70),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Note Input
        TextField(
          controller: _noteController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nội dung / Ghi chú thanh toán',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(height: 32),

        // Big Action Button: Start NFC Payment
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isProcessingPayment ? null : _startNfcPayment,
            icon: const Icon(Icons.nfc, size: 28),
            label: const Text('CHẠM THẺ NFC ĐỂ THANH TOÁN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrPaymentTab(LocaleProvider localeProvider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('MÃ QR THANH TOÁN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'Quét mã này bằng ví điện tử để chuyển tiền đến ví',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
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
              Text(
                '\$${_amountController.text}',
                style: const TextStyle(color: Colors.purple, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _processPaymentApi(method: 'Quét Mã QR'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QUÉT MÃ QR KHÁCH HÀNG / CỬA HÀNG'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
