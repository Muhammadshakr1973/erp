import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ignore: unused_import
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static String get fontFamily => GoogleFonts.vazirmatn().fontFamily ?? 'Vazirmatn';

  // Headings
  static TextStyle get displayLarge => GoogleFonts.vazirmatn(
    fontSize: 32,
    fontWeight: FontWeight.w700, // Bold
  );

  static TextStyle get displayMedium => GoogleFonts.vazirmatn(
    fontSize: 26,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get h1 => GoogleFonts.vazirmatn(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get h2 => GoogleFonts.vazirmatn(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get h3 => GoogleFonts.vazirmatn(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  // Body
  static TextStyle get bodyLarge => GoogleFonts.vazirmatn(
    fontSize: 15,
    fontWeight: FontWeight.w400, // Regular
  );

  static TextStyle get bodyMedium => GoogleFonts.vazirmatn(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get bodyBold => GoogleFonts.vazirmatn(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bodyMediumBold => bodyBold;

  static TextStyle get bodySmall => GoogleFonts.vazirmatn(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get caption => GoogleFonts.vazirmatn(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get overline => GoogleFonts.vazirmatn(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  // Specific Elements
  static TextStyle get price => GoogleFonts.vazirmatn(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get priceLarge => GoogleFonts.vazirmatn(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get button => GoogleFonts.vazirmatn(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
}
