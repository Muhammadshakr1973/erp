import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_durations.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

enum SnackbarType { success, error, warning, info }

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Color bgColor;
    IconData icon;

    switch (type) {
      case SnackbarType.success:
        bgColor = AppColors.success;
        icon = Symbols.check_circle;
        break;
      case SnackbarType.error:
        bgColor = AppColors.danger;
        icon = Symbols.error;
        break;
      case SnackbarType.warning:
        bgColor = AppColors.warning;
        icon = Symbols.warning;
        break;
      case SnackbarType.info:
      // ignore: unreachable_switch_default
      default:
        bgColor = AppColors.info;
        icon = Symbols.info;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      margin: const EdgeInsets.all(16),
      duration: AppDurations.snackbar,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
