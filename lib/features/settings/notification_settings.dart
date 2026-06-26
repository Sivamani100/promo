import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _saving = false;

  Future<void> _updatePreference(String key, dynamic value, {bool isPreferencesColumn = false}) async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    setState(() => _saving = true);

    try {
      if (isPreferencesColumn) {
        final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
        currentPrefs[key] = value;
        await SupabaseService.client.from('profiles').update({
          'preferences': currentPrefs,
        }).eq('id', user.id);
      } else {
        final currentPrefs = Map<String, dynamic>.from(profile['notification_prefs'] ?? {});
        currentPrefs[key] = value;
        await SupabaseService.client.from('profiles').update({
          'notification_prefs': currentPrefs,
        }).eq('id', user.id);
      }

      await ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update preferences: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final role = ref.watch(authProvider).role;
    final prefs = profile?['notification_prefs'] as Map<String, dynamic>? ?? {};
    final userPrefs = profile?['preferences'] as Map<String, dynamic>? ?? {};

    final emailNotif = prefs['email_notifications'] ?? true;
    final chatNotif = prefs['chat_messages'] ?? true;
    final milestoneNotif = prefs['milestone_changes'] ?? true;
    final pitchNotif = prefs['pitch_updates'] ?? true;
    final inviteNotif = prefs['brand_invites'] ?? true;

    final dndEnabled = userPrefs['dnd_enabled'] ?? false;
    final dndStart = userPrefs['dnd_start'] ?? '22:00';
    final dndEnd = userPrefs['dnd_end'] ?? '08:00';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
          Text('Alert Channels', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            _buildSwitchTile(
              icon: Iconsax.direct_send,
              title: 'Email Notifications',
              subtitle: 'Receive summaries and updates on email',
              value: emailNotif,
              onChanged: (val) => _updatePreference('email_notifications', val),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Activity & Events', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            _buildSwitchTile(
              icon: Iconsax.message,
              title: 'Chat Messages',
              subtitle: 'Direct messages and group chats alerts',
              value: chatNotif,
              onChanged: (val) => _updatePreference('chat_messages', val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Iconsax.calendar_tick,
              title: 'Milestone Activities',
              subtitle: 'Collaboration milestones status changes',
              value: milestoneNotif,
              onChanged: (val) => _updatePreference('milestone_changes', val),
            ),
            _buildDivider(),
            if (role == 'brand') ...[
              _buildSwitchTile(
                icon: Iconsax.document_text,
                title: 'Pitch Updates',
                subtitle: 'When influencers apply or update pitches',
                value: pitchNotif,
                onChanged: (val) => _updatePreference('pitch_updates', val),
              ),
            ] else ...[
              _buildSwitchTile(
                icon: Iconsax.crown,
                title: 'Brand Invitations',
                subtitle: 'Direct invitation invites from brands',
                value: inviteNotif,
                onChanged: (val) => _updatePreference('brand_invites', val),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          Text('Quiet Hours (DND)', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          _buildCard([
            _buildSwitchTile(
              icon: Iconsax.moon,
              title: 'Do Not Disturb (DND)',
              subtitle: 'Queue notifications during quiet hours',
              value: dndEnabled,
              onChanged: (val) => _updatePreference('dnd_enabled', val, isPreferencesColumn: true),
            ),
            if (dndEnabled) ...[
              _buildDivider(),
              ListTile(
                leading: Icon(Iconsax.clock, color: AppColors.accent, size: 22),
                title: Text('Start Time', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(dndStart, style: AppTextStyles.captionSm),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: int.parse(dndStart.split(':')[0]),
                      minute: int.parse(dndStart.split(':')[1]),
                    ),
                  );
                  if (time != null) {
                    final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    _updatePreference('dnd_start', formatted, isPreferencesColumn: true);
                  }
                },
              ),
              _buildDivider(),
              ListTile(
                leading: Icon(Iconsax.clock, color: AppColors.accent, size: 22),
                title: Text('End Time', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(dndEnd, style: AppTextStyles.captionSm),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: int.parse(dndEnd.split(':')[0]),
                      minute: int.parse(dndEnd.split(':')[1]),
                    ),
                  );
                  if (time != null) {
                    final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    _updatePreference('dnd_end', formatted, isPreferencesColumn: true);
                  }
                },
              ),
            ],
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

