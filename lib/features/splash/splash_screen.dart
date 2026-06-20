import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _subtitleCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _dotScale;
  late Animation<double> _shimmerValue;

  bool _animationCompleted = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Logo animation: fade + scale + slide
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.7, curve: Curves.elasticOut)),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _dotScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.5, 1.0, curve: Curves.elasticOut)),
    );

    // Subtitle fade in
    _subtitleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _subtitleCtrl, curve: Curves.easeIn),
    );

    // Shimmer bar
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shimmerValue = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _subtitleCtrl.forward();
    _shimmerCtrl.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    _animationCompleted = true;
    final auth = ref.read(authProvider);
    if (!auth.isLoading) {
      _navigate();
    }
  }

  void _navigate() {
    if (_navigated) return;
    _navigated = true;
    final auth = ref.read(authProvider);
    if (auth.user != null) {
      final role = auth.role ?? 'brand';
      context.go('/$role/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _subtitleCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isLoading && _animationCompleted) {
        _navigate();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // Animated logo
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Promo',
                        style: GoogleFonts.inter(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFFFBFBEF) : const Color(0xFF000000),
                          letterSpacing: -2,
                        ),
                      ),
                      ScaleTransition(
                        scale: _dotScale,
                        child: Text(
                          '.',
                          style: GoogleFonts.inter(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFA855F7),
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            FadeTransition(
              opacity: _subtitleFade,
              child: Text(
                'Connect · Create · Collaborate',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.textMuted : const Color(0xFF9E9E9E),
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Loading shimmer bar
            AnimatedBuilder(
              animation: _shimmerValue,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment((_shimmerValue.value * 2) - 1, 0),
                    widthFactor: 0.4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 60),
          ],
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
                  color: Colors.black.withValues(alpha: 0.08),
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
