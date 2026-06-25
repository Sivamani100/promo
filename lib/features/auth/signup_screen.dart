import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
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

const _niches = ['Fashion', 'Tech', 'Food', 'Fitness', 'Beauty', 'Travel', 'Gaming', 'Lifestyle'];
const _platforms = ['Instagram', 'YouTube', 'TikTok', 'Twitter/X', 'LinkedIn'];
const _industries = ['Fashion & Apparel', 'Technology & Software', 'Food & Beverage', 'Health & Wellness', 'Beauty & Cosmetics', 'Travel & Tourism', 'Gaming & Esports', 'Lifestyle'];

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  int _step = 1;
  String _role = 'influencer';
  
  // Basic Account Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  // Personal Controllers
  final _nameCtrl = TextEditingController();
  
  // Brand specific Controllers
  final _companyCtrl = TextEditingController();
  String _industry = '';
  
  // Influencer specific Controllers
  final List<String> _selectedNiches = [];
  final List<String> _selectedPlatforms = [];
  final _locationCtrl = TextEditingController();
  
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSignUp() async {
    // Valdiate role specific details before final submission
    if (_role == 'brand' && (_companyCtrl.text.trim().isEmpty || _industry.isEmpty)) {
      _showSnack('Please fill in company name and select an industry.');
      return;
    }
    if (_role == 'influencer' && (_selectedNiches.isEmpty || _selectedPlatforms.isEmpty)) {
      _showSnack('Please select at least one niche and one platform.');
      return;
    }

    setState(() => _loading = true);
    final metadata = <String, dynamic>{
      'role': _role,
      'display_name': _nameCtrl.text.trim(),
    };
    if (_role == 'brand') {
      metadata['company_name'] = _companyCtrl.text.trim();
      metadata['industry'] = _industry;
    } else {
      metadata['niche'] = _selectedNiches;
      metadata['platforms'] = _selectedPlatforms;
      metadata['follower_count'] = 0;
      metadata['location'] = _locationCtrl.text.trim();
    }

    final role = await ref.read(authProvider.notifier).signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text.trim(),
          metadata,
        );
    if (mounted) {
      setState(() => _loading = false);
    }

    if (role == 'brand') {
      if (mounted) context.go('/brand/home');
    } else if (role == 'influencer') {
      if (mounted) context.go('/influencer/home');
    } else {
      _showSnack(ref.read(authProvider).error ?? 'Failed to sign up.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, msg);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _locationCtrl.dispose();
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

  Widget _roleCard({
    required String title,
    required String description,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : const Color(0xFF000000))
              : (isDark ? AppColors.surface : const Color(0xFFFFFFFF)),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF000000))
                : (isDark ? AppColors.border : const Color(0xFFE7EAEB)),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected
                  ? (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
                  : AppColors.textPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected
                    ? (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: selected
                    ? (isDark ? const Color(0x99000000) : const Color(0x99FFFFFF))
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipSelector(String label, List<String> options, List<String> selected) {
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
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selected.remove(opt);
                  } else {
                    selected.add(opt);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF000000))
                      : (isDark ? AppColors.surface : const Color(0xFFFFFFFF)),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF000000))
                        : (isDark ? AppColors.border : const Color(0xFFE7EAEB)),
                  ),
                ),
                child: Text(
                  opt,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildStep1(bool isDark) {
    return [
      Text(
        'Create your\naccount',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 28,
          height: 1.2,
          color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Enter your email and set up a secure password to get started',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.4,
          color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 36),

      _buildInputField(
        label: 'Your Email Address',
        hint: 'you@example.com',
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),

      _buildInputField(
        label: 'Your Password',
        hint: 'Min 6 characters',
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

      _buildInputField(
        label: 'Confirm Your Password',
        hint: '••••••••',
        controller: _confirmPasswordCtrl,
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
      const SizedBox(height: 40),

      Center(
        child: _buildActionButton(
          label: 'Next Step',
          onTap: () {
            final email = _emailCtrl.text.trim();
            final pass = _passwordCtrl.text;
            final confirm = _confirmPasswordCtrl.text;
            if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
              _showSnack('Please fill in all fields.');
              return;
            }
            if (pass.length < 6) {
              _showSnack('Password must be at least 6 characters.');
              return;
            }
            if (pass != confirm) {
              _showSnack('Passwords do not match.');
              return;
            }
            setState(() => _step = 2);
          },
        ),
      ),
      const SizedBox(height: 32),

      Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(
                'Sign in',
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
    ];
  }

  List<Widget> _buildStep2(bool isDark) {
    return [
      Text(
        'Tell us about\nyourself',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 28,
          height: 1.2,
          color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Enter your full name and choose your primary role in the app',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.4,
          color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 36),

      _buildInputField(
        label: 'Your Full Name',
        hint: 'John Doe',
        controller: _nameCtrl,
      ),
      const SizedBox(height: 24),

      Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          'Choose Your Role',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _roleCard(
              title: 'Creator',
              description: 'I want to collaborate with brands',
              icon: Iconsax.crown,
              selected: _role == 'influencer',
              onTap: () => setState(() => _role = 'influencer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _roleCard(
              title: 'Brand',
              description: 'I want to hire creators for campaigns',
              icon: Iconsax.briefcase,
              selected: _role == 'brand',
              onTap: () => setState(() => _role = 'brand'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 48),

      Center(
        child: _buildActionButton(
          label: 'Continue',
          onTap: () {
            if (_nameCtrl.text.trim().isEmpty) {
              _showSnack('Please enter your name.');
              return;
            }
            setState(() => _step = 3);
          },
        ),
      ),
    ];
  }

  List<Widget> _buildStep3(bool isDark) {
    if (_role == 'brand') {
      return [
        Text(
          'Brand details',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 28,
            height: 1.2,
            color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter company name and select your industry',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
            color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 36),

        _buildInputField(
          label: 'Your Company Name',
          hint: 'Acme Corp',
          controller: _companyCtrl,
        ),
        const SizedBox(height: 20),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'Industry',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
                border: Border.all(color: isDark ? AppColors.border : const Color(0xFFE7EAEB)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _industry.isEmpty ? null : _industry,
                  hint: Text(
                    'Select Industry',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  dropdownColor: isDark ? AppColors.surface2 : const Color(0xFFFFFFFF),
                  isExpanded: true,
                  items: _industries
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                              i,
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _industry = v ?? ''),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        Center(
          child: _buildActionButton(
            label: 'Complete Signup',
            onTap: _handleSignUp,
            isLoading: _loading,
          ),
        ),
      ];
    } else {
      return [
        Text(
          'Influencer details',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 28,
            height: 1.2,
            color: isDark ? AppColors.textPrimary : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Select your niche tags, primary channels and reach details',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
            color: isDark ? AppColors.textSecondary : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 36),

        _chipSelector('Niches', _niches, _selectedNiches),
        const SizedBox(height: 20),
        _chipSelector('Platforms', _platforms, _selectedPlatforms),
        const SizedBox(height: 20),

        _buildInputField(
          label: 'Location',
          hint: 'e.g. Mumbai',
          controller: _locationCtrl,
        ),
        const SizedBox(height: 48),

        Center(
          child: _buildActionButton(
            label: 'Complete Signup',
            onTap: _handleSignUp,
            isLoading: _loading,
          ),
        ),
      ];
    }
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
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  if (_step > 1) {
                    setState(() => _step--);
                  } else {
                    context.go('/login');
                  }
                },
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

              if (_step == 1) ..._buildStep1(isDark),
              if (_step == 2) ..._buildStep2(isDark),
              if (_step == 3) ..._buildStep3(isDark),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );

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