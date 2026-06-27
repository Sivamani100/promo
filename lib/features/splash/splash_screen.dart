import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  late AnimationController _logoCtrl;
  late AnimationController _subtitleCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _dotScale;
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
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _logoCtrl.forward();

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _subtitleCtrl.forward();
      _shimmerCtrl.repeat(reverse: true);

      // 1. Check Force Update
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

      // 2. Check Biometric Lock
      final session = SupabaseService.client.auth.currentSession;
      final biometricEnabled = ref.read(biometricLockProvider);
      if (session != null && biometricEnabled) {
        final success = await _authenticateWithBiometrics();
        if (!success) {
          setState(() {
            _isLocked = true;
          });
          return; // STOP splash completion redirect, lock overlay shows
        }
      }

      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
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
    _logoCtrl.dispose();
    _subtitleCtrl.dispose();
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
