import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'wallet_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'card_detail_screen.dart';
import 'payment_screen.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/haptic_service.dart';
import '../services/api_config.dart';
import '../services/card_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<dynamic> cards = [];
  List<dynamic> recentTransactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCards();
    _fetchTransactions();
  }

  Future<void> _fetchCards() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/cards'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          cards = json.decode(response.body);
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          cards = [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          cards = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/transactions'),
        headers: authProvider.authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          recentTransactions = json.decode(response.body);
        });
      } else if (mounted) {
        setState(() {
          recentTransactions = [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => recentTransactions = []);
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    final dt = DateTime.tryParse(rawDate)?.toLocal();
    if (dt == null) return rawDate;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  Widget _buildHomeDashboard() {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: themeProvider.primaryColor));
    }

    // Find default card or first available card
    final defaultCard = cards.firstWhere(
      (c) => c['isDefault'] == true,
      orElse: () => cards.isNotEmpty ? cards.first : null,
    );

    final String cardNumber = defaultCard != null ? defaultCard['cardNumber'].toString() : '';
    final String maskedNumber = cardNumber.length > 4
        ? "**** **** **** ${cardNumber.substring(cardNumber.length - 4)}"
        : (cardNumber.isNotEmpty ? cardNumber : "**** **** **** ----");
    final String cardName = defaultCard != null ? defaultCard['cardName'].toString() : '';
    final dynamic rawBalance = defaultCard != null ? defaultCard['balance'] : null;
    final double cardBalance = rawBalance is num ? rawBalance.toDouble() : (double.tryParse(rawBalance?.toString() ?? '') ?? 0.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // -------------------------------------------------------------
        // 1. KHUNG THẺ MẶC ĐỊNH & SỐ DƯ (Default Card & Balance Frame)
        // -------------------------------------------------------------
        if (defaultCard == null)
          Container(
            padding: const EdgeInsets.all(24),
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
                Icon(Icons.credit_card_off_rounded, size: 48, color: themeProvider.primaryColor),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticService.selectionFeedback();
                    setState(() => _currentIndex = 1); // Switch to Wallet tab
                  },
                  icon: const Icon(Icons.add_card),
                  label: Text(localeProvider.getText('add_card_now')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: () async {
              HapticService.selectionFeedback();
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(cardData: defaultCard)));
              _fetchCards();
              _fetchTransactions();
            },
            borderRadius: BorderRadius.circular(24),
            child: Builder(builder: (context) {
              final bool isExpired = CardUtils.isCardExpired(defaultCard['expiryDate']);
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isExpired
                        ? [const Color(0xFF37474F), const Color(0xFF212121)]
                        : [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (isExpired ? Colors.grey : const Color(0xFF8E2DE2)).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      localeProvider.getText('default_card').toUpperCase(),
                                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpired) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.redAccent, width: 1),
                                  ),
                                  child: Text(
                                    localeProvider.getText('expired'),
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Icon(Icons.nfc, color: Colors.cyanAccent, size: 28),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        cardName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localeProvider.getText('available_balance'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          localeProvider.formatAmount(cardBalance),
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        maskedNumber,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

        const SizedBox(height: 20),

        // -------------------------------------------------------------
        // 2. KHUNG HIỂN THỊ THÔNG BÁO (Notification / Announcement Frame)
        // -------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.cardBorderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeProvider.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.campaign_rounded, color: themeProvider.accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeProvider.getText('system_notice'),
                      style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.textColor, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localeProvider.getText('notice_content'),
                      style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: themeProvider.subtitleColor),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // -------------------------------------------------------------
        // 3. DANH SÁCH GIAO DỊCH GẦN NHẤT (Real Transactions List)
        // -------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localeProvider.getText('recent_transactions'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor),
            ),
            TextButton(
              onPressed: () {
                HapticService.selectionFeedback();
                setState(() => _currentIndex = 3); // Switch to Reports/History tab
              },
              child: Text(
                localeProvider.getText('see_all'),
                style: TextStyle(color: themeProvider.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (recentTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeProvider.cardBorderColor),
            ),
            child: Center(
              child: Text(
                localeProvider.getText('no_transactions'),
                style: TextStyle(color: themeProvider.subtitleColor, fontSize: 13),
              ),
            ),
          )
        else
          ...recentTransactions.take(5).map((tx) {
            final bool isExpense = tx['isExpense'] == true;
            final String amountText = '${isExpense ? '-' : '+'}${localeProvider.formatAmount(tx['amount'])}';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: themeProvider.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: themeProvider.cardBorderColor),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isExpense
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : Colors.greenAccent.withValues(alpha: 0.15),
                  child: Icon(
                    isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                    color: isExpense ? Colors.redAccent : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  tx['title'].toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.textColor),
                ),
                subtitle: Text(
                  '${_formatDate(tx['date']?.toString())} • ${tx['cardName']}',
                  style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12),
                ),
                trailing: SizedBox(
                  width: 130,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amountText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isExpense ? Colors.redAccent : Colors.green,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final List<Widget> pages = [
      _buildHomeDashboard(),
      const WalletScreen(),
      const PaymentScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        title: Text(
          localeProvider.getText('app_title'),
          style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: themeProvider.textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: themeProvider.textColor),
            onPressed: () {
              HapticService.selectionFeedback();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          HapticService.selectionFeedback();
          setState(() => _currentIndex = index);
          if (index == 0) {
            _fetchCards();
            _fetchTransactions();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: localeProvider.getText('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.wallet), label: localeProvider.getText('wallet')),
          BottomNavigationBarItem(
            icon: Icon(Icons.nfc_rounded, color: themeProvider.isDarkMode ? Colors.cyanAccent : const Color(0xFF6366F1)),
            label: 'Thanh toán',
          ),
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart), label: localeProvider.getText('reports')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: localeProvider.getText('settings')),
        ],
      ),
    );
  }
}
