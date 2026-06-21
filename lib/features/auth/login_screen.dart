import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onTextChanged);
    _passwordCtrl.addListener(_onTextChanged);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 4.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 4.0, end: -4.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -4.0, end: 0.0), weight: 25),
    ]).animate(_shakeController);
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

    setState(() => _loading = true);
    final role = await ref.read(authProvider.notifier).signIn(email, password);
    if (mounted) {
      setState(() => _loading = false);
    }

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

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        final success = await SupabaseService.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        if (!success) {
          throw Exception('Failed to initiate Google Sign-In redirect.');
        }
        return;
      }

      final googleSignIn = GoogleSignIn(
        serverClientId: '857153035385-9fpe4ne2lo2g5hk2pq8bvqc2bllaaikb.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Could not fetch Google ID token.');
      }

      final role = await ref.read(authProvider.notifier).signInWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) {
        setState(() => _loading = false);
      }

      if (role == 'brand') {
        if (mounted) context.go('/brand/home');
      } else if (role == 'influencer') {
        if (mounted) context.go('/influencer/home');
      } else if (role == 'admin') {
        _showSnack('Admin access is web-only. Please use the web dashboard.');
      } else {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch authState for errors and trigger error shake
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        setState(() {
          _errorMessage = next.error;
        });
        _shakeController.forward(from: 0.0);
      }
    });

    Widget content = Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // --bg-base
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24), // Screen horizontal padding: 24px
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
                      color: const Color(0xFFFFFFFF), // --surface
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE7E4DD), // --border
                        width: 1.0,
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
                          color: const Color(0xFF15171C), // --ink-900
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 48),
              ],

              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Subtitle Frame
                    StaggeredEntryWidget(
                      delay: Duration.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign in to\nyour account',
                            style: GoogleFonts.fraunces(
                              fontWeight: FontWeight.w500,
                              fontSize: 32,
                              height: 1.1875,
                              color: const Color(0xFF15171C), // --ink-900
                              letterSpacing: -0.32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enter your credentials to start matching & collaborating',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                              height: 1.4667,
                              color: const Color(0xFF888B92), // --ink-400
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32), // Vertical rhythm: 32px

                    // Email Input
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 60),
                      child: PremiumInputField(
                        label: 'Your Email Address',
                        hint: 'you@example.com',
                        controller: _emailCtrl,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),

                    const SizedBox(height: 20), // Vertical rhythm: 20px

                    // Password Input
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 120),
                      child: PremiumInputField(
                        label: 'Your Password',
                        hint: '••••••••',
                        controller: _passwordCtrl,
                        focusNode: _passwordFocusNode,
                        obscure: _obscurePassword,
                        errorText: _errorMessage,
                        suffixIcon: HoverablePasswordEye(
                          obscure: _obscurePassword,
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    // Forgot password?
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 180),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: HoverableTextButton(
                            text: 'Forgot password?',
                            onPressed: () => context.push('/reset-password'),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28), // Vertical rhythm: 28px

                    // Sign In Button
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 240),
                      child: PrimaryCtaButton(
                        label: 'Sign In',
                        isLoading: _loading,
                        onPressed: _handleSignIn,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // OR Separator
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 300),
                      child: Row(
                        children: [
                          Expanded(child: Container(height: 1, color: const Color(0xFFE7E4DD))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF888B92), // --ink-400
                                letterSpacing: 0.08 * 12,
                              ),
                            ),
                          ),
                          Expanded(child: Container(height: 1, color: const Color(0xFFE7E4DD))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Google Sign-In Button
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 300),
                      child: GoogleSignInButton(
                        onPressed: _loading ? null : _handleGoogleSignIn,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Bottom Account Section (Don't have an account? Sign up)
                    StaggeredEntryWidget(
                      delay: const Duration(milliseconds: 360),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF888B92), // --ink-400
                                height: 1.4286,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/signup'),
                              child: Text(
                                'Sign up',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB08D57), // --accent
                                  height: 1.4286,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
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
              borderRadius: BorderRadius.circular(20),
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

// ========== Custom Supporting Premium Widgets ==========

class StaggeredEntryWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const StaggeredEntryWidget({super.key, required this.child, required this.delay});

  @override
  State<StaggeredEntryWidget> createState() => _StaggeredEntryWidgetState();
}

class _StaggeredEntryWidgetState extends State<StaggeredEntryWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _translateAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final disableAnimations = MediaQuery.of(context).disableAnimations;
      Future.delayed(widget.delay, () {
        if (mounted) {
          if (disableAnimations) {
            _controller.value = 1.0;
          } else {
            _controller.forward();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _translateAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class PremiumInputField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final FocusNode focusNode;
  final String? errorText;

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
    final hasError = widget.errorText != null;
    
    Color borderColor = const Color(0xFFE7E4DD); // --border
    if (hasError) {
      borderColor = const Color(0xFFC2483A); // --error
    } else if (_isFocused) {
      borderColor = const Color(0xFFB08D57); // --border-focus
    }

    Color labelColor = const Color(0xFF33353B); // --ink-700
    if (hasError) {
      labelColor = const Color(0xFFC2483A);
    } else if (_isFocused) {
      labelColor = const Color(0xFFB08D57); // --accent
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: labelColor,
            letterSpacing: 0.02,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: (_isFocused && !hasError)
                ? [
                    BoxShadow(
                      color: const Color(0xFFB08D57).withOpacity(0.12),
                      blurRadius: 3,
                      spreadRadius: 3,
                    )
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            cursorColor: const Color(0xFFB08D57),
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.5,
              color: const Color(0xFF15171C), // --ink-900
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF888B92), // --ink-400
              ),
              filled: true,
              fillColor: const Color(0xFFFFFFFF), // --surface
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFC2483A), width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFC2483A), width: 1.5),
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.errorText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: AnimatedOpacity(
                    opacity: hasError ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    child: Text(
                      widget.errorText!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFC2483A), // --error
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
    final iconColor = _isHovered ? const Color(0xFF15171C) : const Color(0xFF888B92);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IconButton(
        padding: const EdgeInsets.only(right: 12),
        icon: AnimatedCrossFade(
          duration: const Duration(milliseconds: 150),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            widget.text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFB08D57), // --accent
              decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
              decorationColor: const Color(0xFFB08D57),
            ),
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
    if (widget.isDisabled) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF888B92).withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: const Color(0xFFFAF9F6).withOpacity(0.6),
            letterSpacing: 0.01,
          ),
        ),
      );
    }

    final bgColor = _isHovered ? const Color(0xFF1F2128) : const Color(0xFF15171C);
    final scale = _isPressed ? 0.98 : 1.0;
    
    final shadow = (_isHovered && !_isPressed)
        ? const [
            BoxShadow(
              color: Color.fromRGBO(21, 23, 28, 0.18),
              blurRadius: 20,
              offset: Offset(0, 8),
            )
          ]
        : <BoxShadow>[];

    final translateOffset = (_isHovered && !_isPressed) ? -1.0 : 0.0;

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
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadow,
          ),
          transform: Matrix4.translationValues(0, translateOffset, 0)..scale(scale, scale),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAF9F6)),
                  ),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: const Color(0xFFFAF9F6), // --text-on-inverse
                    letterSpacing: 0.01,
                  ),
                ),
        ),
      ),
    );
  }
}

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const GoogleSignInButton({super.key, this.onPressed});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHovered ? const Color(0xFFF5F3EE) : const Color(0xFFFFFFFF);
    final borderColor = _isHovered ? const Color(0xFFD8D4CB) : const Color(0xFFE7E4DD);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://developers.google.com/identity/images/g-logo.png',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Sign In with Google',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: const Color(0xFF33353B), // --ink-700
                    letterSpacing: 0.01,
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
    path.moveTo(14.9998, 19.9201);
    path.lineTo(8.47984, 13.4001);
    path.cubicTo(7.70984, 12.6301, 7.70984, 11.3701, 8.47984, 10.6001);
    path.lineTo(14.9998, 4.08008);

    final matrix = Matrix4.identity();
    matrix.scale(size.width / 24.0, size.height / 24.0);
    final scaledPath = path.transform(matrix.storage);

    canvas.drawPath(scaledPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}