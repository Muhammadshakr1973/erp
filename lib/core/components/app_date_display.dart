import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

class AppDateDisplay extends StatelessWidget {
  final DateTime dateTime;
  final bool showTime;
  final bool showIcon;
  final Color? color;
  final double? fontSize;

  const AppDateDisplay({
    Key? key,
    required this.dateTime,
    this.showTime = false,
    this.showIcon = true,
    this.color,
    this.fontSize,
  }) : super(key: key);

  String _getRelativeKurdishTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'ئێستا';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} خولەک پێش ئێستا';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} کاتژمێر پێش ئێستا';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ڕۆژ پێش ئێستا';
    } else {
      return showTime ? Formatters.dateTime(dt) : Formatters.date(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayColor = color ??
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final textStyle = AppTextStyles.caption.copyWith(
      color: displayColor,
      fontSize: fontSize,
    );

    final textWidget = Text(
      _getRelativeKurdishTime(dateTime),
      style: textStyle,
      textDirection: TextDirection.rtl,
    );

    if (!showIcon) {
      return textWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          showTime ? Symbols.schedule : Symbols.calendar_month,
          size: (fontSize ?? 12.0) + 2,
          color: displayColor.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        textWidget,
      ],
    );
  }
}
