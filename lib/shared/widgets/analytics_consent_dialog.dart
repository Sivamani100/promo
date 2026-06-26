import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import 'shared_widgets.dart';

class AnalyticsConsentDialog extends StatefulWidget {
  const AnalyticsConsentDialog({super.key});

  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('analytics_consent')) {
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AnalyticsConsentDialog(),
        );
      }
    }
  }

  @override
  State<AnalyticsConsentDialog> createState() => _AnalyticsConsentDialogState();
}

class _AnalyticsConsentDialogState extends State<AnalyticsConsentDialog> {
  bool _isSaving = false;

  Future<void> _saveConsent(String choice) async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('analytics_consent', choice);
    
    // If 'essential', Sentry and Firebase SDKs could be toggled off at run time 
    // depending on their API support (checked in analytics logging wrapper).
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        side: BorderSide(color: AppColors.border, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space24),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cookie_outlined,
                  size: DesignTokens.iconLG,
                  color: AppColors.purple,
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Text(
                    'Analytics & Tracking',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space16),
            Text(
              'Promo uses diagnostic tools and performance tracking to keep the app fast and stable. Choose your tracking level:',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: DesignTokens.space24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _saveConsent('essential'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
                      side: BorderSide(color: AppColors.purple, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                      ),
                    ),
                    child: Text(
                      'Essential Only',
                      style: AppTextStyles.buttonSm.copyWith(
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveConsent('all'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
                      backgroundColor: AppColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                      ),
                    ),
                    child: Text(
                      'Accept All',
                      style: AppTextStyles.buttonSm.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
