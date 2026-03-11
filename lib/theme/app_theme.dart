import 'package:flutter/material.dart';

class ThemeColors {
  final Color primary;
  final Color surface;
  final Color card;
  final Color text;
  final Color textSecondary;
  final Color border;

  ThemeColors({
    required this.primary,
    required this.surface,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.border,
  });
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark; // Default to dark for glassmorphism

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  ThemeColors get colors {
    if (isDark) {
      return ThemeColors(
        primary: const Color(0xFF6366F1), // Indigo 500
        surface: const Color(0xFF0F172A), // Slate 900
        card: const Color(0xFF1E293B), // Slate 800
        text: Colors.white,
        textSecondary: const Color(0xFF94A3B8), // Slate 400
        border: const Color(0xFF334155), // Slate 700
      );
    }
    return ThemeColors(
      primary: const Color(0xFF4F46E5), // Indigo 600
      surface: const Color(0xFFF8FAFC), // Slate 50
      card: Colors.white,
      text: const Color(0xFF0F172A), // Slate 900
      textSecondary: const Color(0xFF64748B), // Slate 500
      border: const Color(0xFFE2E8F0), // Slate 200
    );
  }

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF4F46E5),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF4F46E5),
        surface: Color(0xFFF8FAFC),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      cardColor: Colors.white,
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(color: Color(0xFF0F172A)),
        titleLarge: TextStyle(color: Color(0xFF0F172A)),
        titleMedium: TextStyle(color: Color(0xFF0F172A)),
        titleSmall: TextStyle(color: Color(0xFF0F172A)),
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF6366F1),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF6366F1),
        surface: Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardColor: const Color(0xFF1E293B),
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),
    );
  }

  void toggleTheme() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
