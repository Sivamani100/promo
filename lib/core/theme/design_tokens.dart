import 'package:flutter/material.dart';

/// THIS FILE IS THE SINGLE SOURCE OF TRUTH FOR EVERY VISUAL VALUE IN THE APP.
/// No screen should ever hardcode any of these values.
///
/// Usage: `DesignTokens.space16`, `DesignTokens.radiusMD`, etc.
class DesignTokens {
  DesignTokens._();

  // ── SPACING ──────────────────────────────────────────────────────────────
  static const double space2  = 2.0;
  static const double space4  = 4.0;
  static const double space6  = 6.0;
  static const double space8  = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;   // Standard page margin
  static const double space20 = 20.0;
  static const double space24 = 24.0;   // Section gap
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;

  // ── BORDER RADIUS ────────────────────────────────────────────────────────
  static const double radiusXS   = 4.0;
  static const double radiusSM   = 8.0;
  static const double radiusMD   = 12.0;
  static const double radiusLG   = 16.0;
  static const double radiusXL   = 20.0;
  static const double radius2XL  = 24.0;
  static const double radiusFull = 999.0;  // For pills/chips

  // ── ICON SIZES ───────────────────────────────────────────────────────────
  static const double iconXS = 14.0;
  static const double iconSM = 18.0;
  static const double iconMD = 22.0;
  static const double iconLG = 28.0;
  static const double iconXL = 36.0;

  // ── AVATAR SIZES ─────────────────────────────────────────────────────────
  static const double avatarXS = 28.0;   // In chat message
  static const double avatarSM = 36.0;   // In list tiles
  static const double avatarMD = 48.0;   // In cards
  static const double avatarLG = 64.0;   // In profile headers
  static const double avatarXL = 88.0;   // In profile page hero

  // ── ELEVATION / SHADOW ───────────────────────────────────────────────────
  static const List<BoxShadow> shadowSM = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowMD = [
    BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowLG = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  // ── ANIMATION DURATIONS ──────────────────────────────────────────────────
  static const Duration durationXS = Duration(milliseconds: 80);
  static const Duration durationSM = Duration(milliseconds: 150);
  static const Duration durationMD = Duration(milliseconds: 250);
  static const Duration durationLG = Duration(milliseconds: 350);
  static const Duration durationXL = Duration(milliseconds: 500);

  // ── ANIMATION CURVES ─────────────────────────────────────────────────────
  static const Curve curveDefault    = Curves.easeOutCubic;
  static const Curve curveSnappy     = Curves.easeOutExpo;
  static const Curve curveElastic    = Curves.elasticOut;
  static const Curve curveDecelerate = Curves.decelerate;

  // ── TAP TARGET MINIMUM ───────────────────────────────────────────────────
  static const double minTapTarget = 48.0; // WCAG minimum

  // ── CONTENT WIDTH ────────────────────────────────────────────────────────
  static const double maxContentWidth = 600.0; // For tablet layouts

  // ── PAGE MARGINS ─────────────────────────────────────────────────────────
  static const double pageMarginHorizontal = 16.0;
  static const double pageMarginVertical   = 5.0;
  static const double appBarMarginHorizontal = 24.0;

  // ── BOTTOM NAV OFFSET ────────────────────────────────────────────────────
  static const double bottomScreenPadding = 100.0;
}
