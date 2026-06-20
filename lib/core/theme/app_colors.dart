import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDarkMode = false; // Light theme by default

  // Backgrounds
  static Color get background => isDarkMode ? const Color(0xFF000000) : const Color(0xFFF8F9FA);
  static Color get surface => isDarkMode ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
  static Color get surface2 => isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F1F5);
  static Color get surface3 => isDarkMode ? const Color(0xFF1C1C1C) : const Color(0xFFE2E2E9);

  // Text
  static Color get textPrimary => isDarkMode ? const Color(0xFFFBFBEF) : const Color(0xFF1A1A1A);
  static Color get textSecondary => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.6) : const Color(0xFF626262);
  static Color get textMuted => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.4) : const Color(0xFF9E9E9E);
  static Color get textDisabled => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.3) : const Color(0xFFD1D1D6);

  // Accent / Brand
  static Color get accent => isDarkMode ? const Color(0xFFFBFBEF) : const Color(0xFF000000);
  static Color get accentOnDark => isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  // Borders
  static Color get border => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.2) : const Color(0xFFE5E7EB);
  static Color get borderHover => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.4) : const Color(0xFF9CA3AF);
  static Color get borderSubtle => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.1) : const Color(0xFFF3F4F6);
  static Color get borderDashed => isDarkMode ? const Color.fromRGBO(251, 251, 239, 0.3) : const Color(0xFFD1D5DB);

  // Purple accent (used in profile completeness)
  static Color get purple => const Color(0xFFA855F7);
  static Color get purpleLight => const Color(0xFFC084FC);
  static Color get indigo => const Color(0xFF6366F1);

  // Semantic
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF38BDF8);

  // Tags
  static const Color fashionTag = Color(0xFFC084FC);
  static const Color techTag = Color(0xFF38BDF8);
  static const Color foodTag = Color(0xFFFB923C);
  static const Color fitnessTag = Color(0xFF4ADE80);
  static const Color beautyTag = Color(0xFFF472B6);
  static const Color travelTag = Color(0xFFFBBF24);
  static const Color gamingTag = Color(0xFFA78BFA);
  static Color get lifestyleTag => isDarkMode ? const Color(0xFFFBFBEF) : const Color(0xFF000000);

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'Fashion': return fashionTag;
      case 'Tech': return techTag;
      case 'Food': return foodTag;
      case 'Fitness': return fitnessTag;
      case 'Beauty': return beautyTag;
      case 'Travel': return travelTag;
      case 'Gaming': return gamingTag;
      case 'Lifestyle': return lifestyleTag;
      default: return textPrimary;
    }
  }
}