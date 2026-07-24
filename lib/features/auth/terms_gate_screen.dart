import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_card.dart';

class TermsGateScreen extends ConsumerStatefulWidget {
  const TermsGateScreen({super.key});

  @override
  ConsumerState<TermsGateScreen> createState() => _TermsGateScreenState();
}

class _TermsGateScreenState extends ConsumerState<TermsGateScreen> {
  bool _agreedToTerms = false;
  bool _isEighteenOrOlder = false;
  bool _isLoading = false;

  void _onTermsTapped() {
    final role = ref.read(authProvider).role ?? 'influencer';
    context.push('/$role/settings/tos');
  }

  void _onPrivacyTapped() {
    final role = ref.read(authProvider).role ?? 'influencer';
    context.push('/$role/settings/privacy-policy');
  }

  Future<void> _handleAccept() async {
    if (!_agreedToTerms || !_isEighteenOrOlder) return;

    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final currentProfile = ref.read(authProvider).profile ?? {};
      final currentPrefs = Map<String, dynamic>.from(currentProfile['preferences'] ?? {});

      currentPrefs['tos_accepted_at'] = DateTime.now().toIso8601String();
      currentPrefs['tos_version_accepted'] = '1.0';

      await authNotifier.updatePreferences(currentPrefs);
      
      // Let GoRouter redirect pick up the change and forward to the next screen (e.g., /consent)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating agreements: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space16,
              vertical: DesignTokens.space24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DesignTokens.maxContentWidth,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: DesignTokens.space16),
                  
                  // Brand/Logo area
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.space16),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gavel_rounded,
                        size: DesignTokens.avatarMD,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space24),

                  // Header
                  Text(
                    'Before you continue',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displaySM.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    'Please review our community commitment and legal terms.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space32),

                  // Plain English Summary Card
                  AppCard(
                    padding: const EdgeInsets.all(DesignTokens.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms Summary (Plain English)',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space16),
                        _buildSummaryItem(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Age Eligibility',
                          desc: 'You must be 18 years of age or older to register or use the Promo marketplace.',
                        ),
                        const SizedBox(height: DesignTokens.space12),
                        _buildSummaryItem(
                          icon: Icons.face_retouching_natural_rounded,
                          title: 'Content Ownership',
                          desc: 'Any portfolio or campaign content you upload must be your own or legally licensed to you.',
                        ),
                        const SizedBox(height: DesignTokens.space12),
                        _buildSummaryItem(
                          icon: Icons.handshake_outlined,
                          title: 'Agreement Responsibility',
                          desc: 'You are legally responsible for fulfilling all contract deliverables and budget details agreed to in a collaboration.',
                        ),
                        const SizedBox(height: DesignTokens.space12),
                        _buildSummaryItem(
                          icon: Icons.verified_user_outlined,
                          title: 'Account Safety',
                          desc: 'We preserve the right to suspend or ban accounts that engage in fraud, harassment, or violate our guidelines.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space24),

                  // Checkboxes
                  _buildAnimatedCheckbox(
                    value: _agreedToTerms,
                    onChanged: (val) => setState(() => _agreedToTerms = val),
                    labelWidget: RichText(
                      text: TextSpan(
                        text: 'I agree to the ',
                        style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                        children: [
                          WidgetSpan(
                            baseline: TextBaseline.alphabetic,
                            alignment: PlaceholderAlignment.baseline,
                            child: GestureDetector(
                              onTap: _onTermsTapped,
                              child: Text(
                                'Terms of Service',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.purple,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          WidgetSpan(
                            baseline: TextBaseline.alphabetic,
                            alignment: PlaceholderAlignment.baseline,
                            child: GestureDetector(
                              onTap: _onPrivacyTapped,
                              child: Text(
                                'Privacy Policy',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.purple,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space12),
                  _buildAnimatedCheckbox(
                    value: _isEighteenOrOlder,
                    onChanged: (val) => setState(() => _isEighteenOrOlder = val),
                    labelWidget: Text(
                      'I confirm I am 18 years of age or older',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space24),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: DesignTokens.space16,
          right: DesignTokens.space16,
          top: DesignTokens.space12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.border : const Color(0xFFF3F4F6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: AppButton(
          label: 'Continue',
          isLoading: _isLoading,
          isDisabled: !_agreedToTerms || !_isEighteenOrOlder,
          onTap: _handleAccept,
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: DesignTokens.iconMD,
          color: AppColors.purple,
        ),
        const SizedBox(width: DesignTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                desc,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCheckbox({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Widget labelWidget,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: DesignTokens.durationSM,
              curve: DesignTokens.curveDefault,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                border: Border.all(
                  color: value ? AppColors.purple : AppColors.border,
                  width: 2,
                ),
                color: value ? AppColors.purple : Colors.transparent,
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: DesignTokens.space12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: labelWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
