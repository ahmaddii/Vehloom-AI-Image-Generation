import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class AppColors {
  static bool get _isDark => PreferencesService().darkModeEnabled;

  // Cream / Warm Beige (Scaffold background and canvas)
  static Color get creamBg => _isDark ? const Color(0xFF1E1B15) : const Color(0xFFF5F2EB);
  static Color get creamLight => _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
  static Color get creamDark => _isDark ? const Color(0xFF121212) : const Color(0xFFEDE9E0);

  // Primary Black -> Inverted in dark mode
  static Color get black => _isDark ? const Color(0xFFF5F2EB) : const Color(0xFF1E1B15);
  static Color get darkGrey => _isDark ? const Color(0xFFEBE6DD) : const Color(0xFF2A2A2A);
  static Color get lightGrey => _isDark ? const Color(0xFF4A4A4A) : const Color(0xFFEBE6DD);

  // Coral / Accent (Buttons, indicators, highlights)
  static const Color coral = Color(0xFFFF5A4E);
  static const Color coralLight = Color(0xFFFF8A80);
  static const Color coralDark = Color(0xFFE04F44);

  // Status Colors
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}
