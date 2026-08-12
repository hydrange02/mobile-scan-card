import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import '../providers/locale_provider.dart';
import '../services/haptic_service.dart';
import '../services/api_config.dart';

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
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/cards'));
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          cards = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/transactions'));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          recentTransactions = json.decode(response.body);
        });
      }
    } catch (_) {}
  }

  Widget _buildHomeDashboard() {
    final localeProvider = Provider.of<LocaleProvider>(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
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
    final double cardBalance = defaultCard != null ? (defaultCard['balance']?.toDouble() ?? 5240.50) : 0.0;

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
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                const Icon(Icons.credit_card_off_rounded, size: 48, color: Colors.purpleAccent),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có thẻ nào trong ví',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy thêm thẻ ngay để xem chi tiết số dư và quản lý các giao dịch của bạn!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticService.selectionFeedback();
                    setState(() => _currentIndex = 1); // Switch to Wallet tab
                  },
                  icon: const Icon(Icons.add_card),
                  label: const Text('Thêm thẻ ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
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
                  Text(
                    '\$${cardBalance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    maskedNumber,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // -------------------------------------------------------------
        // 2. KHUNG HIỂN THỊ THÔNG BÁO (Notification / Announcement Frame)
        // -------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.cyanAccent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeProvider.getText('system_notice'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localeProvider.getText('notice_content'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                HapticService.selectionFeedback();
                setState(() => _currentIndex = 2); // Switch to Reports tab
              },
              child: Text(
                localeProvider.getText('see_all'),
                style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (recentTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Chưa có lịch sử giao dịch nào',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          )
        else
          ...recentTransactions.take(5).map((tx) {
            final bool isExpense = tx['isExpense'] == true;
            final String amountText = '${isExpense ? '-' : '+'}\$${tx['amount']}';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white.withValues(alpha: 0.03),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isExpense
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : Colors.greenAccent.withValues(alpha: 0.15),
                  child: Icon(
                    isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                    color: isExpense ? Colors.redAccent : Colors.greenAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  tx['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  '${tx['date']} • ${tx['cardName']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isExpense ? Colors.redAccent : Colors.greenAccent,
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

    final List<Widget> pages = [
      _buildHomeDashboard(),
      const WalletScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.getText('app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
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
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart), label: localeProvider.getText('reports')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: localeProvider.getText('settings')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: localeProvider.getText('person') != 'person' ? localeProvider.getText('person') : localeProvider.getText('profile')),
        ],
      ),
    );
  }
}
