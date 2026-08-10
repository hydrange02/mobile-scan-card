import 'package:flutter/material.dart';

class WalletProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> get cards => _cards;

  void addCard(Map<String, dynamic> card) {
    _cards.add(card);
    notifyListeners();
  }
}
