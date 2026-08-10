import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'wallet_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<dynamic> cards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/api/cards'));
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

  Future<void> _deleteCard(int id) async {
    final response = await http.delete(Uri.parse('http://localhost:3000/api/cards/$id'));
    if (response.statusCode == 200 || response.statusCode == 24) {
      _fetchCards();
    }
  }

  Widget _buildHomeDashboard() {
    return isLoading 
      ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
      : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Default Card in Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (cards.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('No cards found in wallet. Tap E-Wallet to add a card.', style: TextStyle(color: Colors.white70)),
                ),
              )
            else
              ...cards.map((card) {
                final String number = card['cardNumber'].toString();
                final maskedNumber = number.length > 4 
                    ? "**** **** **** ${number.substring(number.length - 4)}" 
                    : number;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6200EE), Color(0xFF3700B3)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              card['cardName'].toString().toUpperCase(), 
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteCard(card['id']),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          maskedNumber, 
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 3),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('EXPIRES: 12/28', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                              child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeDashboard(),
      const WalletScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Home Dashboard' : (_currentIndex == 1 ? 'E-Wallet NFC' : 'Customer Profile'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) _fetchCards();
        },
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1E1E2C),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Ví điện tử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Thông tin',
          ),
        ],
      ),
    );
  }
}
