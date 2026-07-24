import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_card.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _essentialGranted = true; // Essential is always true
  bool _locationGranted = true;
  bool _analyticsGranted = true;
  bool _marketingGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    final preferences = profile?['preferences'] as Map<String, dynamic>? ?? {};
    final consents = preferences['consents'] as Map<String, dynamic>?;
    if (consents != null) {
      _essentialGranted = consents['essential']?['granted'] ?? true;
      _locationGranted = consents['location']?['granted'] ?? true;
      _analyticsGranted = consents['analytics']?['granted'] ?? true;
      _marketingGranted = consents['marketing']?['granted'] ?? false;
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final currentProfile = ref.read(authProvider).profile ?? {};
      final currentPrefs = Map<String, dynamic>.from(currentProfile['preferences'] ?? {});

      final nowStr = DateTime.now().toIso8601String();
      
      currentPrefs['consents'] = {
        'essential': {'granted': _essentialGranted, 'timestamp': nowStr},
        'location': {'granted': _locationGranted, 'timestamp': nowStr},
        'analytics': {'granted': _analyticsGranted, 'timestamp': nowStr},
        'marketing': {'granted': _marketingGranted, 'timestamp': nowStr},
      };

      await authNotifier.updatePreferences(currentPrefs);
      
      if (mounted) {
        final fromSettings = GoRouterState.of(context).uri.queryParameters['from_settings'] == 'true';
        if (fromSettings) {
          context.pop();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
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

                  // Header icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.space16),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: DesignTokens.avatarMD,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space24),

                  // Heading
                  Text(
                    'Privacy & Data Choice',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displaySM.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    'In compliance with the India DPDP Act and global standards, choose how your data is handled.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space24),

                  // Data Fiduciary Notice
                  AppCard(
                    padding: const EdgeInsets.all(DesignTokens.space12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: DesignTokens.iconMD,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: DesignTokens.space12),
                        Expanded(
                          child: Text(
                            'Promo (operated by Brand Mobile App Pvt. Ltd.) acts as the Data Fiduciary for the personal data collected through this app. Your privacy choices are respected and protected.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space24),

                  // Consent toggles
                  _buildConsentTile(
                    title: 'Essential App Data',
                    description: 'Required to run the application (e.g. email, password, profile role). Cannot be disabled.',
                    value: _essentialGranted,
                    isMandatory: true,
                    onChanged: null,
                  ),
                  const Divider(height: 1),
                  _buildConsentTile(
                    title: 'Location Services',
                    description: 'Allows showing relevant localized brand campaigns and creators in your geographic region.',
                    value: _locationGranted,
                    isMandatory: false,
                    onChanged: (val) => setState(() => _locationGranted = val),
                  ),
                  const Divider(height: 1),
                  _buildConsentTile(
                    title: 'App Performance & Analytics',
                    description: 'Aggregated analytics to monitor bugs, load speeds, and improve application features.',
                    value: _analyticsGranted,
                    isMandatory: false,
                    onChanged: (val) => setState(() => _analyticsGranted = val),
                  ),
                  const Divider(height: 1),
                  _buildConsentTile(
                    title: 'Marketing & Notifications',
                    description: 'Receive newsletters, industry guides, and promotional offers from Promo.',
                    value: _marketingGranted,
                    isMandatory: false,
                    onChanged: (val) => setState(() => _marketingGranted = val),
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
          label: 'Confirm Choices',
          isLoading: _isLoading,
          onTap: _handleSave,
        ),
      ),
    );
  }

  Widget _buildConsentTile({
    required String title,
    required String description,
    required bool value,
    required bool isMandatory,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMandatory) ...[
                      const SizedBox(width: DesignTokens.space6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                        ),
                        child: Text(
                          'Required',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.purple,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),
                Text(
                  description,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.space16),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.purple,
            onChanged: isMandatory ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
