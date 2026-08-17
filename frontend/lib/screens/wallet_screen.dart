import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_config.dart';
import '../services/haptic_service.dart';
import '../services/nfc_service.dart';
import '../services/card_utils.dart';
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
    final messenger = ScaffoldMessenger.of(context);
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
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Thêm thẻ mới thành công!'), backgroundColor: Colors.green),
        );
        _fetchCards();
      } else {
        if (!mounted) return;
        final resData = json.decode(response.body);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(resData['error'] ?? 'Không thể thêm thẻ mới. Vui lòng thử lại!'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Lỗi kết nối khi thêm thẻ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scanNfcCard() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Navigator.pop(context); // Close selection modal
    
    // Show scanning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.nfc, size: 60, color: Colors.cyanAccent),
            const SizedBox(height: 16),
            Text(
              'Đang quét thẻ NFC...',
              style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng đưa thẻ NFC chạm vào lưng thiết bị',
              textAlign: TextAlign.center,
              style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.cyanAccent),
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Navigator.pop(context); // Close selection modal

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    String detectedBrand = '';
    Color brandColor = Colors.cyanAccent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          void updateBrand(String val) {
            final clean = val.replaceAll(RegExp(r'\s+'), '');
            String brand = '';
            Color col = Colors.cyanAccent;

            if (clean.startsWith('4')) {
              brand = 'VISA';
              col = Colors.blueAccent;
            } else if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(clean)) {
              brand = 'MASTERCARD';
              col = Colors.orangeAccent;
            } else if (clean.startsWith('9704')) {
              brand = 'NAPAS (ATM)';
              col = Colors.greenAccent;
            } else if (RegExp(r'^(34|37)').hasMatch(clean)) {
              brand = 'AMEX';
              col = Colors.cyanAccent;
            } else if (RegExp(r'^35').hasMatch(clean)) {
              brand = 'JCB';
              col = Colors.purpleAccent;
            } else if (RegExp(r'^(62|81)').hasMatch(clean)) {
              brand = 'UNIONPAY';
              col = Colors.tealAccent;
            }

            setDialogState(() {
              detectedBrand = brand;
              brandColor = col;
            });
          }

          return AlertDialog(
            backgroundColor: themeProvider.dialogBgColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.credit_card_rounded, color: Colors.cyanAccent, size: 28),
                const SizedBox(width: 8),
                Text('Nhập Thông Tin Thẻ Thủ Công', style: TextStyle(color: themeProvider.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: themeProvider.textColor),
                    decoration: InputDecoration(
                      labelText: 'Tên gợi nhớ của thẻ (Tùy chọn)',
                      hintText: 'Để trống sẽ tự nhận diện loại thẻ + 4 số cuối',
                      hintStyle: TextStyle(color: themeProvider.subtitleColor, fontSize: 11),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final clean = v.trim();
                      if (clean.length < 2 || clean.length > 50) return 'Tên thẻ phải từ 2 đến 50 ký tự';
                      if (RegExp(r'[<>{}[\]\\\/@#$%^&*()=~|]').hasMatch(clean)) {
                        return 'Tên thẻ không được chứa các ký tự đặc biệt';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: numberController,
                    style: TextStyle(color: themeProvider.textColor),
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    onChanged: updateBrand,
                    decoration: InputDecoration(
                      labelText: 'Số thẻ ngân hàng (15-19 chữ số)',
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      hintText: 'Ví dụ: 4111222233334444 hoặc 9704123456789012',
                      hintStyle: TextStyle(color: themeProvider.subtitleColor, fontSize: 11),
                      border: const OutlineInputBorder(),
                      suffixIcon: detectedBrand.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Chip(
                                label: Text(
                                  detectedBrand,
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                                backgroundColor: brandColor,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          : null,
                    ),
                    validator: (v) {
                      final clean = (v ?? '').replaceAll(RegExp(r'\s+'), '');
                      if (clean.isEmpty) return 'Vui lòng nhập số thẻ ngân hàng';
                      if (!RegExp(r'^\d+$').hasMatch(clean)) return 'Số thẻ chỉ được chứa chữ số';
                      if (clean.length < 15 || clean.length > 19) return 'Số thẻ phải từ 15 đến 19 chữ số (chuẩn 16 số)';

                      final isValidBin = clean.startsWith('4') ||
                          RegExp(r'^(5[1-5]|2[2-7])').hasMatch(clean) ||
                          clean.startsWith('9704') ||
                          RegExp(r'^(34|37)').hasMatch(clean) ||
                          RegExp(r'^35').hasMatch(clean) ||
                          RegExp(r'^(62|81)').hasMatch(clean);

                      if (!isValidBin) {
                        return 'Đầu số (BIN) không hợp lệ (Visa: 4, Mastercard: 5/2, Napas: 9704, Amex: 34/37, JCB: 35)';
                      }
                      return null;
                    },
                  ),
                  if (detectedBrand.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Tự động nhận diện mạng thẻ: $detectedBrand',
                          style: TextStyle(color: brandColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Hủy', style: TextStyle(color: themeProvider.subtitleColor)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final cleanNumber = numberController.text.replaceAll(RegExp(r'\s+'), '');
                    Navigator.pop(ctx);
                    _addCardApi(nameController.text.trim(), cleanNumber);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                child: const Text('Thêm thẻ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCardOptions() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    HapticService.selectionFeedback();
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.dialogBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn phương thức thêm thẻ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.nfc, color: Colors.cyanAccent),
              ),
              title: Text('Quét thẻ bằng NFC', style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Chạm thẻ NFC vào thiết bị để tự động đọc', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
              onTap: _scanNfcCard,
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.edit_note, color: Colors.purpleAccent),
              ),
              title: Text('Nhập thông tin thủ công', style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Tự nhập Tên thẻ và Số thẻ ngân hàng', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeProvider.primaryColor))
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
                        Text(
                          'Ví Điện Tử',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                        ),
                        Text(
                          'Quản lý ${_cards.length} thẻ trong ví',
                          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddCardOptions,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('THÊM THẺ MỚI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.primaryColor,
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
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: themeProvider.cardBorderColor),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.wallet, size: 64, color: themeProvider.primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có thẻ trong ví',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thêm thẻ ngay để bắt đầu trải nghiệm thanh toán NFC 1-Chạm nhanh chóng và an toàn!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showAddCardOptions,
                          icon: const Icon(Icons.add_card),
                          label: const Text('Thêm thẻ ngay'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.primaryColor,
                            foregroundColor: Colors.white,
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
                    final dynamic rawBal = card['balance'];
                    final double balance = rawBal is num ? rawBal.toDouble() : (double.tryParse(rawBal?.toString() ?? '') ?? 0.0);

                    final bool isExpired = CardUtils.isCardExpired(card['expiryDate']);

                    return InkWell(
                      onTap: () async {
                        HapticService.selectionFeedback();
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(cardData: card)));
                        _fetchCards();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isExpired
                                ? [const Color(0xFF37474F), const Color(0xFF212121)]
                                : isDefault
                                    ? [const Color(0xFF6200EE), const Color(0xFF3700B3)]
                                    : [const Color(0xFF2C3E50), const Color(0xFF000000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: isDefault ? Border.all(color: Colors.amber, width: 1.5) : (isExpired ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1) : null),
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
                                          color: isExpired ? Colors.white70 : (isDefault ? Colors.amber : Colors.white),
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
                                  Row(
                                    children: [
                                      if (!isDefault)
                                        IconButton(
                                          icon: Icon(Icons.star_border, color: isExpired ? Colors.grey : Colors.amber),
                                          tooltip: isExpired ? 'Không thể đặt thẻ hết hạn làm mặc định' : 'Đặt làm mặc định',
                                          onPressed: isExpired
                                              ? () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Không thể chọn thẻ đã hết hạn làm thẻ mặc định! Vui lòng cập nhật hạn thẻ trước.')),
                                                  );
                                                }
                                              : () => _setDefaultCard(card['id']),
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Số dư: ${localeProvider.formatAmount(balance)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
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
