import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/dispute_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/shared_widgets.dart';

class RaiseDisputeScreen extends ConsumerStatefulWidget {
  final String agreementId;
  final String? paymentId;

  const RaiseDisputeScreen({
    super.key,
    required this.agreementId,
    this.paymentId,
  });

  @override
  ConsumerState<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends ConsumerState<RaiseDisputeScreen> {
  final _descriptionCtrl = TextEditingController();
  String _selectedCategory = 'payment_not_received';
  bool _submitting = false;

  final List<Map<String, String>> _categories = [
    {'value': 'payment_not_received', 'label': 'Payment Not Received'},
    {'value': 'content_not_delivered', 'label': 'Content Not Delivered'},
    {'value': 'content_quality', 'label': 'Content Quality Issue'},
    {'value': 'agreement_violation', 'label': 'Contract Terms Violation'},
    {'value': 'communication_breakdown', 'label': 'Communication Breakdown'},
    {'value': 'other', 'label': 'Other Issue'},
  ];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      AppSnackbar.show(context, 'Please explain the issue details.');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Determine the against user
      // We need to fetch the agreement to see who is the other participant
      final agreement = await _clientGetAgreement();
      if (agreement == null) {
        throw Exception('Agreement details not found.');
      }

      final brandId = agreement['brand_id'] as String;
      final influencerId = agreement['influencer_id'] as String;
      final againstId = (user.id == brandId) ? influencerId : brandId;

      await DisputeService().raiseDispute(
        agreementId: widget.agreementId,
        paymentId: widget.paymentId,
        raisedBy: user.id,
        against: againstId,
        category: _selectedCategory,
        description: description,
      );

      if (mounted) {
        AppSnackbar.show(context, 'Dispute raised successfully. Our support team will review this case.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to raise dispute: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _clientGetAgreement() async {
    // Queries database directly or uses service
    final response = await Supabase.instance.client
        .from('collaboration_agreements')
        .select('brand_id, influencer_id')
        .eq('id', widget.agreementId)
        .maybeSingle();
    return response;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Text(
          'File a Dispute',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Alert
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconsax.danger, color: AppColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dispute Mediation Protocol',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Filing a dispute halts all agreement statuses and flags this transaction for administrative review. Please present clear details.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category Selector
            Text('Dispute Category', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = cat['value'] == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.accent.withValues(alpha: 0.05) 
                          : (isDark ? const Color(0xFF18181C) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.accent : (isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppColors.accent : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          cat['label']!,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Details description
            Text('Issue Details', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 6,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Please detail exactly what occurred, including dates, deliverables, or missing communications...',
                hintStyle: AppTextStyles.caption,
                fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Submit Dispute Case',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
