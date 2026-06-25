import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global premium snackbar system.
///
/// A single, unified floating pill notification used across the entire app.
/// Features the app logo on the left and a message beside it.
///
/// Usage:
/// ```dart
/// AppSnackbar.show(context, 'Hello');
/// AppSnackbar.success(context, 'Saved');
/// AppSnackbar.error(context, 'Failed');
/// AppSnackbar.warning(context, 'Warning');
/// AppSnackbar.info(context, 'Info');
/// ```
class AppSnackbar {
  AppSnackbar._();

  // ── Durations ──────────────────────────────────────────────────────────
  static const _successDuration = Duration(seconds: 2);
  static const _infoDuration = Duration(milliseconds: 2500);
  static const _warningDuration = Duration(seconds: 3);
  static const _errorDuration = Duration(milliseconds: 3500);

  // ── Design tokens ──────────────────────────────────────────────────────
  static const _bgColor = Color(0xFF1E1E1E);
  static const _pillRadius = 28.0;
  static const _logoSize = 22.0;
  static const _horizontalPadding = 20.0;
  static const _verticalPadding = 14.0;
  static const _logoTextGap = 14.0;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Show a generic notification (default 2s).
  static void show(BuildContext context, String message, {Duration? duration}) {
    _display(context, message, duration ?? _successDuration);
  }

  /// Success feedback — 2 seconds.
  static void success(BuildContext context, String message) {
    _display(context, message, _successDuration);
  }

  /// Error feedback — 3.5 seconds.
  static void error(BuildContext context, String message) {
    _display(context, message, _errorDuration);
  }

  /// Warning feedback — 3 seconds.
  static void warning(BuildContext context, String message) {
    _display(context, message, _warningDuration);
  }

  /// Informational feedback — 2.5 seconds.
  static void info(BuildContext context, String message) {
    _display(context, message, _infoDuration);
  }

  // ── Internal ───────────────────────────────────────────────────────────

  static void _display(BuildContext context, String message, Duration duration) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Clear any existing snackbar to avoid stacking
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: _PremiumSnackbarContent(message: message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 24,
        ),
        duration: duration,
        dismissDirection: DismissDirection.down,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pillRadius),
        ),
      ),
    );
  }
}

/// The actual visual content of the premium snackbar.
class _PremiumSnackbarContent extends StatelessWidget {
  final String message;

  const _PremiumSnackbarContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
          minHeight: 52,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSnackbar._horizontalPadding,
            vertical: AppSnackbar._verticalPadding,
          ),
          decoration: BoxDecoration(
            color: AppSnackbar._bgColor,
            borderRadius: BorderRadius.circular(AppSnackbar._pillRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/Logo.png',
                  width: AppSnackbar._logoSize,
                  height: AppSnackbar._logoSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: AppSnackbar._logoSize,
                    height: AppSnackbar._logoSize,
                  ),
                ),
              ),
              const SizedBox(width: AppSnackbar._logoTextGap),
              // Message text
              Flexible(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
