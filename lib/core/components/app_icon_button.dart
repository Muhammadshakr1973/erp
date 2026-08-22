import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final bool isCircle;

  const AppIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 44.0,
    this.isCircle = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bg = backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final fg = iconColor ?? theme.colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: isCircle ? AppRadius.radiusPill : AppRadius.radiusMd,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: isCircle ? AppRadius.radiusPill : AppRadius.radiusMd,
          child: Center(
            child: Icon(icon, color: fg, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}
