import 'package:flutter/services.dart';

/// Service providing haptic feedback for NFC scanning and UI interactions.
class HapticService {
  /// Rung nhẹ khi quét thành công hoặc thao tác thành công
  static Future<void> successFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Rung khi xảy ra lỗi (ví dụ: quét NFC thất bại hoặc sai checksum)
  static Future<void> errorFeedback() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Rung nhẹ khi chạm nút
  static Future<void> selectionFeedback() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
