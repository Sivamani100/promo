import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/agreement_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/shared_widgets.dart';

class AgreementReviewScreen extends ConsumerStatefulWidget {
  final String agreementId;

  const AgreementReviewScreen({
    super.key,
    required this.agreementId,
  });

  @override
  ConsumerState<AgreementReviewScreen> createState() => _AgreementReviewScreenState();
}

class _AgreementReviewScreenState extends ConsumerState<AgreementReviewScreen> {
  Map<String, dynamic>? _agreement;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AgreementService().getAgreement(widget.agreementId);
      if (mounted) {
        setState(() {
          _agreement = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.show(context, 'Failed to load agreement: $e');
      }
    }
  }

  Future<void> _sign() async {
    final user = ref.read(authProvider).user;
    final role = ref.read(authProvider).role;
    if (user == null || role == null || _agreement == null) return;

    setState(() => _submitting = true);
    try {
      await AgreementService().acceptAgreement(widget.agreementId, user.id, role);
      AppSnackbar.show(context, 'Contract signed successfully!');
      _load();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to sign agreement: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _requestChanges() async {
    setState(() => _submitting = true);
    try {
      await AgreementService().proposeChanges(widget.agreementId);
      AppSnackbar.show(context, 'Change request submitted. Contract status updated to Negotiating.');
      _load();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update agreement: $e');
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
    
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agreement Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_agreement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agreement Review')),
        body: const AppEmptyState(icon: Iconsax.document_text, title: 'Contract details not found'),
      );
    }

    final agr = _agreement!;
    final user = ref.read(authProvider).user;
    final role = ref.read(authProvider).role;
    
    final brand = agr['brand'] as Map<String, dynamic>? ?? {};
    final influencer = agr['influencer'] as Map<String, dynamic>? ?? {};
    
    final brandName = brand['display_name'] ?? 'Brand';
    final influencerName = influencer['display_name'] ?? 'Influencer';

    final isBrand = role == 'brand';
    final isInfluencer = role == 'influencer';

    final brandSigned = agr['brand_accepted_at'] != null;
    final influencerSigned = agr['influencer_accepted_at'] != null;
    final status = agr['status'] as String? ?? 'draft';

    Color statusColor = AppColors.warning;
    String statusLabel = status.toUpperCase().replaceAll('_', ' ');
    if (status == 'both_accepted') {
      statusColor = AppColors.success;
      statusLabel = 'SIGNED & ACTIVE';
    } else if (status == 'completed') {
      statusColor = AppColors.success;
      statusLabel = 'COMPLETED';
    } else if (status == 'disputed') {
      statusColor = AppColors.error;
      statusLabel = 'IN DISPUTE';
    } else if (status == 'cancelled') {
      statusColor = AppColors.textMuted;
    }

    final deliverables = agr['deliverables'] as List? ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Text(
          'Collaboration Agreement',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (status == 'both_accepted' || status == 'completed')
            IconButton(
              icon: const Icon(Iconsax.card_receive),
              onPressed: () {
                context.push('/$role/payments/${agr['id']}');
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status == 'both_accepted' 
                        ? 'This contract is legally active and signed by both parties.'
                        : (status == 'sent_to_influencer' ? 'Awaiting influencer signature.' : 'Contract is in negotiation.'),
                    style: AppTextStyles.captionSm,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Core Contract Card
            Text('Contract Terms', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _buildTermRow(Iconsax.empty_wallet, 'Collaboration Budget', agr['total_budget'] ?? '—', isDark),
                  _buildTermRow(Iconsax.calendar, 'Timeline duration', '${agr['timeline_days'] ?? 30} Days', isDark),
                  _buildTermRow(Iconsax.edit, 'Revision rounds limit', '${agr['revision_rounds'] ?? 2} Rounds', isDark),
                  _buildTermRow(Iconsax.status, 'Payment Terms', (agr['payment_terms'] as String? ?? 'on_delivery').toUpperCase().replaceAll('_', ' '), isDark),
                  _buildTermRow(Iconsax.security, 'Usage Rights licensing', (agr['usage_rights'] as String? ?? 'perpetual').toUpperCase().replaceAll('_', ' '), isDark),
                  _buildTermRow(Iconsax.lock_1, 'Exclusivity Period', '${agr['exclusivity_days'] ?? 0} Days', isDark, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Deliverables Card
            Text('Deliverables', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deliverables.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.verify, color: AppColors.success, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          deliverables[i].toString(),
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Signatures Card
            Text('Signature Status', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSignatureStamp(
                    title: 'Brand Partner',
                    name: brandName,
                    signed: brandSigned,
                    timestamp: agr['brand_accepted_at'] as String?,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSignatureStamp(
                    title: 'Creator Partner',
                    name: influencerName,
                    signed: influencerSigned,
                    timestamp: agr['influencer_accepted_at'] as String?,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Actions for signing
            if (status == 'sent_to_influencer' && isInfluencer && !influencerSigned) ...[
              AppButton(
                label: 'Sign & Accept Terms',
                isLoading: _submitting,
                onTap: _sign,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _submitting ? null : _requestChanges,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Request Changes'),
              ),
            ] else if (status == 'negotiating' && isBrand && !brandSigned) ...[
              AppButton(
                label: 'Sign & Propose Agreement',
                isLoading: _submitting,
                onTap: _sign,
              ),
            ],

            // Dispute Action
            if (status == 'both_accepted') ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    context.push('/$role/disputes/new?agreementId=${widget.agreementId}');
                  },
                  icon: Icon(Iconsax.danger, size: 16, color: AppColors.error),
                  label: Text('File Contract Dispute', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTermRow(IconData icon, String label, String value, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSignatureStamp({
    required String title,
    required String name,
    required bool signed,
    required String? timestamp,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: signed ? AppColors.success : (isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
          width: signed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.overline.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          if (signed) ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                Text('Signed', style: AppTextStyles.captionSm.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(timestamp).toLocal()) : '',
              style: AppTextStyles.captionSm.copyWith(fontSize: 9, color: AppColors.textMuted),
            ),
          ] else
            Row(
              children: [
                Icon(Icons.radio_button_off_rounded, color: AppColors.textMuted, size: 14),
                const SizedBox(width: 4),
                Text('Unsigned', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
              ],
            ),
        ],
      ),
    );
  }
}
