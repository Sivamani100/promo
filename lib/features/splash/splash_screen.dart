import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  late Animation<double> _sweepProgress;
  bool _isFontLoaded = false;
  bool _isLocked = false;
  bool _hasNavigated = false;
  bool _backgroundChecksDone = false;
  bool _needBiometricLock = false;

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
    // local_auth is not supported on Web
    if (kIsWeb) return true;
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

    // 1.5 seconds color sweep animation from left to right
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _sweepProgress = Tween<double>(begin: -0.2, end: 1.2).animate(
      CurvedAnimation(
        parent: _sweepController,
        curve: Curves.easeInOutCubic,
      ),
    );

    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      _isFontLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sweepController.forward().then((_) => _onAnimationFinished());
        }
      });
    } else {
      // Preload My Soul font to prevent FOUT (Flash of Unstyled Text)
      GoogleFonts.pendingFonts([
        GoogleFonts.mySoul(),
      ]).then((_) {
        if (mounted) {
          setState(() {
            _isFontLoaded = true;
          });
          // Start the sweep animation only AFTER the font is fully loaded and ready
          _sweepController.forward().then((_) => _onAnimationFinished());
        }
      }).catchError((error) {
        debugPrint('[SPLASH] Failed to preload custom font: $error');
        if (mounted) {
          setState(() {
            _isFontLoaded = true;
          });
          _sweepController.forward().then((_) => _onAnimationFinished());
        }
      });
    }

    _runBackgroundChecks();
  }

  void _onAnimationFinished() async {
    debugPrint('[SPLASH] _onAnimationFinished entered');
    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      // Hold the completed state for 0.5 seconds
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('[SPLASH] _onAnimationFinished after delay, mounted: $mounted');
    if (!mounted) return;

    if (_needBiometricLock) {
      debugPrint('[SPLASH] _onAnimationFinished - need biometric lock');
      setState(() {
        _isLocked = true;
      });
      return;
    }

    if (_backgroundChecksDone) {
      debugPrint('[SPLASH] _onAnimationFinished - background checks done, navigating');
      _navigateToNextScreen();
    } else {
      debugPrint('[SPLASH] _onAnimationFinished - waiting for background checks');
      // Wait for background checks to complete
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !_backgroundChecksDone && mounted;
      }).then((_) {
        debugPrint('[SPLASH] _onAnimationFinished - after wait, checks done: $_backgroundChecksDone, lock: $_needBiometricLock');
        if (_needBiometricLock) {
          if (mounted) {
            setState(() {
              _isLocked = true;
            });
          }
        } else {
          _navigateToNextScreen();
        }
      });
    }
  }

  Future<void> _runBackgroundChecks() async {
    debugPrint('[SPLASH] _runBackgroundChecks started');
    try {
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
          _hasNavigated = true;
          _showForceUpdateDialog(minVersion);
          return;
        }
      }

      // 2. Check biometrics
      final session = SupabaseService.client.auth.currentSession;
      final biometricEnabled = ref.read(biometricLockProvider);
      if (session != null && biometricEnabled) {
        final success = await _authenticateWithBiometrics();
        if (!success) {
          _needBiometricLock = true;
        }
      }
    } catch (e) {
      debugPrint('[SPLASH] Error in background checks: $e');
    } finally {
      _backgroundChecksDone = true;
      debugPrint('[SPLASH] _runBackgroundChecks finished');
    }
  }

  void _navigateToNextScreen() {
    debugPrint('[SPLASH] _navigateToNextScreen called, hasNavigated: $_hasNavigated, mounted: $mounted');
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    ref.read(splashCompletedProvider.notifier).state = true;
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
          return;
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

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockScreenOverlay();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 600;

    // Theme-specific colors
    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color initialTextColor = isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB);
    final Color targetTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: _isFontLoaded
            ? AnimatedBuilder(
                animation: _sweepProgress,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          targetTextColor,
                          targetTextColor,
                          initialTextColor,
                          initialTextColor,
                        ],
                        stops: [
                          0.0,
                          (_sweepProgress.value).clamp(0.0, 1.0),
                          (_sweepProgress.value + 0.15).clamp(0.0, 1.0),
                          1.0,
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn,
                    child: child,
                  );
                },
                child: Text(
                  'Promo',
                  style: GoogleFonts.mySoul(
                    fontSize: isWide ? 130 : 88,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : const SizedBox.shrink(), // Render empty space with bgColor until font is fully loaded
      ),
    );
  }
}
