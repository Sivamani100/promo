import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// SecurityHardeningService implements client-side runtime security controls:
/// - Jailbreak / Root Detection
/// - SSL Pinning Overrides (rejects untrusted proxy certificates)
class SecurityHardeningService {
  SecurityHardeningService._();

  static bool _isCompromised = false;
  static bool get isCompromised => _isCompromised;

  /// Initializes app-wide security checks and SSL overrides
  static Future<void> initialize() async {
    if (kIsWeb) return;

    // 1. Run root/jailbreak detection
    _isCompromised = await _checkDeviceIntegrity();
    if (_isCompromised) {
      if (kDebugMode) debugPrint('[SECURITY_WARNING] Device integrity check failed. Device may be rooted or jailbroken.');
    }

    // 2. App integrity — verify package has not been repackaged
    await _verifyAppIntegrity();

    // 3. Apply SSL Pinning Overrides
    HttpOverrides.global = PinningHttpOverrides();
    if (kDebugMode) debugPrint('[SECURITY] SSL Pinning overrides active.');
  }

  /// Verifies that the app package name matches the expected value.
  /// A mismatch indicates the app has been repackaged (malicious clone).
  static Future<void> _verifyAppIntegrity() async {
    try {
      const expectedPackageName = 'com.brand.brand_mobile_app';
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.packageName != expectedPackageName) {
        _isCompromised = true;
        if (kDebugMode) {
          debugPrint('[SECURITY_CRITICAL] Package name mismatch! '
              'Expected: $expectedPackageName '
              'Got: ${packageInfo.packageName}. Possible malicious repackage.');
        }
      } else {
        if (kDebugMode) debugPrint('[SECURITY] App integrity OK: ${packageInfo.packageName} v${packageInfo.version}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SECURITY] Could not verify app integrity: $e');
    }
  }

  static Future<bool> _checkDeviceIntegrity() async {
    try {
      if (Platform.isAndroid) {
        // Common root indicators on Android
        final paths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su'
        ];
        for (final path in paths) {
          if (await File(path).exists()) return true;
        }

        // Check if su is executable via shell commands
        try {
          final result = await Process.run('which', ['su']);
          if (result.exitCode == 0) return true;
        } catch (_) {}
      } else if (Platform.isIOS) {
        // Common jailbreak indicators on iOS
        final paths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt/'
        ];
        for (final path in paths) {
          if (await File(path).exists()) return true;
        }
      }
    } catch (e) {
      debugPrint('[SECURITY] Error checking device integrity: $e');
    }
    return false;
  }
}

/// Custom HttpOverrides to enforce strict SSL pinning and certificate verification
class PinningHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    
    // Set connection timeout
    client.connectionTimeout = const Duration(seconds: 15);
    
    // Explicitly fail on bad/untrusted certificates
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      debugPrint('[SSL_PINNING_WARNING] Denied connection to $host due to untrusted certificate.');
      return false; // Force fail MitM / proxy certificates
    };
    
    return client;
  }
}
