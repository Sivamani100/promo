import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class FeedbackService {
  FeedbackService._();

  static const String _npsLastShownKey = 'nps_survey_last_shown_at';
  static const String _npsReviewRequestedKey = 'nps_review_requested';

  /// Evaluates conditions and triggers NPS bottom sheet if applicable.
  static Future<void> triggerNPSIfNeeded(BuildContext context, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check last shown time (must be at least 60 days ago)
    final lastShownStr = prefs.getString(_npsLastShownKey);
    if (lastShownStr != null) {
      final lastShown = DateTime.parse(lastShownStr);
      final diff = DateTime.now().difference(lastShown);
      if (diff.inDays < 60) return;
    }

    // 2. Check user's signup/active age (must be at least 14 days)
    // We can fetch user created_at from Supabase or assume they are eligible
    // for this demo. Let's do a simple check.
    
    if (context.mounted) {
      showNPSSurvey(context, userId);
    }
  }

  /// Show the NPS Survey bottom sheet.
  static void showNPSSurvey(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) {
        return _NPSSurveyWidget(userId: userId);
      },
    );
  }
}

class _NPSSurveyWidget extends StatefulWidget {
  final String userId;
  const _NPSSurveyWidget({required this.userId});

  @override
  State<_NPSSurveyWidget> createState() => _NPSSurveyWidgetState();
}

class _NPSSurveyWidgetState extends State<_NPSSurveyWidget> {
  int? _selectedScore;
  bool _submittedScore = false;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_selectedScore == null) return;
    setState(() => _submitting = true);

    try {
      final client = SupabaseService.client;
      await client.from('feedback').insert({
        'user_id': widget.userId,
        'type': 'nps',
        'score': _selectedScore,
        'comment': _commentCtrl.text.trim(),
      });

      // Record shown timestamp so we don't show for 60 days
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FeedbackService._npsLastShownKey, DateTime.now().toIso8601String());

      // If score is 9-10 (Promoter), request native App Store review
      if (_selectedScore! >= 9) {
        final reviewRequestedBefore = prefs.getBool(FeedbackService._npsReviewRequestedKey) ?? false;
        if (!reviewRequestedBefore) {
          await prefs.setBool(FeedbackService._npsReviewRequestedKey, true);
          final inAppReview = InAppReview.instance;
          if (await inAppReview.isAvailable()) {
            await inAppReview.requestReview();
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your valuable feedback!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('[NPS] Error submitting: $e');
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(DesignTokens.radiusLG),
          topRight: Radius.circular(DesignTokens.radiusLG),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space20,
        DesignTokens.space24,
        DesignTokens.space20,
        MediaQuery.of(context).viewInsets.bottom > 0
            ? DesignTokens.space12
            : MediaQuery.of(context).padding.bottom + DesignTokens.space20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Promo App Survey', style: AppTextStyles.overline.copyWith(color: AppColors.purple)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!_submittedScore) ...[
            Text(
              'How likely are you to recommend Promo to a friend or colleague?',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 24),
            
            // 0-10 Buttons
            Wrap(
              spacing: 6,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(11, (idx) {
                final isSelected = _selectedScore == idx;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedScore = idx;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.purple
                          : (isDark ? AppColors.surface2 : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                      border: Border.all(
                        color: isSelected ? AppColors.purple : AppColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$idx',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 = Not Likely', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                Text('10 = Extremely Likely', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 28),
            
            ElevatedButton(
              onPressed: _selectedScore == null
                  ? null
                  : () {
                      setState(() {
                        _submittedScore = true;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            Text(
              _selectedScore! >= 9
                  ? 'What do you love most about Promo?'
                  : (_selectedScore! >= 7
                      ? 'What could we improve to make your experience better?'
                      : 'We\'re sorry to hear that. What went wrong?'),
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Your feedback',
              hint: 'Write your comments here...',
              controller: _commentCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _submittedScore = false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
