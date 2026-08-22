import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class AppDialog {
  AppDialog._();

  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'بەڵێ',
    String cancelText = 'نەخێر',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
          title: Text(
            title,
            style: AppTextStyles.h2.copyWith(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            AppButton(
              text: cancelText,
              type: AppButtonType.text,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppButton(
              text: confirmText,
              type: isDanger ? AppButtonType.danger : AppButtonType.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String okText = 'باشە',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
          title: Text(
            title,
            style: AppTextStyles.h2.copyWith(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            AppButton(
              text: okText,
              type: AppButtonType.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
