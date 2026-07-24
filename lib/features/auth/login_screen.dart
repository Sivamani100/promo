import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_one_tap_sign_in/google_one_tap_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/app_providers.dart';
import 'package:iconsax/iconsax.dart';

import '../../shared/widgets/analytics_consent_dialog.dart';
import '../../core/security/brute_force_guard.dart';
import 'widgets/auth_background.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/glass_container.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _bruteForceCountdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsConsentDialog.checkAndShow(context);
    });
    _emailCtrl.addListener(_onTextChanged);
    _passwordCtrl.addListener(_onTextChanged);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 8.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 8.0, end: -8.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -8.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  void _onTextChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_onTextChanged);
    _passwordCtrl.removeListener(_onTextChanged);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.');
      return;
    }

    // SECURITY: Check brute force status before attempting login
    final blockStatus = BruteForceGuard.checkStatus(email);
    if (blockStatus != null && blockStatus.isBlocked) {
      if (blockStatus.type == LoginBlockType.delayed) {
        final secs = blockStatus.delayRemaining?.inSeconds ?? 30;
        setState(() => _bruteForceCountdown = secs);
        _showSnack(blockStatus.message);
        _shakeController.forward(from: 0);
        return;
      }
      _showSnack(blockStatus.message);
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _loading = true);
    final role = await ref.read(authProvider.notifier).signIn(email, password);
    if (mounted) {
      setState(() => _loading = false);
    }

    if (role == 'admin') {
      _showSnack('Admin access is web-only. Please use the web dashboard.');
    } else if (role == null) {
      // SECURITY: Record failed attempt and enforce progressive lockout
      final result = BruteForceGuard.recordFailure(email);
      final error = ref.read(authProvider).error;
      final message = result.isBlocked ? result.message : (error ?? 'Failed to sign in.');
      _showSnack(message);
      _shakeController.forward(from: 0);
    } else {
      // SECURITY: Clear attempt history on successful login
      BruteForceGuard.recordSuccess(email);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final googleServerClientId = const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '857153035385-ghuulmjm3j1ttisphp10kv34lmhut0vc.apps.googleusercontent.com',
      );

      if (kIsWeb) {
        final success = await SupabaseService.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: '${Uri.base.origin}/app/',
        );
        if (!success) {
          throw Exception('Failed to initiate Google Sign-In redirect.');
        }
        return;
      }

      String? role;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final data = await GoogleOneTapSignIn.startSignIn(webClientId: googleServerClientId);
        if (data == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        final idToken = data.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Google sign-in did not return a valid ID token.');
        }

        role = await ref.read(authProvider.notifier).signInWithGoogle(
          idToken: idToken,
        );
      } else {
        final googleSignIn = GoogleSignIn(
          serverClientId: googleServerClientId,
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null || idToken.isEmpty) {
          throw Exception('Google sign-in did not return a valid ID token.');
        }

        role = await ref.read(authProvider.notifier).signInWithGoogle(
          idToken: idToken,
          accessToken: accessToken,
        );
      }

      if (mounted) {
        setState(() => _loading = false);
      }

      if (role == 'admin') {
        _showSnack('Admin access is web-only. Please use the web dashboard.');
      } else if (role == null) {
        final error = ref.read(authProvider).error;
        _showSnack(error ?? 'Failed to sign in with Google.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Google Authentication error: $e');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, msg);
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

  void showLoginSuccessDialog(BuildContext context, String role) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF60A5FA).withOpacity(0.15),
                ),
                child: const Icon(
                  Iconsax.verify,
                  size: 48,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Login Successful',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everything looks good, moving you ahead',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(role == 'brand' ? '/brand/home' : '/influencer/home');
                },
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      'Got it',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        setState(() {
          _errorMessage = next.error;
        });
        _shakeController.forward(from: 0.0);
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    'Welcome back 👋',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 6),

                  Text(
                    'Enter your details to access your account',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                  ).animate().fade(duration: 300.ms, delay: 50.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  _buildSegmentedTab(isLogin: true)
                      .animate()
                      .fade(duration: 300.ms, delay: 100.ms),

                  const SizedBox(height: 24),

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
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                        style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white : const Color(0xFF111827)),
                        decoration: InputDecoration(
                          hintText: 'name@company.com',
                          hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: isDark ? AppColors.surface : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms, delay: 150.ms),

                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordCtrl,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSignIn(),
                        style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white : const Color(0xFF111827)),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: isDark ? AppColors.surface : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.border : const Color(0xFFE5E7EB)),
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
                    ],
                  ).animate().fade(duration: 300.ms, delay: 200.ms),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => context.push('/reset-password'),
                        child: Text(
                          'Forgot Password',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  GestureDetector(
                    onTap: _loading ? null : _handleSignIn,
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
                          )
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
                                'Login',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ).animate().fade(duration: 300.ms, delay: 250.ms),

                  const SizedBox(height: 20),

                  // Google Sign-In Option
                  GoogleSignInButton(
                    onPressed: _loading ? null : _handleGoogleSignIn,
                  ).animate().fade(duration: 300.ms, delay: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== Custom Supporting Premium Widgets ==========

class PremiumInputField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final FocusNode focusNode;
  final String? errorText;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const PremiumInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<PremiumInputField> createState() => _PremiumInputFieldState();
}

class _PremiumInputFieldState extends State<PremiumInputField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null;
    
    Color borderColor = isDark ? Colors.white24 : Colors.black12;
    if (hasError) {
      borderColor = const Color(0xFFE53935);
    } else if (_isFocused) {
      borderColor = isDark ? AppColors.purpleLight : const Color(0xFFB08D57);
    }

    Color labelColor = isDark ? Colors.white70 : Colors.black87;
    if (hasError) {
      labelColor = const Color(0xFFE53935);
    } else if (_isFocused) {
      labelColor = isDark ? AppColors.purpleLight : const Color(0xFFB08D57);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: labelColor,
            letterSpacing: 0.02,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_isFocused && !hasError)
                ? [
                    BoxShadow(
                      color: (isDark ? AppColors.purple : const Color(0xFFB08D57)).withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            cursorColor: isDark ? AppColors.purpleLight : const Color(0xFFB08D57),
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
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
                borderSide: BorderSide(color: borderColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.errorText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: AnimatedOpacity(
                    opacity: hasError ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      widget.errorText!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class HoverablePasswordEye extends StatefulWidget {
  final bool obscure;
  final VoidCallback onPressed;
  const HoverablePasswordEye({super.key, required this.obscure, required this.onPressed});

  @override
  State<HoverablePasswordEye> createState() => _HoverablePasswordEyeState();
}

class _HoverablePasswordEyeState extends State<HoverablePasswordEye> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _isHovered 
      ? (isDark ? Colors.white : Colors.black) 
      : (isDark ? Colors.white54 : Colors.black54);
      
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IconButton(
        padding: const EdgeInsets.only(right: 12),
        icon: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          firstChild: Icon(Iconsax.eye, size: 20, color: iconColor),
          secondChild: Icon(Iconsax.eye_slash, size: 20, color: iconColor),
          crossFadeState: widget.obscure ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

class HoverableTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const HoverableTextButton({super.key, required this.text, required this.onPressed});

  @override
  State<HoverableTextButton> createState() => _HoverableTextButtonState();
}

class _HoverableTextButtonState extends State<HoverableTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.purpleLight : const Color(0xFFB08D57);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isHovered ? color.withOpacity(0.8) : color,
              decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
              decorationColor: color.withOpacity(0.8),
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}

class PrimaryCtaButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onPressed;
  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.isDisabled = false,
    this.onPressed,
  });

  @override
  State<PrimaryCtaButton> createState() => _PrimaryCtaButtonState();
}

class _PrimaryCtaButtonState extends State<PrimaryCtaButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.isDisabled) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white30 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final bgColor = isDark
        ? (_isHovered ? Colors.white.withOpacity(0.9) : Colors.white)
        : (_isHovered ? Colors.black87 : Colors.black);
    final textColor = isDark ? Colors.black : Colors.white;
    final scale = _isPressed ? 0.96 : 1.0;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: 54,
          transform: Matrix4.identity()..scale(scale, scale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: _isHovered && !_isPressed
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
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Text(
                  widget.label,
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
  }
}
