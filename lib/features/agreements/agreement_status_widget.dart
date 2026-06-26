import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/agreement_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class AgreementStatusWidget extends ConsumerStatefulWidget {
  final String roomId;
  final String cardId;
  final String otherUserId;

  const AgreementStatusWidget({
    super.key,
    required this.roomId,
    required this.cardId,
    required this.otherUserId,
  });

  @override
  ConsumerState<AgreementStatusWidget> createState() => _AgreementStatusWidgetState();
}

class _AgreementStatusWidgetState extends ConsumerState<AgreementStatusWidget> {
  Map<String, dynamic>? _agreement;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Reload when room changes or manually
  Future<void> _load() async {
    try {
      final active = await AgreementService().getActiveAgreementForRoom(widget.roomId);
      if (mounted) {
        setState(() {
          _agreement = active;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final role = ref.read(authProvider).role;
    final isBrand = role == 'brand';
    
    final agr = _agreement;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (agr == null) {
      // No agreement created yet
      if (!isBrand) {
        return const SizedBox.shrink(); // Influencer only sees when proposed
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          border: Border(
            bottom: BorderSide(color: AppColors.accent.withValues(alpha: 0.15), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Iconsax.document_text, size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ready to collaborate? Outline contract terms now.',
                style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            GestureDetector(
              onTap: () async {
                await context.push(
                  '/$role/agreements/new?roomId=${widget.roomId}&cardId=${widget.cardId}&influencerId=${widget.otherUserId}',
                );
                _load(); // Reload after return
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Propose Contract',
                  style: AppTextStyles.overline.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final status = agr['status'] as String? ?? 'draft';
    
    Color statusColor = AppColors.warning;
    String statusText = 'Contract Pending Signature';
    IconData icon = Iconsax.document_text;

    if (status == 'both_accepted') {
      statusColor = AppColors.success;
      statusText = 'Contract Signed & Active';
      icon = Iconsax.verify;
    } else if (status == 'completed') {
      statusColor = AppColors.success;
      statusText = 'Collaboration Completed';
      icon = Iconsax.award;
    } else if (status == 'disputed') {
      statusColor = AppColors.error;
      statusText = 'Contract in Dispute';
      icon = Iconsax.danger;
    } else if (status == 'negotiating') {
      statusColor = AppColors.warning;
      statusText = 'Contract Under Negotiation';
      icon = Iconsax.message_edit;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: statusColor.withValues(alpha: 0.15), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await context.push('/$role/agreements/${agr['id']}');
              _load(); // Reload after returning
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C22) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C32) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                status == 'both_accepted' ? 'Track Payments' : 'View Details',
                style: AppTextStyles.overline.copyWith(
                  color: status == 'both_accepted' ? AppColors.success : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
