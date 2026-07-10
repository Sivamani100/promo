import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../../shared/widgets/shared_widgets.dart';

/// ResumeAuthGate gates the screen with a biometric lock when the app is resumed
/// from background after more than 5 minutes, if enabled in settings.
class ResumeAuthGate extends ConsumerStatefulWidget {
  final Widget child;
  const ResumeAuthGate({super.key, required this.child});

  @override
  ConsumerState<ResumeAuthGate> createState() => _ResumeAuthGateState();
}

class _ResumeAuthGateState extends ConsumerState<ResumeAuthGate> with WidgetsBindingObserver {
  DateTime? _backgroundedTime;
  bool _isLocked = false;
  bool _authenticating = false;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Biometric lock is not supported on Web
    if (kIsWeb) return;

    final user = ref.read(authProvider).user;
    final isBiometricEnabled = ref.read(biometricLockProvider);

    // If user is not logged in or doesn't have biometric lock enabled, do nothing.
    if (user == null || !isBiometricEnabled) {
      _backgroundedTime = null;
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _backgroundedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedTime != null) {
        final elapsed = DateTime.now().difference(_backgroundedTime!);
        // Gate access if app was backgrounded for more than 5 minutes
        if (elapsed.inMinutes >= 5) {
          setState(() {
            _isLocked = true;
          });
          _authenticate();
        } else {
          // Clear background time if below threshold
          _backgroundedTime = null;
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (kIsWeb || _authenticating) return;
    setState(() => _authenticating = true);

    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        // If not supported or set up, unlock immediately
        setState(() {
          _isLocked = false;
          _authenticating = false;
        });
        _backgroundedTime = null;
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Please verify your identity to unlock Promo',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _isLocked = false;
          _authenticating = false;
        });
        _backgroundedTime = null;
      } else {
        setState(() => _authenticating = false);
      }
    } catch (e) {
      debugPrint('[RESUME_LOCK] Authentication error: $e');
      setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) {
      return widget.child;
    }

    final isDark = AppColors.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.lock5,
                    size: 64,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Promo is Locked',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your session expired due to inactivity. Please authenticate with Face ID or fingerprint to resume.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: 'Unlock with Biometrics',
                  icon: Iconsax.finger_scan,
                  onTap: _authenticate,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    // Reset lock and sign out
                    setState(() {
                      _isLocked = false;
                      _backgroundedTime = null;
                    });
                    await ref.read(authProvider.notifier).signOut();
                  },
                  icon: Icon(Iconsax.logout, size: 18, color: AppColors.error),
                  label: Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
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
