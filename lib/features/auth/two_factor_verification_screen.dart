import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'widgets/auth_background.dart';
import 'widgets/glass_container.dart';

class TwoFactorVerificationScreen extends ConsumerStatefulWidget {
  const TwoFactorVerificationScreen({super.key});

  @override
  ConsumerState<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends ConsumerState<TwoFactorVerificationScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _verifyCode() {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final success =
        ref.read(authProvider.notifier).verifyTwoFactorCode(code);

    setState(() => _loading = false);

    if (success) {
      AppSnackbar.show(context, 'Verification successful!');
      // Router automatically redirects to home via state change
    } else {
      setState(() =>
          _errorMessage = 'Invalid verification code. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Hero(
                tag: 'auth_box',
                child: GlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.shield_security,
                            size: 48,
                            color: AppColors.purple,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Two-Factor Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit code from your authenticator app to continue.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            hintStyle: GoogleFonts.robotoMono(
                                color: AppColors.textMuted),
                            errorText: _errorMessage,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onChanged: (val) {
                            if (val.length == 6) _verifyCode();
                          },
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Verify Code',
                          isLoading: _loading,
                          onTap: _verifyCode,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () async {
                            await ref
                                .read(authProvider.notifier)
                                .signOut();
                          },
                          icon: Icon(Iconsax.logout,
                              size: 16, color: AppColors.error),
                          label: Text(
                            'Cancel / Sign Out',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
