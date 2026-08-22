import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_sizes.dart';

enum AppButtonType { primary, secondary, outline, text, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: AppSizes.buttonHeightMd,
      child: ElevatedButton(
        style: _getButtonStyle(),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(text, style: _getTextStyle()),
      ),
    );
  }

  ButtonStyle _getButtonStyle() {
    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case AppButtonType.primary:
        bgColor = AppColors.primary;
        fgColor = Colors.white;
        break;
      case AppButtonType.secondary:
        bgColor = AppColors.surface;
        fgColor = AppColors.primary;
        break;
      case AppButtonType.outline:
        bgColor = Colors.transparent;
        fgColor = AppColors.primary;
        borderSide = const BorderSide(color: AppColors.primary, width: 1.5);
        break;
      case AppButtonType.danger:
        bgColor = AppColors.danger;
        fgColor = Colors.white;
        break;
      case AppButtonType.text:
        bgColor = Colors.transparent;
        fgColor = AppColors.primary;
        break;
    }

    return ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      side: borderSide,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  TextStyle _getTextStyle() {
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.danger:
        return AppTextStyles.button.copyWith(color: Colors.white);
      case AppButtonType.secondary:
      case AppButtonType.outline:
      case AppButtonType.text:
        return AppTextStyles.button.copyWith(color: AppColors.primary);
    }
  }
}
