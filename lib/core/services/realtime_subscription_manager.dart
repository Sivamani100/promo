import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeSubscriptionManager {
  RealtimeSubscriptionManager._();

  static const int _maxActiveSubscriptions = 2;
  static final Map<String, RealtimeChannel> _active = {};
  static final List<String> _order = [];

  /// Subscribes to a channel and manages the total number of active connections.
  /// If the active connections exceed [_maxActiveSubscriptions], the oldest active
  /// channel is automatically unsubscribed (paused) to preserve battery.
  static Future<void> subscribe(String key, RealtimeChannel channel) async {
    if (_active.containsKey(key)) {
      // Already subscribed, just move to the end of the order (most recently used)
      _order.remove(key);
      _order.add(key);
      return;
    }

    if (_active.length >= _maxActiveSubscriptions) {
      final oldestKey = _order.first;
      final oldestChannel = _active[oldestKey];
      if (oldestChannel != null) {
        debugPrint('[REALTIME_MGR] Pausing oldest channel: $oldestKey');
        try {
          await oldestChannel.unsubscribe();
        } catch (e) {
          debugPrint('[REALTIME_MGR] Error unsubscribing channel $oldestKey: $e');
        }
      }
      _active.remove(oldestKey);
      _order.removeAt(0);
    }

    debugPrint('[REALTIME_MGR] Subscribing to channel: $key');
    try {
      await channel.subscribe();
      _active[key] = channel;
      _order.add(key);
    } catch (e) {
      debugPrint('[REALTIME_MGR] Error subscribing to channel $key: $e');
    }
  }

  /// Unsubscribes from the channel associated with the given key.
  static Future<void> unsubscribe(String key) async {
    if (_active.containsKey(key)) {
      final channel = _active[key];
      if (channel != null) {
        debugPrint('[REALTIME_MGR] Unsubscribing channel: $key');
        try {
          await channel.unsubscribe();
        } catch (e) {
          debugPrint('[REALTIME_MGR] Error unsubscribing channel $key: $e');
        }
      }
      _active.remove(key);
      _order.remove(key);
    }
  }

  /// Cleans up all active subscriptions.
  static Future<void> clearAll() async {
    debugPrint('[REALTIME_MGR] Clearing all subscriptions');
    for (final channel in _active.values) {
      try {
        await channel.unsubscribe();
      } catch (e) {
        debugPrint('[REALTIME_MGR] Error clearing channel: $e');
      }
    }
    _active.clear();
    _order.clear();
  }
}
