import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'package:iconsax/iconsax.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.');
      return;
    }

    setState(() => _loading = true);
    final role = await ref.read(authProvider.notifier).signIn(email, password);
    setState(() => _loading = false);

    if (role == 'brand') {
      if (mounted) context.go('/brand/home');
    } else if (role == 'influencer') {
      if (mounted) context.go('/influencer/home');
    } else if (role == 'admin') {
      _showSnack('Admin access is web-only. Please use the web dashboard.');
    } else {
      final error = ref.read(authProvider).error;
      _showSnack(error ?? 'Failed to sign in.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
              // Back Button (shown if can pop, matches Figma style circular button)
              if (Navigator.of(context).canPop()) ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.pop(),
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
              ] else ...[
                const SizedBox(height: 110),
              ],

              // Title and Subtitle Frame
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in to\nyour account',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      height: 1.2,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your credentials to start matching & collaborating',
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

              // Email Input
              _buildInputField(
                label: 'Your Email Address',
                hint: 'you@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // Password Input
              _buildInputField(
                label: 'Your Password',
                hint: '••••••••',
                controller: _passwordCtrl,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Iconsax.eye : Iconsax.eye_slash,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),

              // Forgot password?
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/reset-password'),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Button Container (Width 283px, Height 45px, fully rounded, center aligned)
              Center(
                child: Container(
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
                  child: _loading
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
                          onPressed: _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(62),
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Bottom Account Section (Don't have an account? Sign up)
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: Text(
                        'Sign up',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );

    // Render mockup frame centered in the web viewport to mirror figma canvas exactly
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