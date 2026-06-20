import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter(color: AppColors.textPrimary);

  // Headings
  static TextStyle get h1 => _base.copyWith(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static TextStyle get h2 => _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static TextStyle get h3 => _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static TextStyle get h4 => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);

  // Body
  static TextStyle get bodyLg => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get body => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySm => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400);

  // Labels
  static TextStyle get label => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
  static TextStyle get labelSm => _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
  static TextStyle get labelXs => _base.copyWith(fontSize: 10, fontWeight: FontWeight.w700);

  // Caption
  static TextStyle get caption => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get captionSm => _base.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textMuted);

  // Uppercase label
  static TextStyle get overline => _base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      );

  // Button
  static TextStyle get button => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get buttonSm => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w700);
}