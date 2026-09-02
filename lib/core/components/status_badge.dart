import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';

enum StatusBadgeType { success, warning, danger, info, purple, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;

  // ignore: use_super_parameters
  const StatusBadge({
    Key? key,
    required this.label,
    this.type = StatusBadgeType.neutral,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();

    final successColor = ext?.success ?? AppColors.success;
    final warningColor = ext?.warning ?? AppColors.warning;
    final dangerColor = ext?.danger ?? AppColors.danger;
    final infoColor = ext?.info ?? AppColors.info;
    final purpleColor = ext?.purple ?? AppColors.purple;

    Color bgColor;
    Color textColor;

    switch (type) {
      case StatusBadgeType.success:
        bgColor = successColor.withOpacity(0.15);
        textColor = successColor;
        break;
      case StatusBadgeType.warning:
        bgColor = warningColor.withOpacity(0.15);
        textColor = warningColor;
        break;
      case StatusBadgeType.danger:
        bgColor = dangerColor.withOpacity(0.15);
        textColor = dangerColor;
        break;
      case StatusBadgeType.info:
        bgColor = infoColor.withOpacity(0.15);
        textColor = infoColor;
        break;
      case StatusBadgeType.purple:
        bgColor = purpleColor.withOpacity(0.15);
        textColor = purpleColor;
        break;
      case StatusBadgeType.neutral:
      // ignore: unreachable_switch_default
      default:
        bgColor = theme.colorScheme.onSurface.withOpacity(0.1);
        textColor = theme.colorScheme.onSurface.withOpacity(0.8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusPill,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
