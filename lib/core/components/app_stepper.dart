import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_text_styles.dart';

class AppStepper extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  const AppStepper({
    Key? key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
  }) : super(key: key);

  void _decrement() {
    if (value > min) {
      onChanged(value - 1);
    }
  }

  void _increment() {
    if (max == null || value < max!) {
      onChanged(value + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bool canDecrement = value > min;
    final bool canIncrement = max == null || value < max!;

    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final iconColor = theme.colorScheme.primary;
    final disabledIconColor = isDark ? AppColors.textDisabledLight : AppColors.textDisabledLight;

    return Container(
      width: AppSizes.stepperWidth,
      height: AppSizes.stepperHeight,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canDecrement ? _decrement : null,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(AppRadius.md)),
                child: Center(
                  child: Icon(
                    Symbols.remove,
                    size: 16,
                    color: canDecrement ? iconColor : disabledIconColor,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            color: borderColor,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: AppTextStyles.bodyBold,
              ),
            ),
          ),
          Container(
            width: 1,
            color: borderColor,
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canIncrement ? _increment : null,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.md)),
                child: Center(
                  child: Icon(
                    Symbols.add,
                    size: 16,
                    color: canIncrement ? iconColor : disabledIconColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
