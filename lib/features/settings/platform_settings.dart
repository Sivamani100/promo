import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_agent.dart';
import '../../core/services/profile_service.dart';

class PlatformSettingsScreen extends ConsumerStatefulWidget {
  const PlatformSettingsScreen({super.key});

  @override
  ConsumerState<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState extends ConsumerState<PlatformSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentHandles();
  }

  void _loadCurrentHandles() {
    final profile = ref.read(authProvider).profile;
    final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};
    final handles = prefs['platform_handles'] as Map<String, dynamic>? ?? {};

    _instagramCtrl.text = handles['Instagram'] ?? handles['instagram'] ?? '';
    _tiktokCtrl.text = handles['TikTok'] ?? handles['tiktok'] ?? '';
    _youtubeCtrl.text = handles['YouTube'] ?? handles['youtube'] ?? '';
    _twitterCtrl.text = handles['Twitter'] ?? handles['twitter'] ?? '';
  }

  @override
  void dispose() {
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _youtubeCtrl.dispose();
    _twitterCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveHandles() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) {
      setState(() => _saving = false);
      return;
    }

    final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
    final instagramHandle = _instagramCtrl.text.trim();
    final tiktokHandle = _tiktokCtrl.text.trim();
    final youtubeHandle = _youtubeCtrl.text.trim();
    final twitterHandle = _twitterCtrl.text.trim();

    final handles = {
      'Instagram': instagramHandle,
      'TikTok': tiktokHandle,
      'YouTube': youtubeHandle,
      'Twitter': twitterHandle,
    };
    currentPrefs['platform_handles'] = handles;

    try {
      // Background verification agent resolves followers and profile details
      List<SocialProfileDetails> verifiedProfiles = [];
      if (instagramHandle.isNotEmpty) {
        verifiedProfiles.add(await SocialAgent.fetchProfileDetails('Instagram', instagramHandle));
      }
      if (tiktokHandle.isNotEmpty) {
        verifiedProfiles.add(await SocialAgent.fetchProfileDetails('TikTok', tiktokHandle));
      }
      if (youtubeHandle.isNotEmpty) {
        verifiedProfiles.add(await SocialAgent.fetchProfileDetails('YouTube', youtubeHandle));
      }
      if (twitterHandle.isNotEmpty) {
        verifiedProfiles.add(await SocialAgent.fetchProfileDetails('Twitter', twitterHandle));
      }

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Verify Social Connections'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please verify that the profiles found belong to you:'),
                const SizedBox(height: 16),
                if (verifiedProfiles.isEmpty)
                  const Text('No platform handles entered.', style: TextStyle(fontStyle: FontStyle.italic))
                else
                  ...verifiedProfiles.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: p.avatarUrl.isNotEmpty
                              ? Image.network(p.avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person))
                              : const Icon(Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.displayName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                              Text('@${p.handle}', style: AppTextStyles.captionSm.copyWith(color: AppColors.accent)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${p.followerCount}', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                            Text('Followers', style: AppTextStyles.captionSm),
                          ],
                        ),
                      ],
                    ),
                  )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Edit Handles', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Confirm & Save'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        int totalFollowers = verifiedProfiles.fold(0, (sum, p) => sum + p.followerCount);
        
        await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
        await ProfileService().updateProfile(user.id, {
          'follower_count': totalFollowers,
          'platforms': handles.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList(),
        });
        await ref.read(authProvider.notifier).refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected platforms verified! Followers count updated: $totalFollowers')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify or save platform handles: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platforms')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Connected Accounts', style: AppTextStyles.overline),
            const SizedBox(height: 8),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _buildHandleField(
                      controller: _instagramCtrl,
                      label: 'Instagram Handle',
                      icon: Iconsax.instagram,
                      prefix: '@',
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(
                      controller: _tiktokCtrl,
                      label: 'TikTok Handle',
                      icon: Iconsax.video_circle,
                      prefix: '@',
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(
                      controller: _youtubeCtrl,
                      label: 'YouTube Channel / Handle',
                      icon: Iconsax.play,
                      prefix: 'c/',
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(
                      controller: _twitterCtrl,
                      label: 'Twitter / X Handle',
                      icon: Iconsax.global,
                      prefix: '@',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveHandles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentOnDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Connections'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandleField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String prefix,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
      ),
    );
  }
}
