// HARDENING-V2: trust-agent 2026-06-26
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
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
/// Fetches actual warning reasons from the user_warnings table and shows
/// the most recent active reason. Tapping "View Details" opens a bottom sheet
/// listing all active warnings with dates.
class WarningBanner extends StatefulWidget {
  final VoidCallback? onDismiss;

  const WarningBanner({
    super.key,
    this.onDismiss,
  });

  @override
  State<WarningBanner> createState() => _WarningBannerState();
}

class _WarningBannerState extends State<WarningBanner> {
  bool _isVisible = true;
  List<Map<String, dynamic>> _activeWarnings = [];
  bool _loaded = false;
  String _latestReason = 'Your account has been warned for violating community guidelines.';

  @override
  void initState() {
    super.initState();
    _fetchWarnings();
  }

  Future<void> _fetchWarnings() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await SupabaseService.client
          .from('user_warnings')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final warnings = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _activeWarnings = warnings;
          _loaded = true;
          if (warnings.isNotEmpty) {
            _latestReason = warnings.first['reason'] as String? ??
                'Your account has been warned for violating community guidelines.';
          }
        });
      }
    } catch (e) {
      debugPrint('[WARNING BANNER] Error fetching warnings: $e');
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  void _showWarningDetailsSheet() {
    final isDark = AppColors.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2, color: AppColors.warning, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account Warnings',
                        style: AppTextStyles.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_activeWarnings.length} active warning${_activeWarnings.length != 1 ? 's' : ''} on your account',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Warnings list
              Flexible(
                child: _activeWarnings.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No active warnings found.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shrinkWrap: true,
                        itemCount: _activeWarnings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final w = _activeWarnings[idx];
                          final createdAt = DateTime.tryParse(w['created_at'] ?? '');
                          final dateStr = createdAt != null
                              ? DateFormat('MMM dd, yyyy · hh:mm a').format(createdAt.toLocal())
                              : 'Unknown date';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.orange.withValues(alpha: 0.06)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Iconsax.warning_2,
                                      size: 14,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'WARNING ${idx + 1}',
                                      style: AppTextStyles.overline.copyWith(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      dateStr,
                                      style: AppTextStyles.captionSm.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  w['reason'] ?? 'No reason provided',
                                  style: AppTextStyles.bodySm.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Footer note
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Text(
                  'Repeated violations may result in account suspension. If you believe a warning was issued in error, please contact support@promoapp.com.',
                  style: AppTextStyles.captionSm.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isDark = AppColors.isDarkMode;
    final warningTextColor = isDark ? const Color(0xFFFFEBAD) : const Color(0xFF92400E);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2600) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF856404).withValues(alpha: 0.5) : const Color(0xFFFDE8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Iconsax.warning_2,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _latestReason,
                  style: AppTextStyles.bodySm.copyWith(
                    color: warningTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: warningTextColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _isVisible = false;
                  });
                  widget.onDismiss?.call();
                },
              ),
            ],
          ),
          if (_loaded && _activeWarnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _showWarningDetailsSheet,
              child: Row(
                children: [
                  const SizedBox(width: 32), // align with text above (icon 20 + gap 12)
                  Text(
                    'View Details (${_activeWarnings.length} warning${_activeWarnings.length != 1 ? 's' : ''})',
                    style: AppTextStyles.captionSm.copyWith(
                      color: warningTextColor,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: warningTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: warningTextColor,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
