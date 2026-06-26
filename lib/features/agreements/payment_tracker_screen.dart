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
import '../../core/services/payment_tracking_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/shared_widgets.dart';

class PaymentTrackerScreen extends ConsumerStatefulWidget {
  final String agreementId;

  const PaymentTrackerScreen({
    super.key,
    required this.agreementId,
  });

  @override
  ConsumerState<PaymentTrackerScreen> createState() => _PaymentTrackerScreenState();
}

class _PaymentTrackerScreenState extends ConsumerState<PaymentTrackerScreen> {
  Map<String, dynamic>? _agreement;
  Map<String, dynamic>? _paymentRecord;
  bool _loading = true;
  bool _submitting = false;

  final _paymentMethodCtrl = TextEditingController(text: 'Bank Transfer');
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paymentMethodCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final agreement = await AgreementService().getAgreement(widget.agreementId);
      if (agreement == null) {
        throw Exception('Agreement details not found.');
      }

      final payments = await PaymentTrackingService().getPaymentsForAgreement(widget.agreementId);
      Map<String, dynamic>? activePayment;
      if (payments.isNotEmpty) {
        activePayment = payments.first;
      } else {
        // If no payment record exists yet, create one matching the total budget
        final user = ref.read(authProvider).user;
        if (user != null && user.id == agreement['brand_id']) {
          activePayment = await PaymentTrackingService().createPaymentRecord(
            agreementId: agreement['id'] as String,
            roomId: agreement['room_id'] as String,
            brandId: agreement['brand_id'] as String,
            influencerId: agreement['influencer_id'] as String,
            amount: agreement['total_budget'] as String,
          );
        }
      }

      if (mounted) {
        setState(() {
          _agreement = agreement;
          _paymentRecord = activePayment;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.show(context, 'Failed to load payments: $e');
      }
    }
  }

  Future<void> _markSent() async {
    if (_paymentRecord == null) return;
    
    final method = _paymentMethodCtrl.text.trim();
    if (method.isEmpty) {
      AppSnackbar.show(context, 'Please enter a payment method.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await PaymentTrackingService().markPaymentAsSent(
        _paymentRecord!['id'] as String,
        paymentMethod: method,
        note: _noteCtrl.text.trim(),
      );
      AppSnackbar.show(context, 'Payment marked as sent successfully!');
      _load();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update payment: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _confirmReceived() async {
    if (_paymentRecord == null) return;

    setState(() => _submitting = true);
    try {
      await PaymentTrackingService().confirmPaymentReceived(
        _paymentRecord!['id'] as String,
        note: _noteCtrl.text.trim(),
      );
      AppSnackbar.show(context, 'Payment confirmed as received!');
      _load();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to confirm payment: $e');
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
        appBar: AppBar(title: const Text('Payment Milestone Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_agreement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Milestone Tracker')),
        body: const AppEmptyState(icon: Iconsax.card_receive, title: 'Agreement details not found'),
      );
    }

    final agr = _agreement!;
    final role = ref.read(authProvider).role;
    final isBrand = role == 'brand';
    final isInfluencer = role == 'influencer';

    final pay = _paymentRecord;
    final amount = pay != null ? pay['amount'] : agr['total_budget'];
    final status = pay != null ? pay['status'] : 'pending';

    // Timeline states
    final step1Completed = agr['status'] != 'draft' && agr['status'] != 'negotiating';
    final step2Completed = status == 'brand_marked_sent' || status == 'completed';
    final step3Completed = status == 'completed';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Text(
          'Payment Tracker',
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
            // Amount Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Text(
                    'TOTAL BUDGET AMOUNT',
                    style: AppTextStyles.overline.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    amount,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (status == 'completed' ? AppColors.success : AppColors.warning).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase().replaceAll('_', ' '),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status == 'completed' ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Timeline header
            Text('Milestone Timeline', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Vertical Timeline Items
            _buildTimelineStep(
              icon: Iconsax.document_text,
              title: 'Contract Agreement Signed',
              description: 'Both parties reviewed and legally signed the collaboration contract.',
              completed: step1Completed,
              isFirst: true,
              isDark: isDark,
            ),
            _buildTimelineStep(
              icon: Iconsax.card_send,
              title: 'Brand Sends Payment',
              description: pay != null && pay['brand_marked_sent_at'] != null
                  ? 'Sent via ${pay['payment_method'] ?? 'Bank Transfer'} on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(pay['brand_marked_sent_at']).toLocal())}.'
                  : 'Brand registers the transaction after sending funds.',
              completed: step2Completed,
              isDark: isDark,
            ),
            _buildTimelineStep(
              icon: Iconsax.verify,
              title: 'Creator Confirms Receipt',
              description: pay != null && pay['influencer_confirmed_at'] != null
                  ? 'Confirmed on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(pay['influencer_confirmed_at']).toLocal())}.'
                  : 'Creator verifies the funds cleared in their account.',
              completed: step3Completed,
              isLast: true,
              isDark: isDark,
            ),
            const SizedBox(height: 32),

            // Actions
            if (pay != null) ...[
              if (status == 'pending' && isBrand) ...[
                Text('Log Sent Transaction', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _paymentMethodCtrl,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText: 'Payment Method / Reference',
                    fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'Add transfer reference or timing notes...',
                    fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Mark Payment as Sent',
                  isLoading: _submitting,
                  onTap: _markSent,
                ),
              ] else if (status == 'brand_marked_sent' && isInfluencer) ...[
                if (pay['brand_note'] != null && (pay['brand_note'] as String).isNotEmpty) ...[
                  Text('Brand Note:', style: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(pay['brand_note'], style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText: 'Receipt Note (Optional)',
                    hintText: 'Add any confirmation details...',
                    fillColor: isDark ? const Color(0xFF18181C) : Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Confirm Payment Received',
                  isLoading: _submitting,
                  onTap: _confirmReceived,
                ),
              ],
            ],

            // Dispute Action
            if (status == 'brand_marked_sent' || status == 'pending') ...[
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    context.push('/$role/disputes/new?agreementId=${widget.agreementId}&paymentId=${pay?['id']}');
                  },
                  icon: Icon(Iconsax.danger, size: 16, color: AppColors.error),
                  label: Text('File Payment Dispute', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String description,
    required bool completed,
    bool isFirst = false,
    bool isLast = false,
    required bool isDark,
  }) {
    final activeColor = completed ? AppColors.success : AppColors.textMuted;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line + Circle column
        Column(
          children: [
            Container(
              width: 2,
              height: isFirst ? 0 : 20,
              color: completed ? AppColors.success : (isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: completed ? AppColors.success.withValues(alpha: 0.1) : (isDark ? const Color(0xFF18181C) : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed ? AppColors.success : (isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 14, color: activeColor),
            ),
            Container(
              width: 2,
              height: isLast ? 0 : 40,
              color: completed ? AppColors.success : (isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB)),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Content Column
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: completed ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
