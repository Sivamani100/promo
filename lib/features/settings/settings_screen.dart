import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role ?? 'brand';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SettingsSection(title: 'Account', items: [
            _SettingsItem(
              icon: Iconsax.notification,
              label: 'Notification Preferences',
              onTap: () => context.push('/$role/settings/notifications'),
            ),
            _SettingsItem(
              icon: Iconsax.lock,
              label: 'Privacy Settings',
              onTap: () => context.push('/$role/settings/privacy'),
            ),
            _SettingsItem(
              icon: Iconsax.shield,
              label: 'Security',
              subtitle: 'Password & sessions',
              onTap: () => context.push('/$role/settings/security'),
            ),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Profile', items: [
            _SettingsItem(
              icon: Iconsax.verify,
              label: 'Verification',
              subtitle: 'Request account verification',
              onTap: () => context.push('/$role/settings/verification'),
            ),
            if (role == 'influencer')
              _SettingsItem(
                icon: Iconsax.mobile,
                label: 'Platform Settings',
                subtitle: 'Manage connected platforms',
                onTap: () => context.push('/$role/settings/platforms'),
              ),
            _SettingsItem(
              icon: Iconsax.key,
              label: 'API Keys',
              onTap: () => context.push('/$role/settings/apikeys'),
            ),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Preferences', items: [
            _SettingsItem(
              icon: ref.watch(themeModeProvider) == ThemeMode.system
                  ? Iconsax.mobile
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Iconsax.moon
                      : Iconsax.sun_1,
              label: 'Theme Mode',
              subtitle: ref.watch(themeModeProvider) == ThemeMode.system
                  ? 'System Default'
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? 'Dark Mode'
                      : 'Light Mode',
              onTap: () => _showThemeSelectionSheet(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Support', items: [
            _SettingsItem(
              icon: Iconsax.info_circle,
              label: 'Help & Support',
              onTap: () => context.push('/$role/support'),
            ),
            _SettingsItem(
              icon: Iconsax.user_octagon,
              label: 'Developers',
              subtitle: 'Meet the creator of Promo',
              onTap: () => context.push('/$role/settings/developers'),
            ),
            _SettingsItem(
              icon: Iconsax.document,
              label: 'Terms of Service',
              onTap: () => context.push('/$role/settings/tos'),
            ),
            _SettingsItem(
              icon: Iconsax.shield_tick,
              label: 'Privacy Policy',
              onTap: () => context.push('/$role/settings/privacy-policy'),
            ),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Danger Zone', items: [
            _SettingsItem(
              icon: Iconsax.logout,
              label: 'Sign Out',
              isDestructive: true,
              onTap: () async {
                final confirmed = await showPremiumConfirmDialog(
                  context: context,
                  title: 'Sign Out',
                  message: 'Are you sure you want to sign out of your account?',
                  confirmLabel: 'Sign Out',
                  isDestructive: true,
                  icon: Iconsax.logout,
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).signOut();
                }
              },
            ),
          ]),
          const SizedBox(height: 32),
          Center(child: Text('Brand v1.0.0', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted))),
        ],
      ),
    );
  }

  void _showThemeSelectionSheet(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(themeModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Theme Mode',
                    style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: ThemeMode.system,
                  label: 'System Default',
                  subtitle: 'Match phone settings',
                  icon: Iconsax.mobile,
                  isSelected: currentMode == ThemeMode.system,
                ),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: ThemeMode.light,
                  label: 'Light Mode',
                  subtitle: 'Bright and clear',
                  icon: Iconsax.sun_1,
                  isSelected: currentMode == ThemeMode.light,
                ),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: ThemeMode.dark,
                  label: 'Dark Mode',
                  subtitle: 'Sleek dark layout',
                  icon: Iconsax.moon,
                  isSelected: currentMode == ThemeMode.dark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode mode,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.purple.withValues(alpha: 0.1)
              : AppColors.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.purple : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppColors.purple : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.purple, size: 22)
          : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, indent: 56, color: AppColors.borderSubtle),
                    ListTile(
                      leading: Icon(item.icon, size: 22, color: item.isDestructive ? AppColors.error : AppColors.textSecondary),
                      title: Text(item.label, style: AppTextStyles.body.copyWith(color: item.isDestructive ? AppColors.error : AppColors.textPrimary)),
                      subtitle: item.subtitle != null ? Text(item.subtitle!, style: AppTextStyles.captionSm) : null,
                      trailing: item.trailing ?? Icon(Iconsax.arrow_right_3, size: 20, color: AppColors.textMuted),
                      onTap: item.onTap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Widget? trailing;

  _SettingsItem({required this.icon, required this.label, this.subtitle, this.onTap, this.isDestructive = false, this.trailing});
}