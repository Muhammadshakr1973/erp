import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

enum MoneyStyleType { standard, large, small }

class AppMoneyDisplay extends StatelessWidget {
  final num amount;
  final MoneyStyleType type;
  final Color? color;
  final bool showColorSemantics; // Green for positive, red for negative
  final bool forceSign;

  const AppMoneyDisplay({
    Key? key,
    required this.amount,
    this.type = MoneyStyleType.standard,
    this.color,
    this.showColorSemantics = false,
    this.forceSign = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String formattedValue = Formatters.number(amount.abs());
    final bool isNegative = amount < 0;

    String prefixSign = '';
    if (isNegative) {
      prefixSign = '-';
    } else if (forceSign && amount > 0) {
      prefixSign = '+';
    }

    // Determine typography and size
    TextStyle numberStyle;
    double symbolSize;

    switch (type) {
      case MoneyStyleType.large:
        numberStyle = AppTextStyles.priceLarge;
        symbolSize = 14.0;
        break;
      case MoneyStyleType.small:
        numberStyle = AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold);
        symbolSize = 10.0;
        break;
      case MoneyStyleType.standard:
      default:
        numberStyle = AppTextStyles.price;
        symbolSize = 12.0;
        break;
    }

    // Determine Color
    Color displayColor;
    if (color != null) {
      displayColor = color!;
    } else if (showColorSemantics) {
      if (amount > 0) {
        displayColor = const Color(0xFF10B981); // Elegant Emerald Green
      } else if (amount < 0) {
        displayColor = const Color(0xFFEF4444); // Elegant Red
      } else {
        displayColor = theme.colorScheme.onSurface;
      }
    } else {
      displayColor = theme.colorScheme.onSurface;
    }

    return RichText(
      textDirection: TextDirection.rtl, // Kurdish RTL for reading currency
      text: TextSpan(
        style: numberStyle.copyWith(color: displayColor),
        children: [
          TextSpan(text: '$prefixSign$formattedValue '),
          TextSpan(
            text: 'د.ع',
            style: TextStyle(
              fontSize: symbolSize,
              fontWeight: FontWeight.normal,
              color: displayColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
