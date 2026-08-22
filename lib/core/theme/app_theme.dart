import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart'; // ئەمەمان زیاد کرد بۆ هێنانی ناوی فۆنتەکە

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // چالاککردنی فۆنتی ڕووداو بۆ هەموو ئەپەکە!
      fontFamily: AppTextStyles.fontFamily,

      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.success, // بەکارهێنانی success وەک ڕەنگی دووەم
        error: AppColors.danger, // گۆڕدرا بۆ danger
        surface: AppColors.surface,
      ),

      // دیزاینی سەرەوەی پەڕەکان (AppBar)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}
