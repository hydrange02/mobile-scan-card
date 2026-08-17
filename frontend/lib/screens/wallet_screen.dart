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
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
        HapticService.successFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeProvider.getText('set_default_success')), backgroundColor: Colors.green),
        );
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.red),
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
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
        HapticService.successFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localeProvider.getText('card_deleted_success'))),
        );
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.red),
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
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
        HapticService.successFeedback();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(localeProvider.getText('card_added_success')), backgroundColor: Colors.green),
        );
        _fetchCards();
      } else {
        if (!mounted) return;
        final resData = json.decode(response.body);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(resData['error'] ?? 'Failed to add card'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('${localeProvider.getText('error_prefix')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _scanNfcCard() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    Navigator.pop(context); // Close selection modal
    
    // Show scanning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.nfc, size: 60, color: Colors.cyanAccent),
            const SizedBox(height: 16),
            Text(
              localeProvider.getText('scanning_nfc'),
              style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              localeProvider.getText('hold_nfc_near'),
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
            content: Text('${localeProvider.getText('nfc_not_supported')} (${result['error']})'),
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
      final String cardDefaultName = localeProvider.isVietnamese ? 'Thẻ NFC ($suffix)' : 'NFC Card ($suffix)';
      _addCardApi(cardDefaultName, '411122223333$suffix');
    }
  }

  void _showManualInputDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
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
            Color color = Colors.cyanAccent;

            if (clean.startsWith('4')) {
              brand = 'VISA';
              color = Colors.blueAccent;
            } else if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(clean)) {
              brand = 'MASTERCARD';
              color = Colors.orangeAccent;
            } else if (clean.startsWith('9704')) {
              brand = 'NAPAS';
              color = Colors.greenAccent;
            } else if (RegExp(r'^(34|37)').hasMatch(clean)) {
              brand = 'AMEX';
              color = Colors.lightBlueAccent;
            } else if (RegExp(r'^35').hasMatch(clean)) {
              brand = 'JCB';
              color = Colors.redAccent;
            } else if (RegExp(r'^(62|81)').hasMatch(clean)) {
              brand = 'UNIONPAY';
              color = Colors.tealAccent;
            }

            setDialogState(() {
              detectedBrand = brand;
              brandColor = color;
            });
          }

          return AlertDialog(
            backgroundColor: themeProvider.dialogBgColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.credit_card_rounded, color: Colors.cyanAccent, size: 28),
                const SizedBox(width: 8),
                Text(localeProvider.getText('manual_entry_title'), style: TextStyle(color: themeProvider.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    keyboardType: TextInputType.text,
                    enableSuggestions: true,
                    autocorrect: true,
                    style: TextStyle(color: themeProvider.textColor),
                    decoration: InputDecoration(
                      labelText: localeProvider.getText('card_nickname_label'),
                      hintText: localeProvider.getText('card_nickname_hint'),
                      hintStyle: TextStyle(color: themeProvider.subtitleColor, fontSize: 11),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final clean = v.trim();
                      if (clean.length < 2 || clean.length > 50) return '2 - 50 chars';
                      if (RegExp(r'[<>{}]').hasMatch(clean)) {
                        return 'Invalid characters';
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
                      labelText: localeProvider.getText('card_number_label'),
                      labelStyle: TextStyle(color: themeProvider.subtitleColor),
                      hintText: localeProvider.getText('card_number_hint'),
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
                      if (clean.isEmpty) return '15 - 19 digits';
                      if (!RegExp(r'^\d+$').hasMatch(clean)) return 'Digits only';
                      if (clean.length < 15 || clean.length > 19) return '15 - 19 digits';

                      final isValidBin = clean.startsWith('4') ||
                          RegExp(r'^(5[1-5]|2[2-7])').hasMatch(clean) ||
                          clean.startsWith('9704') ||
                          RegExp(r'^(34|37)').hasMatch(clean) ||
                          RegExp(r'^35').hasMatch(clean) ||
                          RegExp(r'^(62|81)').hasMatch(clean);

                      if (!isValidBin) {
                        return 'Invalid card BIN';
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
                          '${localeProvider.getText('auto_detect_brand')} $detectedBrand',
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
                child: Text(localeProvider.getText('cancel'), style: TextStyle(color: themeProvider.subtitleColor)),
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
                child: Text(localeProvider.getText('add_card_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCardOptions() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
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
              localeProvider.getText('choose_add_method'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.nfc, color: Colors.cyanAccent),
              ),
              title: Text(localeProvider.getText('scan_nfc_title'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
              subtitle: Text(localeProvider.getText('scan_nfc_sub'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
              onTap: _scanNfcCard,
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.edit_note, color: Colors.purpleAccent),
              ),
              title: Text(localeProvider.getText('manual_entry_title'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
              subtitle: Text(localeProvider.getText('manual_entry_sub'), style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
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
                          localeProvider.getText('wallet_management'),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                        ),
                        Text(
                          localeProvider.isVietnamese ? 'Quản lý ${_cards.length} thẻ trong ví' : 'Managing ${_cards.length} cards in wallet',
                          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddCardOptions,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(localeProvider.getText('add_new_card')),
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
                          localeProvider.getText('no_cards_in_wallet'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localeProvider.getText('add_card_now_sub'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showAddCardOptions,
                          icon: const Icon(Icons.add_card),
                          label: Text(localeProvider.getText('add_card_now')),
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
                                          child: Text(
                                            localeProvider.getText('default_card').toUpperCase(),
                                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
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
                                          child: Text(
                                            localeProvider.getText('expired'),
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
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
                                          tooltip: isExpired ? localeProvider.getText('cannot_set_expired_default') : localeProvider.getText('set_default_tooltip'),
                                          onPressed: isExpired
                                              ? () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(localeProvider.getText('cannot_set_expired_default'))),
                                                  );
                                                }
                                              : () => _setDefaultCard(card['id']),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: localeProvider.getText('delete_card_tooltip'),
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
                                  '${localeProvider.getText('balance_prefix')} ${localeProvider.formatAmount(balance)}',
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
