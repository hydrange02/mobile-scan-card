import 'package:flutter/material.dart';

/// Localization Provider for switching language between English (en) & Vietnamese (vi)
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('vi');
  String _currency = 'VND'; // Default to VND (₫)

  Locale get locale => _locale;
  bool get isVietnamese => _locale.languageCode == 'vi';

  String get currency => _currency;
  bool get isVND => _currency == 'VND';
  String get currencySymbol => _currency == 'VND' ? '₫' : '\$';

  void setLocale(String languageCode) {
    _locale = Locale(languageCode);
    notifyListeners();
  }

  void setCurrency(String currencyCode) {
    _currency = currencyCode;
    notifyListeners();
  }

  String formatAmount(dynamic amount, {bool showSymbol = true}) {
    double numVal = 0.0;
    if (amount is num) {
      numVal = amount.toDouble();
    } else if (amount is String) {
      numVal = double.tryParse(amount) ?? 0.0;
    }

    if (_currency == 'VND') {
      final int rounded = numVal.round();
      final String str = rounded.abs().toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(str[i]);
      }
      final formatted = (numVal < 0 ? '-' : '') + buffer.toString();
      return showSymbol ? '$formatted ₫' : formatted;
    } else {
      final parts = numVal.abs().toStringAsFixed(2).split('.');
      final str = parts[0];
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(str[i]);
      }
      final formatted = '${numVal < 0 ? '-' : ''}${buffer.toString()}.${parts[1]}';
      return showSymbol ? '\$$formatted' : formatted;
    }
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
      'currency_unit': 'Currency Unit',
      'currency_vnd': 'VND (₫) - Vietnam Dong',
      'currency_usd': 'USD (\$) - US Dollar',
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
      'account_security': 'Account Security',
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'update_password': 'Update Password',
      'change_pin': 'Change Security PIN',
      'current_pin': 'Current PIN (6 digits)',
      'new_pin': 'New PIN (exactly 6 digits)',
      'update_pin': 'Update PIN',
      'forgot_pin': 'Forgot PIN / Reset PIN',
      'account_password': 'Account Password',
      'reset_pin': 'Reset PIN',
      'preferences': 'Preferences',
      'enable_notifications': 'Enable Notifications',
      'logout': 'Logout',
      'pin_code': 'Security PIN Code (6 digits)',
      'pin_required': 'PIN code is required (exactly 6 digits)',
      'time_filter': 'Time Period',
      'filter_today': 'Today',
      'filter_this_month': 'This Month',
      'filter_last_month': 'Last Month',
      'filter_last_7_days': 'Last 7 Days',
      'total_transactions': 'Total Transactions',
      'avg_amount': 'Avg / Transaction',
      'success_rate': 'Success Rate',
      'nfc_step_1': '1. Turn on NFC in your phone settings.',
      'nfc_step_2': '2. Hold your physical card or tag near the back sensor of the phone.',
      'nfc_step_3': '3. Keep steady for 1-2 seconds until you feel haptic vibration.',
      'nfc_step_4': '4. Check data checksum validation result on screen.',
      'faq_q1': 'Q: What if the card is not detected?',
      'faq_a1': 'A: Remove thick phone cases or ensure the NFC chip is enabled in system settings.',
      'faq_q2': 'Q: How secure is the AES Backup?',
      'faq_a2': 'A: Data is encrypted with 256-bit AES cipher, requiring secret key to restore.',
      'contact_calling': 'Calling customer support...',
      'payment_title': 'NFC & QR Payment',
      'nfc_tab': 'NFC Tap',
      'qr_tab': 'Scan QR',
      'select_card_source': 'Select Payment Card Source',
      'payment_amount': 'Payment Amount',
      'note_label': 'Payment Content / Note (Optional)',
      'tap_nfc_btn': 'TAP NFC CARD TO PAY',
      'qr_code_title': 'PAYMENT QR CODE',
      'qr_code_sub': 'Scan this code with e-wallet to pay',
      'total_expense': 'TOTAL EXPENSE',
      'total_income': 'TOTAL RECEIVED',
      'clear_history': 'Clear History',
      'expired': 'EXPIRED',
      'search_hint': 'Search transactions...',
      'confirm_clear_title': 'Confirm Clear History',
      'confirm_clear_msg': 'Are you sure you want to clear all transaction history? All records will be permanently deleted.',
      'cancel': 'Cancel',
      'close': 'Close',
      'status': 'Status',
      'card_type': 'Card Type / NFC',
      'filter_all_cards': 'All Card Types',
      'all_time': 'All Time',
      'transaction_detail': 'Transaction Detail',
      'card_used': 'Card Used:',
      'category': 'Category:',
      'time_label': 'Time:',
      'transaction_id': 'Transaction ID:',
      'no_transactions': 'No transaction history found',
      'history_cleared': 'All transaction history cleared!',
      'clear_history_failed': 'Failed to clear transaction history',
      'error_prefix': 'Error',
      'nfc_transaction': 'NFC Transaction',
      'payment_label': 'Payment',
      'nfc_card': 'NFC Card',
      'update_profile_title': 'Update Personal Info',
      'full_name_label': 'Full Name',
      'username_label': 'Username',
      'phone_label': 'Phone Number',
      'address_label': 'Address',
      'dob_label': 'Date of Birth (DD/MM/YYYY)',
      'save_changes': 'Save Changes',
      'create_pin': 'Create Security PIN',
      'create_pin_sub': 'Create a new 6-digit PIN for account',
      'change_pin_sub': 'Change 6-digit security PIN',
      'forgot_pin_sub': 'Verify via password to reset PIN',
      'update_pass_sub': 'Change login account password',
      'app_config': 'App Configuration',
      'phone_invalid': 'Invalid phone number (10 digits)',
      'dob_invalid': 'Invalid date of birth (Format: DD/MM/YYYY)',
      'update_profile_success': 'Profile updated successfully!',
      'user_default_name': 'NFC User',
      'edit_profile_tooltip': 'Edit personal info',
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
      'currency_unit': 'Đơn vị tiền tệ',
      'currency_vnd': 'VND (₫) - Việt Nam Đồng',
      'currency_usd': 'USD (\$) - Đô la Mỹ',
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
      'account_security': 'Bảo mật tài khoản',
      'current_password': 'Mật khẩu hiện tại',
      'new_password': 'Mật khẩu mới',
      'update_password': 'Cập nhật mật khẩu',
      'change_pin': 'Đổi Mã PIN Bảo Mật',
      'current_pin': 'Mã PIN hiện tại (6 chữ số)',
      'new_pin': 'Mã PIN mới (bắt buộc 6 chữ số)',
      'update_pin': 'Cập nhật Mã PIN',
      'forgot_pin': 'Quên Mã PIN / Đặt lại PIN',
      'account_password': 'Mật khẩu tài khoản',
      'reset_pin': 'Đặt lại Mã PIN',
      'preferences': 'Tùy chọn ứng dụng',
      'enable_notifications': 'Bật thông báo hệ thống',
      'logout': 'Đăng xuất',
      'pin_code': 'Mã PIN bảo mật (6 chữ số)',
      'pin_required': 'Mã PIN bắt buộc phải đúng 6 chữ số',
      'time_filter': 'Khoảng thời gian',
      'filter_today': 'Hôm nay',
      'filter_this_month': 'Tháng này',
      'filter_last_month': 'Tháng trước',
      'filter_last_7_days': '7 ngày qua',
      'total_transactions': 'Số lượt giao dịch',
      'avg_amount': 'Trung bình/giao dịch',
      'success_rate': 'Tỷ lệ thành công',
      'nfc_step_1': '1. Bật NFC trong Cài đặt điện thoại của bạn.',
      'nfc_step_2': '2. Đưa thẻ vật lý hoặc chip NFC đến gần mặt lưng điện thoại.',
      'nfc_step_3': '3. Giữ nguyên 1-2 giây cho đến khi có phản hồi rung.',
      'nfc_step_4': '4. Kiểm tra kết quả xác thực dữ liệu trên màn hình.',
      'faq_q1': 'Hỏi: Nếu không nhận thẻ NFC thì làm sao?',
      'faq_a1': 'Đáp: Tháo ốp lưng quá dày hoặc kiểm tra bật NFC trong Cài đặt hệ thống.',
      'faq_q2': 'Hỏi: Sao lưu AES bảo mật thế nào?',
      'faq_a2': 'Đáp: Dữ liệu được mã hóa thuật toán AES 256-bit chuẩn quân sự.',
      'contact_calling': 'Đang kết nối tổng đài hỗ trợ...',
      'payment_title': 'Thanh Toán NFC & Quét QR',
      'nfc_tab': 'Chạm NFC',
      'qr_tab': 'Quét Mã QR',
      'select_card_source': 'Chọn Nguồn Thẻ Thanh Toán',
      'payment_amount': 'Số Tiền Thanh Toán',
      'note_label': 'Nội dung / Ghi chú thanh toán (Tùy chọn)',
      'tap_nfc_btn': 'CHẠM THẺ NFC ĐỂ THANH TOÁN',
      'qr_code_title': 'MÃ QR THANH TOÁN',
      'qr_code_sub': 'Quét mã này bằng ví điện tử để thanh toán',
      'total_expense': 'TỔNG CHI TIÊU',
      'total_income': 'TỔNG NHẬN TIỀN',
      'clear_history': 'Xóa Lịch Sử Giao Dịch',
      'expired': 'ĐÃ HẾT HẠN',
      'search_hint': 'Tìm kiếm giao dịch...',
      'confirm_clear_title': 'Xác Nhận Xóa Lịch Sử',
      'confirm_clear_msg': 'Bạn có chắc chắn muốn xóa toàn bộ lịch sử giao dịch? Dữ liệu nhật ký giao dịch sẽ bị xóa và không thể khôi phục.',
      'cancel': 'Hủy',
      'close': 'Đóng',
      'status': 'Trạng thái',
      'card_type': 'Loại thẻ / NFC',
      'filter_all_cards': 'Tất cả loại thẻ',
      'all_time': 'Tất cả thời gian',
      'transaction_detail': 'Chi Tiết Giao Dịch',
      'card_used': 'Thẻ sử dụng:',
      'category': 'Danh mục:',
      'time_label': 'Thời gian:',
      'transaction_id': 'Mã giao dịch:',
      'no_transactions': 'Chưa có lịch sử giao dịch',
      'history_cleared': 'Đã xóa toàn bộ lịch sử giao dịch!',
      'clear_history_failed': 'Không thể xóa lịch sử giao dịch',
      'error_prefix': 'Lỗi',
      'nfc_transaction': 'Giao dịch NFC',
      'payment_label': 'Thanh toán',
      'nfc_card': 'Thẻ NFC',
      'update_profile_title': 'Cập Nhật Thông Tin Cá Nhân',
      'full_name_label': 'Họ và tên',
      'username_label': 'Tên người dùng (Username)',
      'phone_label': 'Số điện thoại',
      'address_label': 'Địa chỉ',
      'dob_label': 'Ngày sinh (DD/MM/YYYY)',
      'save_changes': 'Lưu Thay Đổi',
      'create_pin': 'Tạo Mã PIN Bảo Mật',
      'create_pin_sub': 'Tạo mới Mã PIN 6 chữ số cho tài khoản',
      'change_pin_sub': 'Đổi Mã PIN bảo mật 6 chữ số',
      'forgot_pin_sub': 'Xác thực qua mật khẩu để tạo PIN mới',
      'update_pass_sub': 'Đổi mật khẩu tài khoản đăng nhập',
      'app_config': 'Cấu Hình Ứng Dụng',
      'phone_invalid': 'Số điện thoại không hợp lệ (gồm 10 chữ số)',
      'dob_invalid': 'Ngày sinh không hợp lệ (định dạng DD/MM/YYYY)',
      'update_profile_success': 'Cập nhật thông tin cá nhân thành công!',
      'user_default_name': 'Người Dùng NFC',
      'edit_profile_tooltip': 'Cập nhật thông tin cá nhân',
    },
  };

  String getText(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
