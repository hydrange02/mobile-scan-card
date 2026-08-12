import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  /// Dynamically determines the appropriate base URL for the backend server
  /// based on the platform running the app:
  /// - Android Emulator: http://10.0.2.2:3000
  /// - Web / iOS / Desktop: http://localhost:3000
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
