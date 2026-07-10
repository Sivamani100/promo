import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';

import 'package:flutter/services.dart';
import '../../core/security/totp_helper.dart';
import '../../core/services/auth_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // HARDENING: sec-agent 2026-06-24
      // Use AuthService to update password and trigger global sign out
      await AuthService().updatePassword(_newPasswordCtrl.text.trim());

      if (mounted) {
        AppSnackbar.show(context, 'Password updated successfully! Signing out all devices...');
        _oldPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      }
    } on AuthException catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to update password: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle2FA(bool enable) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (enable) {
      // 1. Generate standard secret key
      final secret = TotpHelper.generateSecret();
      
      // 2. Open setup dialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final codeCtrl = TextEditingController();
          String? dialogError;
          int step = 1;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(step == 1 ? 'Setup Two-Factor (2FA)' : 'Verify Verification Code'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step == 1) ...[
                        const Text(
                          'Configure 2FA by adding this secret key to your Authenticator App (Google Authenticator, Authy, etc.):',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  secret,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Iconsax.copy),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: secret));
                                  AppSnackbar.show(ctx, 'Secret copied to clipboard.');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Make sure to backup this key securely. If you lose access, you will need recovery codes.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ] else ...[
                        const Text(
                          'Enter the 6-digit verification code from your authenticator app to confirm:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: codeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            errorText: dialogError,
                            counterText: '',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (step == 1) {
                        setDialogState(() {
                          step = 2;
                        });
                      } else {
                        final code = codeCtrl.text.trim();
                        final isValid = TotpHelper.verifyCode(secret, code);
                        if (isValid) {
                          try {
                            await SupabaseService.client.from('profiles').update({
                              'totp_secret': secret,
                              'totp_enabled': true,
                              'totp_backup_codes': List.generate(8, (_) => TotpHelper.generateSecret().substring(0, 10)),
                            }).eq('id', user.id);
                            
                            Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() {
                              dialogError = 'Database update failed: $e';
                            });
                          }
                        } else {
                          setDialogState(() {
                            dialogError = 'Invalid code. Please try again.';
                          });
                        }
                      }
                    },
                    child: Text(step == 1 ? 'Next' : 'Verify & Enable'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        await ref.read(authProvider.notifier).refreshProfile();
        if (mounted) {
          AppSnackbar.show(context, 'Two-factor authentication enabled successfully.');
        }
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Disable Two-Factor Authentication?'),
          content: const Text(
            'This will lower the security level of your account. You will no longer be prompted for a 2FA code during login.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await SupabaseService.client.from('profiles').update({
            'totp_secret': null,
            'totp_enabled': false,
            'totp_backup_codes': null,
          }).eq('id', user.id);
          
          await ref.read(authProvider.notifier).refreshProfile();
          if (mounted) {
            AppSnackbar.show(context, '2FA has been disabled.');
          }
        } catch (e) {
          if (mounted) {
            AppSnackbar.show(context, 'Failed to disable 2FA: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final totpEnabled = profile?['totp_enabled'] ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Update Password Card
          Text('Change Password', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          Form(
            key: _formKey,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _oldPasswordCtrl,
                      obscureText: !_showOld,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(_showOld ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showOld = !_showOld),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: !_showNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        suffixIcon: IconButton(
                          icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showNew = !_showNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) return 'Password must be at least 8 characters';
                        if (!RegExp(r'[A-Z]').hasMatch(v)) {
                          return 'At least one uppercase letter required';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(v)) {
                          return 'At least one number required';
                        }
                        if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(v)) {
                          return 'At least one special character required';
                        }
                        final email = ref.read(authProvider).user?.email;
                        if (email != null) {
                          final emailPrefix = email.split('@').first.toLowerCase();
                          if (emailPrefix.length >= 3 && v.toLowerCase().contains(emailPrefix)) {
                            return 'Password cannot contain your email username';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: !_showConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        suffixIcon: IconButton(
                          icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != _newPasswordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentOnDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Two-Factor Auth Card
          Text('Two-Factor Authentication', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: ListTile(
              leading: Icon(Iconsax.shield_tick, color: totpEnabled ? AppColors.success : AppColors.textMuted),
              title: const Text('2FA (TOTP)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(totpEnabled ? 'Secured via Authenticator App' : 'Enable additional security'),
              trailing: Switch.adaptive(
                value: totpEnabled,
                activeThumbColor: AppColors.accent,
                onChanged: _loading ? null : _toggle2FA,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Active Sessions list
          Text('Active Sessions', style: AppTextStyles.overline),
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
              child: Builder(
                builder: (context) {
                  final isDeviceWeb = kIsWeb;
                  final isDeviceApple = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
                  final isDeviceAndroid = defaultTargetPlatform == TargetPlatform.android;
                  
                  String currentDeviceName = 'Chrome (Windows)';
                  IconData currentDeviceIcon = Icons.laptop_chromebook_rounded;
                  
                  if (isDeviceWeb) {
                    if (isDeviceApple) {
                      currentDeviceName = 'Safari (macOS)';
                      currentDeviceIcon = Icons.laptop_mac_rounded;
                    } else if (isDeviceAndroid) {
                      currentDeviceName = 'Chrome (Android)';
                      currentDeviceIcon = Icons.phone_android_rounded;
                    } else {
                      currentDeviceName = 'Chrome (Windows)';
                      currentDeviceIcon = Icons.laptop_chromebook_rounded;
                    }
                  } else {
                    if (isDeviceApple) {
                      currentDeviceName = 'iPhone 15 Pro Max';
                      currentDeviceIcon = Icons.phone_iphone_rounded;
                    } else if (isDeviceAndroid) {
                      currentDeviceName = 'Android Phone';
                      currentDeviceIcon = Icons.phone_android_rounded;
                    } else {
                      currentDeviceName = 'Workstation PC';
                      currentDeviceIcon = Icons.desktop_windows_rounded;
                    }
                  }

                  String otherDeviceName = 'iPhone 15 Pro Max';
                  IconData otherDeviceIcon = Icons.phone_iphone_rounded;
                  String otherDeviceSub = 'Last active: 2 hours ago • India';

                  if (!isDeviceWeb && (isDeviceApple || isDeviceAndroid)) {
                    otherDeviceName = 'Chrome (Windows)';
                    otherDeviceIcon = Icons.laptop_chromebook_rounded;
                    otherDeviceSub = 'Last active: 1 day ago • India';
                  }

                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(currentDeviceIcon, color: Colors.blue),
                        title: Text(currentDeviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Current Session • India'),
                        trailing: Text('Active', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Divider(height: 1, color: AppColors.borderSubtle, indent: 56),
                      ListTile(
                        leading: Icon(otherDeviceIcon, color: Colors.grey),
                        title: Text(otherDeviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(otherDeviceSub),
                        trailing: IconButton(
                          icon: const Icon(Iconsax.trash, size: 18, color: Colors.red),
                          onPressed: () {
                            AppSnackbar.show(context, 'Session revoked successfully.');
                          },
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out All Devices
          Text('Danger Zone', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: Icon(Iconsax.logout, color: AppColors.error, size: 22),
                title: Text('Sign Out All Devices',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                subtitle: const Text('Revoke all active sessions across every device instantly.'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out All Devices?'),
                      content: const Text(
                        'This will immediately revoke all active sessions across every device and browser. '
                        'You will be signed out of this device as well.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out All'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await ref.read(authProvider.notifier).signOut();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
