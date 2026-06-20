import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
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
  final _instagramFollowersCtrl = TextEditingController();
  final _tiktokFollowersCtrl = TextEditingController();
  final _youtubeFollowersCtrl = TextEditingController();
  final _twitterFollowersCtrl = TextEditingController();
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
    final followers = prefs['platform_followers'] as Map<String, dynamic>? ?? {};

    _instagramCtrl.text = handles['Instagram'] ?? handles['instagram'] ?? '';
    _tiktokCtrl.text = handles['TikTok'] ?? handles['tiktok'] ?? '';
    _youtubeCtrl.text = handles['YouTube'] ?? handles['youtube'] ?? '';
    _twitterCtrl.text = handles['Twitter'] ?? handles['twitter'] ?? '';

    _instagramFollowersCtrl.text = (followers['Instagram'] ?? followers['instagram'] ?? '').toString();
    _tiktokFollowersCtrl.text = (followers['TikTok'] ?? followers['tiktok'] ?? '').toString();
    _youtubeFollowersCtrl.text = (followers['YouTube'] ?? followers['youtube'] ?? '').toString();
    _twitterFollowersCtrl.text = (followers['Twitter'] ?? followers['twitter'] ?? '').toString();
  }

  @override
  void dispose() {
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _youtubeCtrl.dispose();
    _twitterCtrl.dispose();
    _instagramFollowersCtrl.dispose();
    _tiktokFollowersCtrl.dispose();
    _youtubeFollowersCtrl.dispose();
    _twitterFollowersCtrl.dispose();
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

    final int instagramFollowers = int.tryParse(_instagramFollowersCtrl.text.trim()) ?? 0;
    final int tiktokFollowers = int.tryParse(_tiktokFollowersCtrl.text.trim()) ?? 0;
    final int youtubeFollowers = int.tryParse(_youtubeFollowersCtrl.text.trim()) ?? 0;
    final int twitterFollowers = int.tryParse(_twitterFollowersCtrl.text.trim()) ?? 0;

    final followers = {
      'Instagram': instagramFollowers,
      'TikTok': tiktokFollowers,
      'YouTube': youtubeFollowers,
      'Twitter': twitterFollowers,
    };

    currentPrefs['platform_handles'] = handles;
    currentPrefs['platform_followers'] = followers;

    try {
      int totalFollowers = instagramFollowers + tiktokFollowers + youtubeFollowers + twitterFollowers;
      
      await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
      await ProfileService().updateProfile(user.id, {
        'follower_count': totalFollowers,
        'platforms': handles.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList(),
      });
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected platforms and followers count updated! Total followers: $totalFollowers')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save platform connections: $e')),
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
                    const SizedBox(height: 12),
                    _buildFollowersField(
                      controller: _instagramFollowersCtrl,
                      label: 'Instagram Followers',
                      icon: Iconsax.people,
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(
                      controller: _tiktokCtrl,
                      label: 'TikTok Handle',
                      icon: Iconsax.video_circle,
                      prefix: '@',
                    ),
                    const SizedBox(height: 12),
                    _buildFollowersField(
                      controller: _tiktokFollowersCtrl,
                      label: 'TikTok Followers',
                      icon: Iconsax.people,
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(
                      controller: _youtubeCtrl,
                      label: 'YouTube Channel / Handle',
                      icon: Iconsax.play,
                      prefix: 'c/',
                    ),
                    const SizedBox(height: 12),
                    _buildFollowersField(
                      controller: _youtubeFollowersCtrl,
                      label: 'YouTube Followers',
                      icon: Iconsax.people,
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(
                      controller: _twitterCtrl,
                      label: 'Twitter / X Handle',
                      icon: Iconsax.global,
                      prefix: '@',
                    ),
                    const SizedBox(height: 12),
                    _buildFollowersField(
                      controller: _twitterFollowersCtrl,
                      label: 'Twitter / X Followers',
                      icon: Iconsax.people,
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

  Widget _buildFollowersField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
      ),
    );
  }
}
