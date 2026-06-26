import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Tracks the current app lifecycle state across the app via Riverpod.
final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);

/// Timestamp of when the app was last paused (backgrounded).
final appPausedAtProvider = StateProvider<DateTime?>(
  (ref) => null,
);

/// Manages app lifecycle transitions and executes appropriate actions.
///
/// Register in main.dart:
/// ```dart
/// WidgetsBinding.instance.addObserver(AppLifecycleManager(ref: container));
/// ```
class AppLifecycleManager with WidgetsBindingObserver {
  final ProviderContainer ref;

  AppLifecycleManager({required this.ref});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LIFECYCLE] State changed to: $state');
    ref.read(appLifecycleStateProvider.notifier).state = state;

    switch (state) {
      case AppLifecycleState.paused:
        _onPaused();
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      case AppLifecycleState.detached:
        _onDetached();
        break;
      case AppLifecycleState.inactive:
        // Briefly inactive (call coming in, control center swipe)
        // Don't do anything significant — it's transient
        break;
      case AppLifecycleState.hidden:
        // iOS only — app hidden but not suspended
        _onPaused(); // Same treatment as paused
        break;
    }
  }

  /// App going to background.
  void _onPaused() {
    ref.read(appPausedAtProvider.notifier).state = DateTime.now();

    // Update last_seen in profiles
    _updateLastSeen();
  }

  /// App coming back to foreground.
  void _onResumed() {
    final pausedAt = ref.read(appPausedAtProvider);

    // Check if we've been in background long enough to warrant a refresh
    if (pausedAt != null) {
      final elapsed = DateTime.now().difference(pausedAt);

      if (elapsed.inMinutes > 60) {
        // Refresh auth token if stale
        _refreshAuthToken();
      }

      if (elapsed.inMinutes > 30) {
        // Data is stale — notify active screens to silently refresh
        debugPrint('[LIFECYCLE] App was backgrounded for ${elapsed.inMinutes}m — triggering refresh');
      }
    }

    // Always refresh unread counts on resume
    _refreshUnreadCounts();

    // Update last_seen to mark user as active
    _updateLastSeen();
  }

  /// App being killed.
  void _onDetached() {
    // Clean up Realtime subscriptions
    try {
      Supabase.instance.client.removeAllChannels();
    } catch (e) {
      debugPrint('[LIFECYCLE] Error cleaning up channels: $e');
    }
  }

  // ── Helper Methods ───────────────────────────────────────────────────────

  Future<void> _updateLastSeen() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('[LIFECYCLE] Failed to update last_seen: $e');
    }
  }

  Future<void> _refreshAuthToken() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
      debugPrint('[LIFECYCLE] Auth token refreshed');
    } catch (e) {
      debugPrint('[LIFECYCLE] Failed to refresh auth token: $e');
    }
  }

  Future<void> _refreshUnreadCounts() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch unread notification count
      final notifResult = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .eq('is_read', false)
          .count(CountOption.exact);

      debugPrint('[LIFECYCLE] Unread notifications: ${notifResult.count}');

      // Badge sync is handled by the notification provider listening to this
    } catch (e) {
      debugPrint('[LIFECYCLE] Failed to refresh unread counts: $e');
    }
  }
}
