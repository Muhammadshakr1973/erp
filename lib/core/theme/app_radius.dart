import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 10.0; // Input, Button
  static const double lg = 12.0; // Card
  static const double xl = 16.0; // Dialog
  static const double xxl = 24.0; // Bottom Sheet
  static const double pill = 999.0; // Badge, Chip

  // BorderRadii
  static final BorderRadius radiusSm = BorderRadius.circular(sm);
  static final BorderRadius radiusMd = BorderRadius.circular(md);
  static final BorderRadius radiusLg = BorderRadius.circular(lg);
  static final BorderRadius radiusXl = BorderRadius.circular(xl);
  static final BorderRadius radiusXxl = BorderRadius.circular(xxl);
  static final BorderRadius radiusPill = BorderRadius.circular(pill);
}
