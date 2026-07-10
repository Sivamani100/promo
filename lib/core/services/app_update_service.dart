import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'supabase_service.dart';

class AppConfigState {
  final bool needsForceUpdate;
  final bool isInMaintenance;
  final bool isLoading;
  final String currentVersion;
  final String minRequiredVersion;

  const AppConfigState({
    this.needsForceUpdate = false,
    this.isInMaintenance = false,
    this.isLoading = true,
    this.currentVersion = '1.0.0',
    this.minRequiredVersion = '1.0.0',
  });

  AppConfigState copyWith({
    bool? needsForceUpdate,
    bool? isInMaintenance,
    bool? isLoading,
    String? currentVersion,
    String? minRequiredVersion,
  }) {
    return AppConfigState(
      needsForceUpdate: needsForceUpdate ?? this.needsForceUpdate,
      isInMaintenance: isInMaintenance ?? this.isInMaintenance,
      isLoading: isLoading ?? this.isLoading,
      currentVersion: currentVersion ?? this.currentVersion,
      minRequiredVersion: minRequiredVersion ?? this.minRequiredVersion,
    );
  }
}

class AppConfigNotifier extends StateNotifier<AppConfigState> {
  AppConfigNotifier() : super(const AppConfigState()) {
    check();
  }

  Future<void> check() async {
    state = state.copyWith(isLoading: true);
    try {
      // Fetch from platform_config — uses anon-accessible SELECT policy
      final res = await SupabaseService.client
          .from('platform_config')
          .select('key, value');

      bool isInMaintenance = false;
      String minVersion = '1.0.0';

      for (final row in res) {
        final key = row['key'] as String;
        final val = row['value']; // JSONB — can be bool, String, num, Map, etc.

        if (key == 'maintenance_mode') {
          // JSONB 'false' → Dart false | JSONB 'true' → Dart true
          if (val is bool) {
            isInMaintenance = val;
          } else {
            isInMaintenance = val.toString().toLowerCase() == 'true';
          }
        } else if (key == 'min_app_version') {
          // JSONB '"1.0.1"' → Dart '"1.0.1"' (with quotes) or '1.0.1'
          minVersion = val.toString().replaceAll('"', '').trim();
        }
      }

      // Fetch local package version
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version;
      final needsForceUpdate = _isVersionOlder(installedVersion, minVersion);

      state = AppConfigState(
        needsForceUpdate: needsForceUpdate,
        isInMaintenance: isInMaintenance,
        isLoading: false,
        currentVersion: installedVersion,
        minRequiredVersion: minVersion,
      );
    } catch (e) {
      // Graceful degradation: if config fetch fails (network / RLS), never block the user.
      debugPrint('[CONFIG_CHECK] Could not fetch platform config: $e');
      final version = state.currentVersion == '1.0.0'
          ? (await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
              appName: 'Promo',
              packageName: 'com.brand.promo',
              version: '1.0.0',
              buildNumber: '1',
            ))).version
          : state.currentVersion;
      state = state.copyWith(
        isLoading: false,
        needsForceUpdate: false,
        isInMaintenance: false,
        currentVersion: version,
      );
    }
  }

  bool _isVersionOlder(String current, String minimum) {
    final currentParts = current.split('+').first.split('.');
    final minimumParts = minimum.split('+').first.split('.');
    
    for (int i = 0; i < 3; i++) {
      final cur = i < currentParts.length ? (int.tryParse(currentParts[i]) ?? 0) : 0;
      final min = i < minimumParts.length ? (int.tryParse(minimumParts[i]) ?? 0) : 0;
      if (cur < min) return true;
      if (cur > min) return false;
    }
    return false;
  }
}

final appConfigCheckerProvider = StateNotifierProvider<AppConfigNotifier, AppConfigState>((ref) {
  return AppConfigNotifier();
});
