import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTap = onTap != null || onLongPress != null;

    final content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: AppRadius.radiusLg,
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
        boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
      ),
      child: Material(
        color: Colors.transparent,
        child: hasTap
            ? InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: AppRadius.radiusLg,
                child: content,
              )
            : content,
      ),
    );
  }
}
