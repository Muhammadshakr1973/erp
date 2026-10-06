import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand
  static const Color primary = Color(0xFF122D5A);
  static const Color primaryLight = Color(0xFFEBF0FA);

  // Status Semantic (Light Mode)
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
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFEFF4FB);
  static const Color borderLight = Color(0xFFD1DCE8);

  static const Color textPrimaryLight = Color(0xFF0D1B2E);
  static const Color textSecondaryLight = Color(0xFF5B6B84);
  static const Color textDisabledLight = Color(0xFF9AABBB);

  // Neutral Aliases
  static const Color textSecondary = textSecondaryLight;
  static const Color textTertiary = textDisabledLight;

  // Dark Mode colors (Modern Professional Slate/Midnight Palette)
  static const Color primaryDark = Color(0xFF3A86FF); // Brilliant clear electric blue
  static const Color primaryContainerDark = Color(0xFF162541); // Deep rich navy container
  static const Color backgroundDark = Color(0xFF080C14); // Ultra-rich deep space midnight black background
  static const Color surfaceDark = Color(0xFF10192A); // High-contrast premium deep midnight card surface
  static const Color surfaceContainerDark = Color(0xFF17243B); // Dark slate/navy container
  static const Color surfaceContainerHighestDark = Color(0xFF223250); // Dark accent slate container
  
  static const Color successDark = Color(0xFF00E676); // Pure electric green
  static const Color warningDark = Color(0xFFFFB300); // Vibrant glowing gold/amber
  static const Color dangerDark = Color(0xFFFE3F30); // Vibrant neon coral/red
  static const Color infoDark = Color(0xFF00E5FF); // Electric bright cyan/sky blue
  static const Color purpleDark = Color(0xFFD500F9); // Vibrant neon purple/violet

  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50 (Ultra crisp)
  static const Color textSecondaryDark = Color(0xFFE2E8F0); // Slate 200 (Clear, legible)
  static const Color textDisabledDark = Color(0xFF64748B); // Slate 500
  static const Color borderDark = Color(0xFF1E2E4A); // Clean, structured deep midnight-blue border

  /// Helper to get an adaptive color from a given base color
  static Color getAdaptiveColor(BuildContext context, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return color;

    if (color == primary) return primaryDark;
    if (color == success) return successDark;
    if (color == warning) return warningDark;
    if (color == danger) return dangerDark;
    if (color == info) return infoDark;
    if (color == purple) return purpleDark;
    
    return color;
  }

  /// Helper to get adaptive primary color based on theme
  static Color primaryAdaptive(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Helper to get adaptive primary text color based on theme
  static Color textPrimaryAdaptive(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Helper to get adaptive secondary text color based on theme
  static Color textSecondaryAdaptive(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  /// Helper to get adaptive surface/card background color based on theme
  static Color surfaceAdaptive(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Helper to get adaptive border color based on theme
  static Color borderAdaptive(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }
}
