import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;

  const AppTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final outlineInputBorder = OutlineInputBorder(
      borderRadius: AppRadius.radiusMd,
      borderSide: BorderSide(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        width: 1.0,
      ),
    );

    final focusedBorder = outlineInputBorder.copyWith(
      borderSide: BorderSide(
        color: theme.colorScheme.primary,
        width: 1.5,
      ),
    );

    final errorBorder = outlineInputBorder.copyWith(
      borderSide: BorderSide(
        color: theme.colorScheme.error,
        width: 1.5,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: (maxLines > 1 || validator != null) ? null : AppSizes.inputHeight,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            onChanged: onChanged,
            maxLines: maxLines,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textDisabledLight : AppColors.textDisabledLight,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.5))
                  : null,
              suffixIcon: suffixIcon,
              border: outlineInputBorder,
              enabledBorder: outlineInputBorder,
              focusedBorder: focusedBorder,
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder,
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTextStyles.caption.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
