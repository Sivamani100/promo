import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Comprehensive typography system for the Promo app.
///
/// Apply colors separately via `.copyWith(color: ...)` to support
/// dark/light mode: `AppTextStyles.h1.copyWith(color: AppColors.textPrimary)`
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter(color: AppColors.textPrimary);

  // ── DISPLAY ──────────────────────────────────────────────────────────────
  static TextStyle get display   => _base.copyWith(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5);
  static TextStyle get displaySM => _base.copyWith(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3);

  // ── HEADING ──────────────────────────────────────────────────────────────
  static TextStyle get h1 => _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2);
  static TextStyle get h2 => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3);
  static TextStyle get h3 => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get h4 => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);

  // ── BODY ─────────────────────────────────────────────────────────────────
  static TextStyle get bodyLg => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);
  static TextStyle get body   => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodySm => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);

  // ── LABEL ────────────────────────────────────────────────────────────────
  static TextStyle get labelLg => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500, height: 1.2);
  static TextStyle get label   => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle get labelSm => _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle get labelXs => _base.copyWith(fontSize: 10, fontWeight: FontWeight.w700, height: 1.2);

  // ── CAPTION ──────────────────────────────────────────────────────────────
  static TextStyle get caption   => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.textSecondary);
  static TextStyle get captionSm => _base.copyWith(fontSize: 10, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.textMuted);

  // ── SPECIAL ──────────────────────────────────────────────────────────────
  static TextStyle get overline => _base.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.textMuted,
  );
  static TextStyle get code => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, fontFamily: 'monospace');

  // ── BUTTON ───────────────────────────────────────────────────────────────
  static TextStyle get button   => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.0, letterSpacing: 0.1);
  static TextStyle get buttonSm => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.0);

  // ── CHAT SPECIFIC ────────────────────────────────────────────────────────
  static TextStyle get chatMessage => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45);
  static TextStyle get chatTime    => _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, height: 1.0, color: AppColors.textMuted);
  static TextStyle get chatName    => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2);
}