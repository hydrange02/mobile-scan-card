import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  /// Override this variable if testing on a physical phone over Wi-Fi
  /// Example: ApiConfig.customBaseUrl = 'http://192.168.1.15:3000';
  static String? customBaseUrl;

  /// Dynamically determines the appropriate base URL for the backend server
  /// based on the platform running the app:
  /// - Android Emulator: http://10.0.2.2:3000
  /// - Web / iOS / Desktop: http://localhost:3000
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
