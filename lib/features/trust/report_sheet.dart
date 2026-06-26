// HARDENING-V2: trust-agent 2026-06-26
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/shared_widgets.dart';

class ReportSheet extends ConsumerStatefulWidget {
  final String? reportedId;
  final String? reportedCardId;
  final String? reportedMessageId;
  final String contentTypeName; // e.g. "User", "Campaign", "Message"

  const ReportSheet({
    super.key,
    this.reportedId,
    this.reportedCardId,
    this.reportedMessageId,
    required this.contentTypeName,
  }) : assert(
          reportedId != null || reportedCardId != null || reportedMessageId != null,
          'At least one entity must be specified to report',
        );

  static void show(
    BuildContext context, {
    String? reportedId,
    String? reportedCardId,
    String? reportedMessageId,
    required String contentTypeName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReportSheet(
        reportedId: reportedId,
        reportedCardId: reportedCardId,
        reportedMessageId: reportedMessageId,
        contentTypeName: contentTypeName,
      ),
    );
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final ReportService _reportService = ReportService();
  final TextEditingController _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasons = [
    {'value': 'spam', 'label': 'Spam or irrelevant content'},
    {'value': 'scam', 'label': 'Scam, fraud, or suspicious activity'},
    {'value': 'fake_profile', 'label': 'Fake profile or impersonation'},
    {'value': 'inappropriate_content', 'label': 'Inappropriate or adult content'},
    {'value': 'harassment', 'label': 'Harassment or bullying'},
    {'value': 'hate_speech', 'label': 'Hate speech or discrimination'},
    {'value': 'misleading_information', 'label': 'Misleading or false info'},
    {'value': 'underage_user', 'label': 'User appears to be under 18'},
    {'value': 'other', 'label': 'Other reason'},
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason for the report')),
      );
      return;
    }

    final authState = ref.read(authProvider);
    final reporterId = authState.user?.id;
    if (reporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to report content')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _reportService.submitReport(
        reporterId: reporterId,
        reportedId: widget.reportedId,
        reportedCardId: widget.reportedCardId,
        reportedMessageId: widget.reportedMessageId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Thank you. We have received your report and will review the ${widget.contentTypeName.toLowerCase()} shortly.',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to submit report: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.xl + bottomInset,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF242428) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E33) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Iconsax.danger, color: AppColors.error, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Report ${widget.contentTypeName}',
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Help us keep our community safe. Please select the primary reason why this ${widget.contentTypeName.toLowerCase()} violates our terms of service.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              
              // Reasons List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reasons.length,
                itemBuilder: (context, index) {
                  final reason = _reasons[index];
                  final isSelected = _selectedReason == reason['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedReason = reason['value'];
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.error : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              reason['label']!,
                              style: AppTextStyles.body.copyWith(
                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              Text(
                'ADDITIONAL DETAILS (OPTIONAL)',
                style: AppTextStyles.overline,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 500,
                style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Please provide any additional context or details...',
                  hintStyle: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Submit Report',
                onTap: _submitReport,
                isLoading: _isSubmitting,
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
