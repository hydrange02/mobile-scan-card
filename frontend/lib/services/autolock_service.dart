import 'dart:async';
import 'package:flutter/material.dart';

/// Auto-lock service that monitors user inactivity and app lifecycle states
/// to lock the application appropriately without frustrating the user.
class AutoLockService extends ChangeNotifier with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  int _autoLockSeconds = 300; // Mặc định 5 phút (300s) thay vì 30s gây phiền
  bool _isLocked = false;
  DateTime? _pausedAt;

  AutoLockService() {
    WidgetsBinding.instance.addObserver(this);
    resetTimer();
  }

  bool get isLocked => _isLocked;
  int get autoLockSeconds => _autoLockSeconds;

  void setAutoLockSeconds(int seconds) {
    _autoLockSeconds = seconds;
    resetTimer();
    notifyListeners();
  }

  void resetTimer() {
    _inactivityTimer?.cancel();
    if (_autoLockSeconds <= 0 || _isLocked) return;
    _inactivityTimer = Timer(Duration(seconds: _autoLockSeconds), () {
      _isLocked = true;
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_autoLockSeconds <= 0) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
      _inactivityTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null && !_isLocked) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= _autoLockSeconds) {
          _isLocked = true;
          notifyListeners();
        }
      }
      _pausedAt = null;
      if (!_isLocked) {
        resetTimer();
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
