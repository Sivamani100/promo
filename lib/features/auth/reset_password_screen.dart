import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  late AnimationController _checkAnimCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(
      parent: _checkAnimCtrl,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _handleReset() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _showSnack('Please enter your email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().resetPassword(_emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _sent = true;
          _loading = false;
        });
        _checkAnimCtrl.forward();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('An error occurred. Please try again.');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, msg);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _checkAnimCtrl.dispose();
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
            child: _sent ? _buildSuccessContent(isDark) : _buildFormContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessContent(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Email sent icon
        ScaleTransition(
          scale: _checkScale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0D2E1A)
                  : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_rounded,
              size: 48,
              color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
            ),
          ),
        ),

        const SizedBox(height: 28),

        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 10),

        Text(
          'We sent a password reset link to',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ).animate().fade(duration: 300.ms, delay: 50.ms),

        const SizedBox(height: 4),

        Text(
          _emailCtrl.text.trim(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate().fade(duration: 300.ms, delay: 80.ms),

        const SizedBox(height: 40),

        // Back to sign in button
        GestureDetector(
          onTap: () => context.go('/login'),
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
                'Back to Sign In',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: 200.ms),

        const SizedBox(height: 20),

        GestureDetector(
          onTap: () {
            setState(() => _sent = false);
            _checkAnimCtrl.reset();
          },
          child: Text(
            "Didn't receive it? Try again",
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              decoration: TextDecoration.underline,
              decorationColor: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: 250.ms),
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
                    Iconsax.key,
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
          'Forgot password?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 8),

        Text(
          "Enter your email and we'll send you a link to reset your password.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ).animate().fade(duration: 300.ms, delay: 50.ms),

        const SizedBox(height: 32),

        // Email field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Address',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleReset(),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: 'name@company.com',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
                prefixIcon: Icon(
                  Iconsax.sms,
                  size: 20,
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
              ),
            ),
          ],
        ).animate().fade(duration: 300.ms, delay: 150.ms),

        const SizedBox(height: 28),

        // Send Reset Link button
        GestureDetector(
          onTap: _loading ? null : _handleReset,
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
                      'Send Reset Link',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
            ),
          ),
        ).animate().fade(duration: 300.ms, delay: 250.ms),

        const SizedBox(height: 24),

        // Back to sign in link
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Remember your password? ',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(
                'Sign in',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ).animate().fade(duration: 300.ms, delay: 300.ms),

        const SizedBox(height: 40),
      ],
    );
  }
}
