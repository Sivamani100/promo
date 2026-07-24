import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'package:iconsax/iconsax.dart';

import 'widgets/auth_background.dart';
import 'widgets/glass_container.dart';
import 'widgets/google_sign_in_button.dart';
import '../../shared/widgets/password_strength_meter.dart';

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

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  final _companyFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();
  
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSignUp() async {
    // Validate role specific details before final submission
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

    if (role == null) {
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
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nameFocusNode.dispose();
    _companyFocusNode.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          cursorColor: isDark ? AppColors.purpleLight : const Color(0xFFB08D57),
          style: GoogleFonts.inter(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? AppColors.purpleLight : const Color(0xFFB08D57), width: 1.5),
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
    
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        bool isPressed = false;

        final bgColor = isDark
            ? (isHovered ? Colors.white.withOpacity(0.9) : Colors.white)
            : (isHovered ? Colors.black87 : Colors.black);
        final textColor = isDark ? Colors.black : Colors.white;
        final scale = isPressed ? 0.96 : 1.0;

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => isPressed = true),
            onTapUp: (_) => setState(() => isPressed = false),
            onTapCancel: () => setState(() => isPressed = false),
            onTap: isLoading ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              height: 54,
              width: double.infinity,
              transform: Matrix4.identity()..scale(scale, scale),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: isHovered && !isPressed
                    ? [
                        BoxShadow(
                          color: isDark ? Colors.white24 : Colors.black26,
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        );
      },
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
    
    return StatefulBuilder(builder: (context, setState) {
      bool isHovered = false;
      bool isPressed = false;
      
      final bgColor = selected
          ? (isDark ? Colors.white : Colors.black)
          : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02));
      final borderColor = selected
          ? (isDark ? Colors.white : Colors.black)
          : (isDark ? Colors.white24 : Colors.black12);
      final iconColor = selected
          ? (isDark ? Colors.black : Colors.white)
          : (isDark ? Colors.white : Colors.black);
      final titleColor = selected
          ? (isDark ? Colors.black : Colors.white)
          : (isDark ? Colors.white : Colors.black);
      final descColor = selected
          ? (isDark ? Colors.black54 : Colors.white70)
          : (isDark ? Colors.white54 : Colors.black54);
          
      final scale = isPressed ? 0.95 : (isHovered && !selected ? 1.02 : 1.0);

      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) => setState(() => isPressed = false),
          onTapCancel: () => setState(() => isPressed = false),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            transform: Matrix4.identity()..scale(scale, scale),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: selected ? 2.0 : 1.0),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isHovered && !selected
                ? [
                    BoxShadow(
                      color: isDark ? Colors.white10 : Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: iconColor,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: descColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _chipSelector(String label, List<String> options, List<String> selected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? Colors.white24 : Colors.black12),
                  ),
                ),
                child: Text(
                  opt,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white : Colors.black),
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
      _buildInputField(
        label: 'Email Address',
        hint: 'you@example.com',
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        focusNode: _emailFocusNode,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
      ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
      const SizedBox(height: 20),

      _buildInputField(
        label: 'Password',
        hint: 'Min 6 characters',
        controller: _passwordCtrl,
        obscure: _obscurePassword,
        focusNode: _passwordFocusNode,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Iconsax.eye : Iconsax.eye_slash,
            size: 20,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
      // SECURITY: Live password strength meter
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordCtrl,
          builder: (_, value, __) => PasswordStrengthMeter(password: value.text),
        ),
      ),
      const SizedBox(height: 20),

      _buildInputField(
        label: 'Confirm Password',
        hint: '••••••••',
        controller: _confirmPasswordCtrl,
        obscure: _obscureConfirmPassword,
        focusNode: _confirmPasswordFocusNode,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          final email = _emailCtrl.text.trim();
          final pass = _passwordCtrl.text;
          final confirm = _confirmPasswordCtrl.text;
          if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
            _showSnack('Please fill in all fields.');
            return;
          }
          if (pass.length < 8) {
            _showSnack('Password must be at least 8 characters.');
            return;
          }
          if (!RegExp(r'[A-Z]').hasMatch(pass)) {
            _showSnack('Password must contain at least one uppercase letter.');
            return;
          }
          if (!RegExp(r'[0-9]').hasMatch(pass)) {
            _showSnack('Password must contain at least one number.');
            return;
          }
          if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(pass)) {
            _showSnack('Password must contain at least one special character.');
            return;
          }
          final emailPrefix = email.split('@').first.toLowerCase();
          if (emailPrefix.length >= 3 && pass.toLowerCase().contains(emailPrefix)) {
            _showSnack('Password cannot contain your email username.');
            return;
          }
          if (pass != confirm) {
            _showSnack('Passwords do not match.');
            return;
          }
          setState(() => _step = 2);
        },
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Iconsax.eye : Iconsax.eye_slash,
            size: 20,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ).animate().fade(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),
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
            if (pass.length < 8) {
              _showSnack('Password must be at least 8 characters.');
              return;
            }
            if (!RegExp(r'[A-Z]').hasMatch(pass)) {
              _showSnack('Password must contain at least one uppercase letter.');
              return;
            }
            if (!RegExp(r'[0-9]').hasMatch(pass)) {
              _showSnack('Password must contain at least one number.');
              return;
            }
            if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(pass)) {
              _showSnack('Password must contain at least one special character.');
              return;
            }
            final emailPrefix = email.split('@').first.toLowerCase();
            if (emailPrefix.length >= 3 && pass.toLowerCase().contains(emailPrefix)) {
              _showSnack('Password cannot contain your email username.');
              return;
            }
            if (pass != confirm) {
              _showSnack('Passwords do not match.');
              return;
            }
            setState(() => _step = 2);
          },
        ),
      ).animate().fade(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2, end: 0),
      const SizedBox(height: 32),
      
      Center(
        child: GoogleSignInButton(
          label: 'Sign up with Google',
          onPressed: () {
            // Google Sign Up Logic
          },
        ),
      ).animate().fade(duration: 400.ms, delay: 550.ms).slideY(begin: 0.2, end: 0),
    ];
  }

  List<Widget> _buildStep2(bool isDark) {
    return [
      Text(
        'Tell us about\nyourself',
        style: GoogleFonts.fraunces(
          fontWeight: FontWeight.w600,
          fontSize: 32,
          height: 1.1875,
          color: isDark ? Colors.white : const Color(0xFF15171C),
          letterSpacing: -0.32,
        ),
      ).animate().fade(duration: 400.ms).slideY(begin: 0.2, end: 0),
      const SizedBox(height: 12),
      Text(
        'Enter your full name and choose your primary role in the app',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 15,
          height: 1.4,
          color: isDark ? Colors.white70 : const Color(0xFF55575C),
        ),
      ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
      const SizedBox(height: 36),

      _buildInputField(
        label: 'Full Name',
        hint: 'John Doe',
        controller: _nameCtrl,
        focusNode: _nameFocusNode,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (_nameCtrl.text.trim().isEmpty) {
            _showSnack('Please enter your name.');
            return;
          }
          setState(() => _step = 3);
        },
      ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
      const SizedBox(height: 24),

      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'Choose Your Role',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
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
          const SizedBox(width: 16),
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
      ).animate().fade(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),
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
      ).animate().fade(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2, end: 0),
    ];
  }

  List<Widget> _buildStep3(bool isDark) {
    if (_role == 'brand') {
      return [
        Text(
          'Brand details',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w600,
            fontSize: 32,
            height: 1.1875,
            color: isDark ? Colors.white : const Color(0xFF15171C),
            letterSpacing: -0.32,
          ),
        ).animate().fade(duration: 400.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        Text(
          'Enter company name and select your industry',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.white70 : const Color(0xFF55575C),
          ),
        ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 36),

        _buildInputField(
          label: 'Company Name',
          hint: 'Acme Corp',
          controller: _companyCtrl,
          focusNode: _companyFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSignUp(),
        ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 20),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Industry',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _industry.isEmpty ? null : _industry,
                  hint: Text(
                    'Select Industry',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  dropdownColor: isDark ? const Color(0xFF1F2128) : Colors.white,
                  isExpanded: true,
                  icon: Icon(Iconsax.arrow_down_1, size: 20, color: isDark ? Colors.white54 : Colors.black54),
                  items: _industries
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                              i,
                              style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white : Colors.black),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _industry = v ?? ''),
                ),
              ),
            ),
          ],
        ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 48),

        Center(
          child: _buildActionButton(
            label: 'Complete Signup',
            onTap: _handleSignUp,
            isLoading: _loading,
          ),
        ).animate().fade(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),
      ];
    } else {
      return [
        Text(
          'Influencer details',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w600,
            fontSize: 32,
            height: 1.1875,
            color: isDark ? Colors.white : const Color(0xFF15171C),
            letterSpacing: -0.32,
          ),
        ).animate().fade(duration: 400.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        Text(
          'Select your niche tags, primary channels and reach details',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.white70 : const Color(0xFF55575C),
          ),
        ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 36),

        _chipSelector('Niches', _niches, _selectedNiches)
            .animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 24),
        
        _chipSelector('Platforms', _platforms, _selectedPlatforms)
            .animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 24),

        _buildInputField(
          label: 'Location',
          hint: 'e.g. Mumbai',
          controller: _locationCtrl,
          focusNode: _locationFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSignUp(),
        ).animate().fade(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 48),

        Center(
          child: _buildActionButton(
            label: 'Complete Signup',
            onTap: _handleSignUp,
            isLoading: _loading,
          ),
        ).animate().fade(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2, end: 0),
      ];
    }
  }

  Widget _buildSegmentedTab({required bool isLogin}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isLogin) context.go('/login');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isLogin
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isLogin
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Login',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isLogin ? FontWeight.w700 : FontWeight.w500,
                      color: isLogin
                          ? (isDark ? Colors.white : const Color(0xFF111827))
                          : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isLogin) context.go('/signup');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !isLogin
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: !isLogin
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Sign up',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: !isLogin ? FontWeight.w700 : FontWeight.w500,
                      color: !isLogin
                          ? (isDark ? Colors.white : const Color(0xFF111827))
                          : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mascot / Security Badge Header
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
                          Iconsax.user_add,
                          size: 30,
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
                            Iconsax.star1,
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
                  'Create account 👋',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 6),

                Text(
                  'Enter your details to register your account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ).animate().fade(duration: 300.ms, delay: 50.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 24),

                // Segmented Switcher (Login / Sign up)
                _buildSegmentedTab(isLogin: false)
                    .animate()
                    .fade(duration: 300.ms, delay: 100.ms),

                const SizedBox(height: 24),

                // Animated Step Content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_step == 1) ..._buildStep1(isDark),
                        if (_step == 2) ..._buildStep2(isDark),
                        if (_step == 3) ..._buildStep3(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}