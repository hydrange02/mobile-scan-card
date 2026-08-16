import 'package:flutter/material.dart';

/// Theme Provider for managing System-wide Dark Mode & Light Mode support.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Color get backgroundColor => isDarkMode ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5F9);
  Color get cardColor => isDarkMode ? const Color(0xFF1E1E2C) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
  Color get subtitleColor => isDarkMode ? Colors.white70 : Colors.black54;
  Color get cardBorderColor => isDarkMode ? Colors.white12 : Colors.black12;
  Color get dialogBgColor => isDarkMode ? const Color(0xFF16213E) : Colors.white;
  Color get inputFillColor => isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.purpleAccent,
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      cardColor: const Color(0xFF1E1E2C),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E2C),
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.purple,
      scaffoldBackgroundColor: const Color(0xFFF4F5F9),
      cardColor: Colors.white,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.purple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
