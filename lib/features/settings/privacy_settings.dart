import 'package:flutter/material.dart';
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
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update preference: $e');
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
