import 'package:flutter/animation.dart';

class AppDurations {
  AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250); // Page transition
  static const Duration slow = Duration(milliseconds: 350); // Bottom sheet
  static const Duration slower = Duration(milliseconds: 500);

  // Specific components
  static const Duration snackbar = Duration(seconds: 3);
  static const Duration shimmerLoop = Duration(milliseconds: 1200);
  static const Duration debounceSearch = Duration(milliseconds: 400);

  static const Curve defaultCurve = Curves.easeOutCubic;
}
