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
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  ThemeColors get colors {
    if (isDark) {
      return ThemeColors(
        primary: const Color.fromARGB(255, 63, 20, 235),
        surface: const Color.fromARGB(255, 4, 5, 8),
        card: const Color(0xFF101827),
        text: Colors.white,
        textSecondary: const Color(0xFF9CA3AF),
        border: const Color(0xFF1F2937),
      );
    }
    return ThemeColors(
      primary: const Color(0xFF271085),
      surface: const Color(0xFFF3F4F6),
      card: Colors.white,
      text: const Color(0xFF111827),
      textSecondary: const Color(0xFF6B7280),
      border: const Color(0xFFE5E7EB),
    );
  }

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.surface,
      colorScheme: ColorScheme.light(
        primary: colors.primary,
        secondary: colors.primary,
        surface: colors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.card,
        foregroundColor: colors.text,
        elevation: 0,
      ),
      cardColor: colors.card,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.surface,
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        secondary: colors.primary,
        surface: colors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.card,
        foregroundColor: colors.text,
        elevation: 0,
      ),
      cardColor: colors.card,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: colors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }

  void toggleTheme() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
