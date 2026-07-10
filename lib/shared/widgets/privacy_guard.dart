import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppPrivacyGuard automatically blurs the screen when the app enters the background
/// or multitasking view, protecting sensitive details from previews.
class AppPrivacyGuard extends StatefulWidget {
  final Widget child;
  const AppPrivacyGuard({super.key, required this.child});

  @override
  State<AppPrivacyGuard> createState() => _AppPrivacyGuardState();
}

class _AppPrivacyGuardState extends State<AppPrivacyGuard> with WidgetsBindingObserver {
  bool _isBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _isBackground = state == AppLifecycleState.inactive || 
                      state == AppLifecycleState.paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBackground) {
      return widget.child;
    }

    final isDark = AppColors.isDarkMode;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned.fill(
          child: Container(
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.shield_security,
                        size: 64,
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Promo Secure Area',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Privacy protection active',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
