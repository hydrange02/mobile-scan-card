import 'dart:async';
import 'package:flutter/material.dart';

/// Auto-lock service that monitors user inactivity and triggers app locking after a set duration.
class AutoLockService extends ChangeNotifier {
  Timer? _inactivityTimer;
  int _autoLockSeconds = 30; // Mặc định 30s hoặc 60s
  bool _isLocked = false;

  bool get isLocked => _isLocked;
  int get autoLockSeconds => _autoLockSeconds;

  void setAutoLockSeconds(int seconds) {
    _autoLockSeconds = seconds;
    resetTimer();
    notifyListeners();
  }

  void resetTimer() {
    _inactivityTimer?.cancel();
    if (_autoLockSeconds <= 0) return;
    _inactivityTimer = Timer(Duration(seconds: _autoLockSeconds), () {
      _isLocked = true;
      notifyListeners();
    });
  }

  void unlock() {
    _isLocked = false;
    resetTimer();
    notifyListeners();
  }

  void stop() {
    _inactivityTimer?.cancel();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
