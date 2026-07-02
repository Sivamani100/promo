import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _storyCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _shimmerCtrl;

  late Animation<double> _mergeAnimation;
  late Animation<double> _pulseRadiusAnimation;
  late Animation<double> _pulseOpacityAnimation;
  late Animation<double> _morphAnimation;
  late Animation<double> _textRevealAnimation;
  late Animation<double> _dotScaleAnimation;
  late Animation<double> _subtitleFade;
  late Animation<double> _shimmerValue;

  bool _isLocked = false;

  bool _isVersionOlder(String current, String minimum) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final minParts = minimum.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final currentVal = i < currentParts.length ? currentParts[i] : 0;
        final minVal = i < minParts.length ? minParts[i] : 0;
        if (currentVal < minVal) return true;
        if (currentVal > minVal) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showForceUpdateDialog(String minVersion) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.black.withOpacity(0.85),
            body: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.refresh, color: AppColors.error, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Update Required',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A new version of Promo is available. \nPlease update to continue.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Update Now',
                      onTap: () async {
                        final info = await PackageInfo.fromPlatform();
                        final packageName = info.packageName;
                        final url = 'https://play.google.com/store/apps/details?id=$packageName';
                        try {
                          await url_launcher.launchUrl(
                            Uri.parse(url),
                            mode: url_launcher.LaunchMode.externalApplication,
                          );
                        } catch (e) {
                          debugPrint('Could not launch Play Store URL: $e');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Update Later',
                      isPrimary: false,
                      onTap: () {
                        Navigator.pop(context);
                        _continueAfterUpdateCheck();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _authenticateWithBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) return true;

      return await auth.authenticate(
        localizedReason: 'Please authenticate to unlock Promo',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('[BIOMETRIC] Authentication error: $e');
      return false;
    }
  }

  Widget _buildLockScreenOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Icon(Iconsax.lock, size: 64, color: AppColors.purple),
              const SizedBox(height: 24),
              Text(
                'Promo is Locked',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please unlock using biometric authentication to access your account.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              AppButton(
                label: 'Unlock App',
                icon: Iconsax.finger_scan,
                onTap: () async {
                  final success = await _authenticateWithBiometrics();
                  if (success) {
                    setState(() {
                      _isLocked = false;
                    });
                    ref.read(splashCompletedProvider.notifier).state = true;
                  }
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Sign Out',
                isPrimary: false,
                icon: Iconsax.logout,
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                  setState(() {
                    _isLocked = false;
                  });
                  ref.read(splashCompletedProvider.notifier).state = true;
                },
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }



  @override
  void initState() {
    super.initState();

    // 1. Storytelling animation controller (3.5 seconds)
    _storyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _mergeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    _pulseRadiusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    _pulseOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
      ),
    );

    _morphAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.40, 0.70, curve: Curves.easeInOut),
      ),
    );

    _textRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.65, 0.90, curve: Curves.easeOut),
      ),
    );

    _dotScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.80, 1.0, curve: Curves.elasticOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storyCtrl,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. Floating continuous animation controller
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 3. Shimmer bar loader animation controller
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shimmerValue = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _startAnimation();
  }

  Future<void> _continueAfterUpdateCheck() async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      final biometricEnabled = ref.read(biometricLockProvider);
      if (session != null && biometricEnabled) {
        final success = await _authenticateWithBiometrics();
        if (!success) {
          setState(() {
            _isLocked = true;
          });
          return; // STOP redirect
        }
      }

      if (!mounted) return;
      ref.read(splashCompletedProvider.notifier).state = true;
    } catch (e) {
      debugPrint('Error in splash screen check: $e');
      if (mounted) {
        ref.read(splashCompletedProvider.notifier).state = true;
      }
    }
  }

  Future<void> _startAnimation() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      // Start animations
      _floatCtrl.repeat(reverse: true);
      _shimmerCtrl.repeat(reverse: true);
      final animationFuture = _storyCtrl.forward();

      // 1. Check Force Update in background
      String? minVersion;
      try {
        final configData = await SupabaseService.client
            .from('platform_config')
            .select('value')
            .eq('key', 'min_app_version')
            .maybeSingle();
        minVersion = configData?['value'] as String?;
      } catch (e) {
        debugPrint('[SPLASH] Error checking config: $e');
      }

      if (minVersion != null) {
        final info = await PackageInfo.fromPlatform();
        if (_isVersionOlder(info.version, minVersion)) {
          _showForceUpdateDialog(minVersion);
          return; // STOP splash completion redirect
        }
      }

      // 2. Check biometric requirement state
      final session = SupabaseService.client.auth.currentSession;
      final biometricEnabled = ref.read(biometricLockProvider);
      bool needBiometricLock = false;
      if (session != null && biometricEnabled) {
        final success = await _authenticateWithBiometrics();
        if (!success) {
          needBiometricLock = true;
        }
      }

      // Wait for the storytelling animation to complete playing
      await animationFuture;

      if (!mounted) return;

      if (needBiometricLock) {
        setState(() {
          _isLocked = true;
        });
        return; // STOP redirect
      }

      // All checks complete & animation played: transition
      ref.read(splashCompletedProvider.notifier).state = true;
    } catch (e) {
      debugPrint('Error in splash screen animation: $e');
      if (mounted) {
        ref.read(splashCompletedProvider.notifier).state = true;
      }
    }
  }

  @override
  void dispose() {
    _storyCtrl.dispose();
    _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockScreenOverlay();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // Animated Storytelling Logo Stack (merged circles morphing into cursive Promo.)
            SizedBox(
              height: 120,
              width: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Merging circles
                  FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                      CurvedAnimation(
                        parent: _storyCtrl,
                        curve: const Interval(0.40, 0.70, curve: Curves.easeInOut),
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_storyCtrl, _floatCtrl]),
                      builder: (context, child) {
                        final floatVal = (CurvedAnimation(
                          parent: _floatCtrl,
                          curve: Curves.easeInOut,
                        ).value * 2.0) - 1.0;
                        return CustomPaint(
                          size: const Size(200, 100),
                          painter: StorytellingLogoPainter(
                            floatOffset: floatVal,
                            mergeProgress: _mergeAnimation.value,
                            pulseRadius: _pulseRadiusAnimation.value,
                            pulseOpacity: _pulseOpacityAnimation.value,
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Stylish cursive "Promo." text
                  FadeTransition(
                    opacity: _textRevealAnimation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Promo',
                          style: GoogleFonts.dancingScript(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFBFBEF) : const Color(0xFF000000),
                          ),
                        ),
                        ScaleTransition(
                          scale: _dotScaleAnimation,
                          child: Text(
                            '.',
                            style: GoogleFonts.dancingScript(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA855F7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Loading shimmer bar (visual only)
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

    return content;
  }
}

class StorytellingLogoPainter extends CustomPainter {
  final double floatOffset; // oscillation between -1.0 and 1.0
  final double mergeProgress;
  final double pulseRadius;
  final double pulseOpacity;
  final bool isDark;

  StorytellingLogoPainter({
    required this.floatOffset,
    required this.mergeProgress,
    required this.pulseRadius,
    required this.pulseOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 22.0;

    // 1. Draw collision pulse shockwave (no radial blur shades, simple stroke)
    if (pulseOpacity > 0.01 && pulseRadius > 0.0) {
      final pulseStroke = Paint()
        ..color = const Color(0xFFA855F7).withOpacity(pulseOpacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, pulseRadius * 100, pulseStroke);
    }

    // 2. Draw the two circles (Brand & Influencer)
    // Distance goes from 75px to 0px
    final distance = 75.0 * (1.0 - mergeProgress);

    // Brand Circle (Cyan) - Solid with clean edges
    final brandCenter = Offset(
      center.dx - distance,
      center.dy + (floatOffset * 10.0 * (1.0 - mergeProgress)),
    );
    final brandSolid = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: brandCenter, radius: baseRadius))
      ..style = PaintingStyle.fill;

    // Influencer Circle (Pink) - Solid with clean edges
    final influencerCenter = Offset(
      center.dx + distance,
      center.dy - (floatOffset * 10.0 * (1.0 - mergeProgress)),
    );
    final influencerSolid = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFDB2777), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: influencerCenter, radius: baseRadius))
      ..style = PaintingStyle.fill;

    // Draw solid clean circles
    canvas.drawCircle(brandCenter, baseRadius, brandSolid);
    canvas.drawCircle(influencerCenter, baseRadius, influencerSolid);

    // Blending intersection overlap if overlapping
    if (mergeProgress > 0.5) {
      final overlapPaint = Paint()
        ..color = const Color(0xFFA855F7).withOpacity((mergeProgress - 0.5) * 2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, baseRadius * (mergeProgress - 0.5), overlapPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StorytellingLogoPainter oldDelegate) {
    return oldDelegate.floatOffset != floatOffset ||
        oldDelegate.mergeProgress != mergeProgress ||
        oldDelegate.pulseRadius != pulseRadius ||
        oldDelegate.pulseOpacity != pulseOpacity;
  }
}
