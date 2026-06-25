import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../core/services/supabase_service.dart';

class VerificationSettingsScreen extends ConsumerStatefulWidget {
  const VerificationSettingsScreen({super.key});

  @override
  ConsumerState<VerificationSettingsScreen> createState() => _VerificationSettingsScreenState();
}

class _VerificationSettingsScreenState extends ConsumerState<VerificationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _docType = 'Passport';
  bool _submitting = false;
  String? _uploadedDocName;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(authProvider.notifier).refreshProfile();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedDocName == null) {
      AppSnackbar.show(context, 'Please upload a verification document.');
      return;
    }

    setState(() => _submitting = true);

    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
    currentPrefs['verification_request'] = {
      'status': 'pending',
      'full_name': _nameCtrl.text.trim(),
      'doc_type': _docType,
      'doc_name': _uploadedDocName,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await SupabaseService.client.from('verification_requests').insert({
        'user_id': user.id,
        'role': profile['role'],
        'submitted_links': [_uploadedDocName],
        'notes': 'Official Name: ${_nameCtrl.text.trim()}, Doc Type: $_docType',
        'status': 'pending',
      });
      await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
      if (mounted) {
        AppSnackbar.show(context, 'Verification request submitted successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to submit request: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _simulateUpload() {
    setState(() {
      _uploadedDocName = 'verify_document_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final isVerified = profile?['is_verified'] ?? false;
    final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};
    final request = prefs['verification_request'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Current Verification Status Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: isVerified
                  ? LinearGradient(colors: [AppColors.success.withOpacity(0.2), AppColors.success.withOpacity(0.05)])
                  : LinearGradient(colors: [AppColors.accent.withOpacity(0.15), AppColors.accent.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: isVerified ? AppColors.success.withOpacity(0.3) : AppColors.border),
            ),
            child: Row(
              children: [
                if (isVerified)
                  const VerificationBadge(size: 48)
                else
                  Icon(
                    Iconsax.verify,
                    color: AppColors.accent,
                    size: 48,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'Account Verified' : 'Get Verified Badge',
                        style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified
                            ? 'Your account has been verified. You have access to all premium badges.'
                            : 'Submit documents to verify your identity and build brand trust.',
                        style: AppTextStyles.captionSm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (isVerified)
            const SizedBox.shrink()
          else if (request != null && request['status'] == 'pending')
            // Pending Verification Request Card
            _buildPendingCard(request)
          else
            // Verification Form
            _buildForm(),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> req) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.info_circle, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Request Pending Review',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your verification request was submitted and is currently being reviewed by our administration team. This process normally takes up to 48 hours.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const Divider(height: 24),
          _buildInfoRow('Full Name', req['full_name'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Document Type', req['doc_type'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Submitted At', _formatDate(req['submitted_at'])),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit Verification Request', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Official Full Name',
                      hintText: 'Enter your name as it appears on your ID',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your official name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _docType,
                    decoration: const InputDecoration(labelText: 'Document Type'),
                    items: const [
                      DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'National Identity Card', child: Text('National Identity Card')),
                      DropdownMenuItem(value: 'Drivers License', child: Text('Driver\'s License')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _docType = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('Upload Verification Document', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _simulateUpload,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.surface2,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Iconsax.document_upload, size: 32, color: AppColors.accent),
                            const SizedBox(height: 8),
                            Text(
                              _uploadedDocName ?? 'Select document image or scan PDF',
                              style: AppTextStyles.captionSm.copyWith(
                                color: _uploadedDocName != null ? AppColors.success : AppColors.textMuted,
                                fontWeight: _uploadedDocName != null ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentOnDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Request'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500)),
        Text(value, style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}
