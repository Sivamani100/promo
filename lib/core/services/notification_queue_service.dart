import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NotificationQueueService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Check if the current time falls inside the user's DND window.
  static bool isInsideDNDWindow(Map<String, dynamic>? preferences) {
    if (preferences == null) return false;
    final enabled = preferences['dnd_enabled'] as bool? ?? false;
    if (!enabled) return false;

    final startStr = preferences['dnd_start'] as String? ?? '22:00';
    final endStr = preferences['dnd_end'] as String? ?? '08:00';

    try {
      final now = DateTime.now();
      final startParts = startStr.split(':').map(int.parse).toList();
      final endParts = endStr.split(':').map(int.parse).toList();

      final start = DateTime(now.year, now.month, now.day, startParts[0], startParts[1]);
      var end = DateTime(now.year, now.month, now.day, endParts[0], endParts[1]);

      if (end.isBefore(start)) {
        // spans midnight (e.g., 22:00 to 08:00)
        if (now.isAfter(start) || now.isBefore(end)) {
          return true;
        }
      } else {
        // same day (e.g., 09:00 to 17:00)
        if (now.isAfter(start) && now.isBefore(end)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Sends or queues a notification based on user DND settings.
  static Future<void> sendOrQueue({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    try {
      final profileResult = await _client
          .from('profiles')
          .select('preferences')
          .eq('id', userId)
          .maybeSingle();

      final prefs = profileResult?['preferences'] as Map<String, dynamic>?;

      if (isInsideDNDWindow(prefs)) {
        await _client.from('notification_queue').insert({
          'user_id': userId,
          'type': type,
          'payload': {
            'title': title,
            'body': body,
            if (referenceId != null) 'reference_id': referenceId,
          },
          'scheduled_for': DateTime.now().toIso8601String(),
        });
        print('[NOTIFICATION_QUEUE] Queued notification for $userId due to DND');
      } else {
        await insertWithBatching(userId, type, title, body, referenceId);
      }
    } catch (e) {
      print('[NOTIFICATION_QUEUE] Error sending/queuing: $e');
    }
  }

  /// Insert notification with grouping/batching logic.
  static Future<void> insertWithBatching(
    String userId,
    String type,
    String title,
    String body,
    String? referenceId,
  ) async {
    try {
      final existingQuery = _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('type', type)
          .eq('is_read', false);

      final existing = await (referenceId != null 
          ? existingQuery.eq('reference_id', referenceId)
          : existingQuery
      ).maybeSingle();

      if (existing != null) {
        final existingId = existing['id'];
        final existingCount = existing['group_count'] as int? ?? 1;
        
        String newTitle = title;
        String newBody = body;
        
        if (type == 'new_message') {
          newTitle = 'New Messages';
          newBody = 'You have multiple unread messages in this chat.';
        } else if (type == 'profile_view') {
          final count = existingCount + 1;
          newTitle = 'Profile Views';
          newBody = '$count users have viewed your profile.';
        } else if (type == 'application_received') {
          final count = existingCount + 1;
          newTitle = 'Applications Received';
          newBody = 'You have received $count new applications.';
        }

        await _client.from('notifications').update({
          'title': newTitle,
          'body': newBody,
          'group_count': existingCount + 1,
          'created_at': DateTime.now().toIso8601String(),
        }).eq('id', existingId);
        print('[NOTIFICATION_QUEUE] Batched notification $existingId');
      } else {
        await _client.from('notifications').insert({
          'user_id': userId,
          'type': type,
          'title': title,
          'body': body,
          if (referenceId != null) 'reference_id': referenceId,
          'is_read': false,
          'group_count': 1,
        });
        print('[NOTIFICATION_QUEUE] Sent notification to $userId');
      }
    } catch (e) {
      print('[NOTIFICATION_QUEUE] Error during insert/batching: $e');
    }
  }

  /// Process/Flush the queue when DND is off.
  static Future<void> processQueue(String userId) async {
    try {
      final profileResult = await _client
          .from('profiles')
          .select('preferences')
          .eq('id', userId)
          .maybeSingle();

      final prefs = profileResult?['preferences'] as Map<String, dynamic>?;

      if (isInsideDNDWindow(prefs)) {
        print('[NOTIFICATION_QUEUE] Cannot process queue: DND is active');
        return;
      }

      final queued = await _client
          .from('notification_queue')
          .select()
          .eq('user_id', userId)
          .isFilter('sent_at', null);

      if (queued.isEmpty) return;

      print('[NOTIFICATION_QUEUE] Processing ${queued.length} queued notifications');

      for (final item in queued) {
        final payload = item['payload'] as Map<String, dynamic>;
        final type = item['type'] as String;
        final title = payload['title'] as String;
        final body = payload['body'] as String;
        final refId = payload['reference_id'] as String?;

        await insertWithBatching(userId, type, title, body, refId);

        await _client
            .from('notification_queue')
            .update({'sent_at': DateTime.now().toIso8601String()})
            .eq('id', item['id']);
      }
    } catch (e) {
      print('[NOTIFICATION_QUEUE] Error processing queue: $e');
    }
  }
}
