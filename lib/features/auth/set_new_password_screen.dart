import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';

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
    // Simple check for at least a letter and a number to align with figma spec description:
    // "At least 8 characters, containing a letter and a number"
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    if (!hasLetter || !hasNumber) {
      _showSnack('Password must contain at least one letter and one number.');
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

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
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
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.textMuted : const Color(0xFF333333).withOpacity(0.5),
            ),
            filled: true,
            fillColor: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE7EAEB), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE7EAEB), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000), width: 1.5),
            ),
            suffixIcon: suffixIcon,
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
            color: Colors.black.withOpacity(0.12),
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
                  color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
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
                  color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
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
              // Top Back button
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _goToLogin,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(16, 16),
                      painter: SvgBackIconPainter(
                        color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 44),

              if (_done) ...[
                // Success message
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
                      const SizedBox(height: 24),
                      Text(
                        'Password Updated!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your password has been successfully changed. You can now sign in with your new password.',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 1.4,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _buildActionButton(label: 'Go to Sign In', onTap: _goToLogin),
                    ],
                  ),
                ),
              ] else ...[
                // New Password Input Form (Figma spec "Onboarding 13")
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let’s Create\nPassword',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 28,
                        height: 1.2,
                        color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use the Different password style that it should be differ from your previous',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.4,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Password input
                _buildInputField(
                  label: 'Enter Password',
                  hint: 'Password',
                  controller: _passwordCtrl,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Iconsax.eye : Iconsax.eye_slash,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password input
                _buildInputField(
                  label: 'Confirm Password',
                  hint: 'Confirm Password',
                  controller: _confirmCtrl,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Iconsax.eye : Iconsax.eye_slash,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                const SizedBox(height: 12),

                // Password constraints text
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'At least 8 characters, containing a letter and a number',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Update Password button
                Center(
                  child: _buildActionButton(
                    label: 'Update Password',
                    onTap: _handleSetPassword,
                    isLoading: _loading,
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );

    // Mockup frame for Web browser viewport
    if (kIsWeb) {
      return Container(
        color: isDark ? const Color(0xFF14141E) : const Color(0xFFF2F2F7),
        child: Center(
          child: Container(
            width: 393,
            height: 852,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: content,
            ),
          ),
        ),
      );
    }

    return content;
  }
}

class SvgBackIconPainter extends CustomPainter {
  final Color color;
  const SvgBackIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // M14.9998 19.9201
    path.moveTo(14.9998, 19.9201);
    // L8.47984 13.4001
    path.lineTo(8.47984, 13.4001);
    // C7.70984 12.6301 7.70984 11.3701 8.47984 10.6001
    path.cubicTo(7.70984, 12.6301, 7.70984, 11.3701, 8.47984, 10.6001);
    // L14.9998 4.08008
    path.lineTo(14.9998, 4.08008);

    // Scale painter to fit constraints if different from 24x24 viewBox
    final matrix = Matrix4.identity();
    matrix.scale(size.width / 24.0, size.height / 24.0);
    final scaledPath = path.transform(matrix.storage);

    canvas.drawPath(scaledPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
