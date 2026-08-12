import 'package:flutter/material.dart';

/// Localization Provider for switching language between English (en) & Vietnamese (vi)
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('vi');

  Locale get locale => _locale;
  bool get isVietnamese => _locale.languageCode == 'vi';

  void setLocale(String languageCode) {
    _locale = Locale(languageCode);
    notifyListeners();
  }

  // Multi-language dictionary dictionary lookup helper
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Secure NFC Wallet',
      'home': 'Home',
      'wallet': 'Wallet',
      'reports': 'Reports',
      'settings': 'Settings',
      'help': 'Help',
      'profile': 'Profile',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'auto_lock': 'Auto-Lock Inactivity',
      'export_backup': 'Export AES Encrypted Backup',
      'import_backup': 'Import AES Backup',
      'transactions': 'Transaction History',
      'filter_all': 'All',
      'filter_success': 'Success',
      'filter_failed': 'Failed',
      'export_pdf': 'Export PDF',
      'export_csv': 'Export CSV',
      'nfc_guide': 'NFC Scanning Instructions',
      'nfc_faq': 'Frequently Asked Questions (FAQ)',
      'contact_support': 'Contact Support',
      'default_card': 'Default Card',
      'available_balance': 'Available Balance',
      'system_notice': 'System Announcement',
      'notice_content': 'NFC 1-Tap contactless payment active with AES-256 encryption.',
      'recent_transactions': 'Recent Transactions',
      'see_all': 'See All',
    },
    'vi': {
      'app_title': 'Ví NFC Bảo Mật',
      'home': 'Trang chủ',
      'wallet': 'Ví tiền',
      'reports': 'Báo cáo',
      'settings': 'Cài đặt',
      'help': 'Hỗ trợ',
      'profile': 'Hồ sơ',
      'dark_mode': 'Chế độ tối',
      'language': 'Ngôn ngữ',
      'auto_lock': 'Tự động khóa khi không hoạt động',
      'export_backup': 'Xuất file sao lưu mã hóa AES',
      'import_backup': 'Nhập file sao lưu AES',
      'transactions': 'Lịch sử giao dịch',
      'filter_all': 'Tất cả',
      'filter_success': 'Thành công',
      'filter_failed': 'Thất bại',
      'export_pdf': 'Xuất PDF',
      'export_csv': 'Xuất CSV',
      'nfc_guide': 'Hướng dẫn quét thẻ NFC',
      'nfc_faq': 'Câu hỏi thường gặp (FAQ)',
      'contact_support': 'Liên hệ hỗ trợ',
      'default_card': 'Thẻ mặc định',
      'available_balance': 'Số dư khả dụng',
      'system_notice': 'Thông báo hệ thống',
      'notice_content': 'Tính năng thanh toán NFC 1-Chạm đang bật. Mã hóa AES-256.',
      'recent_transactions': 'Giao dịch gần đây',
      'see_all': 'Xem tất cả',
    },
  };

  String getText(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
