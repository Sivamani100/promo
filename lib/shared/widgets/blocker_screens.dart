import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/app_update_service.dart';
import 'shared_widgets.dart';

class MaintenanceBlockerScreen extends ConsumerWidget {
  const MaintenanceBlockerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Animated gear icon using flutter_animate
                Icon(
                  Iconsax.setting_5,
                  size: 80,
                  color: AppColors.purple,
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .rotate(duration: 10.seconds, curve: Curves.linear),
                const SizedBox(height: 32),
                Text(
                  'Promo Undergoing Upgrades',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We are currently performing server optimizations and database indexing to make your collaborations even faster. We will be back online shortly.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: 'Check Server Status',
                  icon: Iconsax.refresh,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(appConfigCheckerProvider.notifier).check();
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Thank you for your patience.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForceUpdateBlockerScreen extends ConsumerWidget {
  const ForceUpdateBlockerScreen({super.key});

  Future<void> _launchStore() async {
    // Fallback store search details
    final Uri url = Uri.parse('https://play.google.com/store/apps/details?id=com.brand.promo');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[STORE_LAUNCH] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Animated download pulse icon
                Icon(
                  Iconsax.document_download,
                  size: 80,
                  color: AppColors.purple,
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                      duration: 1.8.seconds,
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 32),
                Text(
                  'Update Required',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A critical update containing major speed boosts, haptic improvements, and security enhancements is now available. Please update Promo to continue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: 'Update Now',
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    _launchStore();
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Version: ${ref.read(appConfigCheckerProvider).currentVersion}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
