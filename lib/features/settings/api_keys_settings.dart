import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';

class ApiKeysSettingsScreen extends ConsumerStatefulWidget {
  const ApiKeysSettingsScreen({super.key});

  @override
  ConsumerState<ApiKeysSettingsScreen> createState() => _ApiKeysSettingsScreenState();
}

class _ApiKeysSettingsScreenState extends ConsumerState<ApiKeysSettingsScreen> {
  final _keyNameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _keyNameCtrl.dispose();
    super.dispose();
  }

  String _generateKeyToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final parts = List.generate(32, (index) => chars[rand.nextInt(chars.length)]);
    return 'sk_live_${parts.join()}';
  }

  Future<void> _createApiKey(String name) async {
    if (name.trim().isEmpty) return;

    setState(() => _saving = true);

    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
    final List<dynamic> keysList = List<dynamic>.from(currentPrefs['api_keys'] ?? []);

    final newToken = _generateKeyToken();
    final newKeyObj = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name.trim(),
      'token': newToken,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    keysList.add(newKeyObj);
    currentPrefs['api_keys'] = keysList;

    try {
      await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
      if (mounted) {
        _showNewKeyDialog(name, newToken);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate key: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteKey(String keyId) async {
    setState(() => _saving = true);

    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null || profile == null) return;

    final currentPrefs = Map<String, dynamic>.from(profile['preferences'] ?? {});
    final List<dynamic> keysList = List<dynamic>.from(currentPrefs['api_keys'] ?? []);

    keysList.removeWhere((k) => k['id'] == keyId);
    currentPrefs['api_keys'] = keysList;

    try {
      await ref.read(authProvider.notifier).updatePreferences(currentPrefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key revoked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke key: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showNewKeyDialog(String name, String token) {
    showPremiumDialog(
      context: context,
      title: 'API Key Generated',
      icon: Iconsax.key,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please copy your API key now. For security reasons, you will not be able to view it again.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    token,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Iconsax.copy, size: 18, color: AppColors.accent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Key copied to clipboard!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentOnDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog() {
    _keyNameCtrl.clear();
    showPremiumDialog(
      context: context,
      title: 'Create API Key',
      icon: Iconsax.key_square,
      content: TextField(
        controller: _keyNameCtrl,
        decoration: InputDecoration(
          labelText: 'Key Name',
          hintText: 'e.g., Production API',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        autofocus: true,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final name = _keyNameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context);
                    _createApiKey(name);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentOnDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                child: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};
    final List<dynamic> apiKeys = prefs['api_keys'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('API Keys')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active API Keys', style: AppTextStyles.overline),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _showCreateDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Key'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentOnDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: apiKeys.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.key, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No API Keys generated yet.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: apiKeys.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final keyObj = apiKeys[idx] as Map<String, dynamic>;
                        final keyId = keyObj['id'] as String;
                        final keyName = keyObj['name'] as String? ?? 'API Key';
                        final rawToken = keyObj['token'] as String? ?? '';
                        final truncatedToken = rawToken.length > 15
                            ? '${rawToken.substring(0, 10)}...${rawToken.substring(rawToken.length - 4)}'
                            : rawToken;

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Iconsax.key, color: AppColors.accent, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(keyName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      truncatedToken,
                                      style: AppTextStyles.captionSm.copyWith(fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Iconsax.trash, color: Colors.red, size: 20),
                                onPressed: () async {
                                  final confirmed = await showPremiumConfirmDialog(
                                    context: context,
                                    title: 'Revoke API Key',
                                    message: 'Are you sure you want to revoke this API key? Any applications currently using this key will immediately fail.',
                                    confirmLabel: 'Revoke',
                                    isDestructive: true,
                                    icon: Iconsax.key,
                                  );
                                  if (confirmed == true) {
                                    _deleteKey(keyId);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
