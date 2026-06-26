import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/agreement_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/shared_widgets.dart';

class AgreementBuilderScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String cardId;
  final String influencerId;

  const AgreementBuilderScreen({
    super.key,
    required this.roomId,
    required this.cardId,
    required this.influencerId,
  });

  @override
  ConsumerState<AgreementBuilderScreen> createState() => _AgreementBuilderScreenState();
}

class _AgreementBuilderScreenState extends ConsumerState<AgreementBuilderScreen> {
  final _budgetCtrl = TextEditingController();
  final _timelineCtrl = TextEditingController(text: '30');
  final _revisionsCtrl = TextEditingController(text: '2');
  final _exclusivityCtrl = TextEditingController(text: '0');
  final _deliverableInputCtrl = TextEditingController();
  
  String _paymentTerms = 'on_delivery';
  String _usageRights = 'perpetual';
  final List<String> _deliverables = [];

  final List<Map<String, String>> _paymentOptions = [
    {'value': 'upfront', 'label': 'Upfront Payment'},
    {'value': 'on_delivery', 'label': 'On Final Delivery'},
    {'value': 'milestone_based', 'label': 'Milestone-Based Payments'},
  ];

  final List<Map<String, String>> _usageOptions = [
    {'value': 'one_time', 'label': 'One-Time Use Only'},
    {'value': 'limited', 'label': 'Limited Rights (6 months)'},
    {'value': 'perpetual', 'label': 'Perpetual Rights'},
  ];

  bool _submitting = false;

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _timelineCtrl.dispose();
    _revisionsCtrl.dispose();
    _exclusivityCtrl.dispose();
    _deliverableInputCtrl.dispose();
    super.dispose();
  }

  void _addDeliverable() {
    final text = _deliverableInputCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _deliverables.add(text);
        _deliverableInputCtrl.clear();
      });
    }
  }

  void _removeDeliverable(int index) {
    setState(() {
      _deliverables.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final budget = _budgetCtrl.text.trim();
    if (budget.isEmpty) {
      AppSnackbar.show(context, 'Please specify the contract budget.');
      return;
    }

    if (_deliverables.isEmpty) {
      AppSnackbar.show(context, 'Please add at least one campaign deliverable.');
      return;
    }

    final timelineDays = int.tryParse(_timelineCtrl.text.trim()) ?? 30;
    final revisionRounds = int.tryParse(_revisionsCtrl.text.trim()) ?? 2;
    final exclusivityDays = int.tryParse(_exclusivityCtrl.text.trim()) ?? 0;

    setState(() => _submitting = true);
    try {
      await AgreementService().createAgreement(
        roomId: widget.roomId,
        cardId: widget.cardId,
        brandId: user.id,
        influencerId: widget.influencerId,
        deliverables: _deliverables,
        totalBudget: budget,
        paymentTerms: _paymentTerms,
        timelineDays: timelineDays,
        revisionRounds: revisionRounds,
        usageRights: _usageRights,
        exclusivityDays: exclusivityDays,
      );

      if (mounted) {
        AppSnackbar.show(context, 'Collaboration agreement sent successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to create agreement: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Text(
          'Create Agreement Contract',
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
            // Title description banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.document_text, color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Outline the exact deliverables and terms. Both parties must sign before payment milestones can be active.',
                      style: AppTextStyles.caption.copyWith(height: 1.4, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Budget Input
            Text('Collaboration Budget (INR / USD)', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.text,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                prefixIcon: const Icon(Iconsax.empty_wallet, size: 18),
                hintText: r'e.g. ₹15,000 / $500',
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
            const SizedBox(height: 20),

            // Timeline & Revisions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Timeline (Days)', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _timelineCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'e.g. 30',
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
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Revision Rounds', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _revisionsCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'e.g. 2',
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Exclusivity days
            Text('Exclusivity Period (Days)', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _exclusivityCtrl,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                prefixIcon: const Icon(Iconsax.lock_1, size: 18),
                hintText: 'e.g. 15 (0 for none)',
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
            const SizedBox(height: 20),

            // Payment Terms Options
            Text('Payment Terms', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentTerms,
              items: _paymentOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt['value'],
                  child: Text(opt['label']!, style: AppTextStyles.body),
                );
              }).toList(),
              onChanged: (val) => setState(() => _paymentTerms = val!),
              decoration: InputDecoration(
                fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Usage Rights Options
            Text('Usage Rights', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _usageRights,
              items: _usageOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt['value'],
                  child: Text(opt['label']!, style: AppTextStyles.body),
                );
              }).toList(),
              onChanged: (val) => setState(() => _usageRights = val!),
              decoration: InputDecoration(
                fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Deliverables list builder
            Text('Deliverables List', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deliverableInputCtrl,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'e.g. 1 Instagram Reel (with audio)',
                      hintStyle: AppTextStyles.caption,
                      fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addDeliverable,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_deliverables.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No deliverables added yet.', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _deliverables.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181C) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.verify, color: AppColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_deliverables[i], style: AppTextStyles.body.copyWith(fontSize: 13)),
                        ),
                        GestureDetector(
                          onTap: () => _removeDeliverable(i),
                          child: Icon(Icons.close_rounded, color: AppColors.error, size: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),

            // Submit Button
            AppButton(
              label: 'Send Agreement proposed',
              isLoading: _submitting,
              onTap: _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
