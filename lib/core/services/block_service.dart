// HARDENING-V2: trust-agent 2026-06-26
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for managing user blocks (hide profiles, cards, prevent messaging).
class BlockService {
  final SupabaseClient _client = SupabaseService.client;

  /// Block a user. Returns true if successful, false if already blocked.
  Future<bool> blockUser(String blockerId, String blockedId) async {
    if (blockerId == blockedId) return false;
    try {
      await _client.from('user_blocks').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      return true;
    } on PostgrestException catch (e) {
      // Unique constraint violation means already blocked
      if (e.code == '23505') return false;
      rethrow;
    }
  }

  /// Unblock a user.
  Future<void> unblockUser(String blockerId, String blockedId) async {
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  /// Check if userA has blocked userB.
  Future<bool> isBlocked(String blockerId, String blockedId) async {
    final data = await _client
        .from('user_blocks')
        .select('id')
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId)
        .maybeSingle();
    return data != null;
  }

  /// Check bidirectional block (either user blocked the other).
  Future<bool> isBlockedBidirectional(String userA, String userB) async {
    final data = await _client
        .from('user_blocks')
        .select('id')
        .or('and(blocker_id.eq.$userA,blocked_id.eq.$userB),and(blocker_id.eq.$userB,blocked_id.eq.$userA)')
        .maybeSingle();
    return data != null;
  }

  /// Get all users blocked by a given user.
  Future<List<Map<String, dynamic>>> getBlockedUsers(String userId) async {
    final data = await _client
        .from('user_blocks')
        .select('*, blocked:profiles!user_blocks_blocked_id_fkey(id, display_name, avatar_url, role)')
        .eq('blocker_id', userId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get the set of blocked user IDs for efficient filtering.
  Future<Set<String>> getBlockedIds(String userId) async {
    final data = await _client
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', userId);
    return List<Map<String, dynamic>>.from(data)
        .map((e) => e['blocked_id'] as String)
        .toSet();
  }

  /// Get the set of users who have blocked this user (for filtering).
  Future<Set<String>> getBlockedByIds(String userId) async {
    // This requires service-level access or a separate query strategy.
    // For now, we rely on the bidirectional check per-interaction.
    // In production, this would be handled via RLS filters on the database side.
    return {};
  }

  /// Get the set of all user IDs where either user blocked the other (bidirectional).
  Future<Set<String>> getAllBlockedUserIds(String userId) async {
    try {
      final data = await _client
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$userId,blocked_id.eq.$userId')
          .timeout(const Duration(seconds: 10));
      final set = <String>{};
      for (final row in List<Map<String, dynamic>>.from(data)) {
        set.add(row['blocker_id'] as String);
        set.add(row['blocked_id'] as String);
      }
      set.remove(userId);
      return set;
    } catch (e) {
      print('[BLOCK] Error getting all blocked user IDs: $e');
      return {};
    }
  }
}
