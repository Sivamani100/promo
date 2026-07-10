import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _saving = false;

  Future<void> _toggleIsActive(bool value) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('profiles').update({
        'is_active': value,
      }).eq('id', user.id);

      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update visibility: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePreference(String key, bool value) async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
    currentPrefs[key] = value;

    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Failed to update preference: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportData() async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    setState(() => _saving = true);
    try {
      // 1. Record the request in the database for auditing
      await SupabaseService.client.from('data_export_requests').insert({
        'user_id': user.id,
        'status': 'completed',
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });

      // 2. Build the export payload
      final exportPayload = {
        'exported_at': DateTime.now().toIso8601String(),
        'user_info': {
          'id': user.id,
          'email': user.email,
          'created_at': user.createdAt,
        },
        'profile': profile,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportPayload);

      // 3. Share/download the exported data as JSON
      await Share.share(
        jsonString,
        subject: 'Promo_MyDataExport.json',
      );

      if (mounted) {
        AppSnackbar.show(context, 'Data exported successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to export data: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Your Account?'),
        content: const Text(
          'WARNING: This is permanent. All your cards, applications, messages, and profile information will be deleted immediately. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      // Call RPC delete_user_account
      await SupabaseService.client.rpc('delete_user_account', params: {
        'p_user_id': user.id,
      });

      // Log out
      await ref.read(authProvider.notifier).signOut();
      
      if (mounted) {
        AppSnackbar.show(context, 'Account deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to delete account: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final isActive = profile?['is_active'] ?? true;
    final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};

    final activeStatus = prefs['privacy_active_status'] ?? true;
    final readReceipts = prefs['privacy_read_receipts'] ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Discovery', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            _buildSwitchTile(
              icon: Iconsax.eye,
              title: 'Show in Discover Search',
              subtitle: 'Allow other users to find your profile in feeds and maps',
              value: isActive,
              onChanged: _toggleIsActive,
            ),
          ]),
          const SizedBox(height: 20),
          Text('Chat & Presence', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            _buildSwitchTile(
              icon: Iconsax.user_tag,
              title: 'Show Active Status',
              subtitle: 'Show when you are online in chat lists',
              value: activeStatus,
              onChanged: (val) => _togglePreference('privacy_active_status', val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Iconsax.message_tick,
              title: 'Read Receipts',
              subtitle: 'Allow others to see when you have read their messages',
              value: readReceipts,
              onChanged: (val) => _togglePreference('privacy_read_receipts', val),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Trust & Safety', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            ListTile(
              leading: Icon(Iconsax.user_remove, color: AppColors.error, size: 22),
              title: Text('Blocked Users', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text('Manage the list of users you have blocked', style: AppTextStyles.captionSm),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final role = ref.read(authProvider).role;
                context.push('/$role/settings/privacy/blocked-users');
              },
            ),
          ]),
          const SizedBox(height: 20),
          Text('Data & Privacy (GDPR)', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            ListTile(
              leading: Icon(Iconsax.document_download, color: AppColors.accent, size: 22),
              title: Text('Export My Data', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text('Download all your personal data as a JSON file', style: AppTextStyles.captionSm),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _exportData,
            ),
            _buildDivider(),
            ListTile(
              leading: Icon(Iconsax.trash, color: AppColors.error, size: 22),
              title: Text('Delete My Account', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text('Permanently delete your profile and account', style: AppTextStyles.captionSm),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _deleteAccount,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent, size: 22),
      title: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: AppTextStyles.captionSm),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppColors.accent,
        onChanged: _saving ? null : onChanged,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 56, color: AppColors.borderSubtle);
  }
}
