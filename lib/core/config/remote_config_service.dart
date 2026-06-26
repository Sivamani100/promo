// HARDENING-V2: admin-agent 2026-06-26
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Remote configuration service that loads feature flags and platform settings
/// from the `platform_config` table. Supports maintenance mode and force update.
class RemoteConfigService {
  RemoteConfigService._();

  static final Map<String, dynamic> _config = {};
  static bool _initialized = false;

  /// Load all config values from the database. Called once on app startup.
  static Future<void> initialize() async {
    try {
      final data = await SupabaseService.client
          .from('platform_config')
          .select('key, value')
          .timeout(const Duration(seconds: 5));
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final key = row['key'] as String;
        final value = row['value'];
        // Supabase stores JSONB — value could be a string, number, list, or map
        _config[key] = value;
      }
      _initialized = true;
      print('[CONFIG] Loaded ${_config.length} remote config values');
    } catch (e) {
      print('[CONFIG] Failed to load remote config: $e');
      // App continues with defaults — remote config is non-blocking
    }
  }

  /// Get a config value with a typed default fallback.
  static T get<T>(String key, T defaultValue) {
    if (!_config.containsKey(key)) return defaultValue;
    final raw = _config[key];
    if (raw is T) return raw;

    // Handle JSONB string → typed conversion
    if (raw is String) {
      try {
        if (T == bool) return (raw.toLowerCase() == 'true') as T;
        if (T == int) return int.parse(raw) as T;
        if (T == double) return double.parse(raw) as T;
        if (T == String) return raw as T;
        // For complex types (List, Map), try JSON decode
        final decoded = jsonDecode(raw);
        if (decoded is T) return decoded;
      } catch (_) {
        // Fall through to default
      }
    }
    if (raw is num) {
      if (T == int) return raw.toInt() as T;
      if (T == double) return raw.toDouble() as T;
    }

    return defaultValue;
  }

  /// Check if the app is in maintenance mode.
  static bool get isMaintenanceMode {
    final val = _config['maintenance_mode'];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  /// Get the minimum required app version.
  static String get minAppVersion {
    final val = _config['min_app_version'];
    if (val is String) {
      // Strip surrounding quotes if stored as JSON string
      return val.replaceAll('"', '');
    }
    return '1.0.0';
  }

  /// Get the maximum number of cards a brand can create per day.
  static int get maxCardsPerBrandPerDay => get<int>('max_cards_per_brand_per_day', 10);

  /// Get the maximum applications an influencer can submit per day.
  static int get maxApplicationsPerInfluencerPerDay => get<int>('max_applications_per_influencer_per_day', 20);

  /// Get the auto-suspend report threshold.
  static int get autoSuspendReportThreshold => get<int>('auto_suspend_report_threshold', 5);

  /// Get max file upload size in MB.
  static int get maxFileUploadMb => get<int>('max_file_upload_mb', 10);

  /// Whether remote config has been loaded.
  static bool get isInitialized => _initialized;

  /// Reload config (useful for admin changes).
  static Future<void> reload() async {
    _config.clear();
    _initialized = false;
    await initialize();
  }
}
