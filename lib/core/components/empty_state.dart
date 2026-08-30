import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onAction;

  const EmptyState({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Symbols.inbox,
    this.buttonText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark
                ? AppColors.textDisabledLight
                : AppColors.textDisabledLight,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h2.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          if (buttonText != null && onAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: AppButton(
                text: buttonText!,
                onPressed: onAction,
                type: AppButtonType.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
