import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/app_providers.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/widgets/password_strength_meter.dart';

class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSetPassword() async {
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in both fields.');
      return;
    }
    if (password.length < 8) {
      _showSnack('Password must be at least 8 characters.');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _showSnack('Password must contain at least one uppercase letter.');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _showSnack('Password must contain at least one number.');
      return;
    }
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
      _showSnack('Password must contain at least one special character.');
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService().updatePassword(password);
      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
        });
      }
      ref.read(authProvider.notifier).clearRecoveryMode();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Failed to update password. Please try again.');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, msg);
  }

  void _goToLogin() {
    ref.read(authProvider.notifier).signOut();
    context.go('/login');
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _done ? _buildSuccessContent(isDark) : _buildFormContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessContent(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D2E1A) : const Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 52,
            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),

        Text(
          'Password Updated!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 10),

        Text(
          'Your password has been successfully changed. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.6,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ).animate().fade(duration: 300.ms, delay: 80.ms),

        const SizedBox(height: 40),

        GestureDetector(
          onTap: _goToLogin,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : const Color(0xFF111827),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Go to Sign In',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: 200.ms),
      ],
    );
  }

  Widget _buildFormContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon header
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE).withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Iconsax.lock,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF60A5FA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.edit,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 20),

        Text(
          "Create New Password",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 8),

        Text(
          'Use a different password from your previous one.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ).animate().fade(duration: 300.ms, delay: 50.ms),

        const SizedBox(height: 32),

        // Password field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Password',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: isDark ? AppColors.surface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                    size: 20,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Live password strength meter
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _passwordCtrl,
              builder: (_, value, __) => PasswordStrengthMeter(password: value.text),
            ),
          ],
        ).animate().fade(duration: 300.ms, delay: 150.ms),

        const SizedBox(height: 16),

        // Confirm Password field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm Password',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSetPassword(),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: isDark ? AppColors.surface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.border : const Color(0xFFE5E7EB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                    size: 20,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ),
          ],
        ).animate().fade(duration: 300.ms, delay: 200.ms),

        const SizedBox(height: 10),

        // Password hint text
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'At least 8 characters with an uppercase letter, number & special character',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: 220.ms),

        const SizedBox(height: 28),

        // Update Password button
        GestureDetector(
          onTap: _loading ? null : _handleSetPassword,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : const Color(0xFF111827),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      'Update Password',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: 250.ms),

        const SizedBox(height: 40),
      ],
    );
  }
}
