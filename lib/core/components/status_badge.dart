import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';

enum StatusBadgeType { success, warning, danger, info, purple, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;

  const StatusBadge({
    Key? key,
    required this.label,
    this.type = StatusBadgeType.neutral,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    
    Color bgColor;
    Color textColor;

    switch (type) {
      case StatusBadgeType.success:
        bgColor = ext.success.withOpacity(0.15);
        textColor = ext.success;
        break;
      case StatusBadgeType.warning:
        bgColor = ext.warning.withOpacity(0.15);
        textColor = ext.warning;
        break;
      case StatusBadgeType.danger:
        bgColor = ext.danger.withOpacity(0.15);
        textColor = ext.danger;
        break;
      case StatusBadgeType.info:
        bgColor = ext.info.withOpacity(0.15);
        textColor = ext.info;
        break;
      case StatusBadgeType.purple:
        bgColor = ext.purple.withOpacity(0.15);
        textColor = ext.purple;
        break;
      case StatusBadgeType.neutral:
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
