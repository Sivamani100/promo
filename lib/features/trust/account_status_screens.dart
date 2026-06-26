// HARDENING-V2: trust-agent 2026-06-26
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Full screen view shown to permanently banned users.
class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDarkMode;
    final profile = ref.watch(authProvider.select((s) => s.profile));
    final reason = profile?['suspension_reason'] as String? ?? 'Violation of Community Guidelines';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.user_remove,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Account Banned',
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been permanently suspended for violating our platform community guidelines and terms of service.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REASON FOR BAN:',
                      style: AppTextStyles.overline.copyWith(color: AppColors.error),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'If you believe this is a mistake, please contact our support team at support@promoapp.com.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Sign Out',
                isPrimary: false,
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen view shown to temporarily suspended users.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppColors.isDarkMode;
    final profile = ref.watch(authProvider.select((s) => s.profile));
    final reason = profile?['suspension_reason'] as String? ?? 'Temporary suspension for account review.';
    final suspensionUntilStr = profile?['suspension_until'] as String?;
    
    DateTime? suspensionUntil;
    if (suspensionUntilStr != null) {
      suspensionUntil = DateTime.tryParse(suspensionUntilStr);
    }

    final formattedDate = suspensionUntil != null
        ? DateFormat('MMMM dd, yyyy - hh:mm a').format(suspensionUntil.toLocal())
        : 'Indefinitely';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.lock_1,
                  color: AppColors.warning,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Account Suspended',
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been temporarily restricted from accessing platform features.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUSPENSION REASON:',
                      style: AppTextStyles.overline.copyWith(color: AppColors.warning),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SUSPENDED UNTIL:',
                      style: AppTextStyles.overline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Please review our community guidelines. Your access will be automatically restored after the suspension window expires.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Sign Out',
                isPrimary: false,
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dismissible banner shown at the top of the home feed if the user has warnings.
class WarningBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;

  const WarningBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  State<WarningBanner> createState() => _WarningBannerState();
}

class _WarningBannerState extends State<WarningBanner> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isDark = AppColors.isDarkMode;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2600) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF856404).withOpacity(0.5) : const Color(0xFFFDE8E8),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Iconsax.warning_2,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.message,
              style: AppTextStyles.bodySm.copyWith(
                color: isDark ? const Color(0xFFFFEBAD) : const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: isDark ? const Color(0xFFFFEBAD) : const Color(0xFF92400E),
            onPressed: () {
              setState(() {
                _isVisible = false;
              });
              if (widget.onDismiss != null) {
                widget.onDismiss!();
              }
            },
          ),
        ],
      ),
    );
  }
}
