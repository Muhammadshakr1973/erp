import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand
  static const Color primary = Color(0xFF122D5A);
  static const Color primaryLight = Color(0xFFEBF0FA);

  // Status Semantic
  static const Color success = Color(0xFF0A9C6E);
  static const Color warning = Color(0xFFD4820A);
  static const Color danger = Color(0xFFD93535);
  static const Color info = Color(0xFF2678D4);
  static const Color purple = Color(0xFF7B41D6);

  // Price Tiers
  static const Color n1 = success;
  static const Color n2 = warning;
  static const Color n3 = Color(0xFF5B6B84);

  // Neutrals & Typography (Light Mode)
  static const Color backgroundLight = Color(0xFFF7F9FD);
  static const Color surfaceLight = Color(0xFFEFF4FB);
  static const Color borderLight = Color(0xFFD1DCE8);
  
  static const Color textPrimaryLight = Color(0xFF0D1B2E);
  static const Color textSecondaryLight = Color(0xFF5B6B84);
  static const Color textDisabledLight = Color(0xFF9AABBB);

  // Dark Mode colors
  static const Color primaryDark = Color(0xFF4A7FD4);
  static const Color backgroundDark = Color(0xFF0F1419);
  static const Color surfaceDark = Color(0xFF1A2332);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerDark = Color(0xFFF87171);
  
  static const Color textPrimaryDark = Color(0xFFF0F4FA);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF2A3548);
}
