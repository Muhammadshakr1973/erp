import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_text_styles.dart';

enum AppButtonType { primary, secondary, outline, text, danger }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    // Determine height
    double height;
    switch (size) {
      case AppButtonSize.lg:
        height = AppSizes.buttonHeightLg;
        break;
      case AppButtonSize.sm:
        height = AppSizes.buttonHeightSm;
        break;
      case AppButtonSize.md:
      // ignore: unreachable_switch_default
      default:
        height = AppSizes.buttonHeightMd;
        break;
    }

    // Colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;
    Color borderColor = Colors.transparent;

    switch (type) {
      case AppButtonType.primary:
        backgroundColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
        break;
      case AppButtonType.secondary:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.primary;
        break;
      case AppButtonType.outline:
        backgroundColor = Colors.transparent;
        textColor = theme.colorScheme.primary;
        borderColor = theme.colorScheme.primary;
        break;
      case AppButtonType.text:
        backgroundColor = Colors.transparent;
        textColor = theme.colorScheme.primary;
        break;
      case AppButtonType.danger:
        backgroundColor = theme.colorScheme.error;
        textColor = theme.colorScheme.onError;
        break;
    }

    if (isDisabled && type != AppButtonType.text) {
      backgroundColor = isDark ? AppColors.borderDark : AppColors.borderLight;
      textColor = isDark
          ? AppColors.textDisabledLight
          : AppColors.textDisabledLight;
      borderColor = Colors.transparent;
    }

    Widget content = Text(
      text,
      style: AppTextStyles.button.copyWith(
        color: textColor,
        fontSize: size == AppButtonSize.sm ? 13 : 15,
      ),
    );

    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: textColor,
            size: size == AppButtonSize.sm ? 18 : 22,
          ),
          const SizedBox(width: 8),
          content,
        ],
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: type == AppButtonType.outline
          ? OutlinedButton(
              onPressed: isDisabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: content,
            )
          : type == AppButtonType.text
          ? TextButton(
              onPressed: isDisabled ? null : onPressed,
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: content,
            )
          : ElevatedButton(
              onPressed: isDisabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: textColor,
                backgroundColor: backgroundColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: content,
            ),
    );
  }
}
