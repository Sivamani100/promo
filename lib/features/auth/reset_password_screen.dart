import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/auth_service.dart';

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

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppColors.textMuted
                  : const Color(0xFF333333).withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: isDark ? AppColors.border : const Color(0xFFE7EAEB),
                  width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: isDark ? AppColors.border : const Color(0xFFE7EAEB),
                  width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF000000),
                  width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 283,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(62),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading
          ? Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark
                      ? const Color(0xFF000000)
                      : const Color(0xFFFFFFFF),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(62),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF000000)
                      : const Color(0xFFFFFFFF),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFFFFFFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF000000),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF000000),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 44),

              if (_sent) ...[
                // Success State
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      ScaleTransition(
                        scale: _checkScale,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF1A2E1A)
                                : const Color(0xFFE8F5E9),
                          ),
                          child: Icon(
                            Icons.mark_email_read_rounded,
                            size: 40,
                            color: isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Check your email',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We sent a password reset link to',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 1.4,
                          color: isDark
                              ? AppColors.textSecondary
                              : const Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailCtrl.text.trim(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF000000),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _buildActionButton(
                        label: 'Back to Sign In',
                        onTap: () => context.go('/login'),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() => _sent = false);
                          _checkAnimCtrl.reset();
                        },
                        child: Text(
                          'Didn\'t receive it? Try again',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondary
                                : const Color(0xFF333333),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Reset Form
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forgot your\npassword?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 28,
                        height: 1.2,
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your email and we\'ll send you a link to reset your password.',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textSecondary
                            : const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                _buildInputField(
                  label: 'Your Email Address',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 48),

                Center(
                  child: _buildActionButton(
                    label: 'Send Reset Link',
                    onTap: _handleReset,
                    isLoading: _loading,
                  ),
                ),

                const SizedBox(height: 32),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Remember your password? ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? AppColors.textSecondary
                              : const Color(0xFF333333),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimary
                                : const Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}
