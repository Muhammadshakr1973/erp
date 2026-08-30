import 'package:flutter/material.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color purple;

  final Color n1;
  final Color n2;
  final Color n3;

  const AppThemeExtension({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.purple,
    required this.n1,
    required this.n2,
    required this.n3,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? purple,
    Color? n1,
    Color? n2,
    Color? n3,
  }) {
    return AppThemeExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      purple: purple ?? this.purple,
      n1: n1 ?? this.n1,
      n2: n2 ?? this.n2,
      n3: n3 ?? this.n3,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      n1: Color.lerp(n1, other.n1, t)!,
      n2: Color.lerp(n2, other.n2, t)!,
      n3: Color.lerp(n3, other.n3, t)!,
    );
  }
}
