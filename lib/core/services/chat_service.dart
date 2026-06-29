import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/input_sanitizer.dart';

class ChatService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getRooms(String userId, String role) async {
    if (role == 'brand') {
      final data = await _client
          .from('rooms')
          .select('*, brand:profiles!rooms_brand_id_fkey(*), influencer:profiles!rooms_influencer_id_fkey(*), card:cards!rooms_card_id_fkey(title)')
          .eq('brand_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } else if (role == 'admin') {
      final data = await _client
          .from('rooms')
          .select('*, brand:profiles!rooms_brand_id_fkey(*), influencer:profiles!rooms_influencer_id_fkey(*), card:cards!rooms_card_id_fkey(title)')
          .or('brand_id.eq.$userId,influencer_id.eq.$userId')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } else {
      // Fetch 1-to-1 rooms
      final rooms1to1 = await _client
          .from('rooms')
          .select('*, brand:profiles!rooms_brand_id_fkey(*), influencer:profiles!rooms_influencer_id_fkey(*), card:cards!rooms_card_id_fkey(title)')
          .eq('influencer_id', userId);

      // Fetch group rooms where the user is invited or joined
      List<Map<String, dynamic>> groupRooms = [];
      try {
        final membersData = await _client
            .from('group_members')
            .select('room_id, status, role')
            .eq('user_id', userId)
            .inFilter('status', ['joined', 'pending_invite']);
        
        final roomIds = List<Map<String, dynamic>>.from(membersData)
            .map((m) => m['room_id'] as String)
            .toList();

        if (roomIds.isNotEmpty) {
          final groupData = await _client
              .from('rooms')
              .select('*, brand:profiles!rooms_brand_id_fkey(*), influencer:profiles!rooms_influencer_id_fkey(*), card:cards!rooms_card_id_fkey(title)')
              .inFilter('id', roomIds);
          
          final fetchedGroups = List<Map<String, dynamic>>.from(groupData);
          for (var room in fetchedGroups) {
            final mem = List<Map<String, dynamic>>.from(membersData)
                .firstWhere((m) => m['room_id'] == room['id']);
            room['membership_status'] = mem['status'];
            room['membership_role'] = mem['role'];
            groupRooms.add(room);
          }
        }
      } catch (e) {
        print('Error fetching group rooms: $e');
      }

      final allRooms = [...List<Map<String, dynamic>>.from(rooms1to1), ...groupRooms];
      allRooms.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return allRooms;
    }
  }

  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    return await _client
        .from('rooms')
        .select('*, brand:profiles!rooms_brand_id_fkey(*), influencer:profiles!rooms_influencer_id_fkey(*), card:cards!rooms_card_id_fkey(title)')
        .eq('id', roomId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getMessages(String roomId, {int limit = 50}) async {
    final data = await _client
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(display_name, avatar_url, is_verified)')
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    Map<String, dynamic>? payload,
  }) async {
    // HARDENING: sec-agent 2026-06-24
    final sanitizedContent = InputSanitizer.sanitizeText(content);
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': sanitizedContent,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'payload': payload,
    });
  }

  Future<void> markMessagesAsRead(String roomId, String userId) async {
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  Future<void> updateLastSeen(String userId) async {
    try {
      await _client.from('profiles').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  Future<DateTime?> getUserLastSeen(String userId) async {
    try {
      final res = await _client.from('profiles').select('last_seen').eq('id', userId).maybeSingle();
      if (res != null && res['last_seen'] != null) {
        return DateTime.tryParse(res['last_seen']);
      }
    } catch (e) {
      print('Error getting user last seen: $e');
    }
    return null;
  }

  RealtimeChannel subscribeToMessages(String roomId, void Function(Map<String, dynamic>) onMessage) {
    return _client
        .channel('room:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }

  Future<int> getUnreadMessageCount(String userId) async {
    final rooms = await _client.from('rooms').select('id').or('brand_id.eq.$userId,influencer_id.eq.$userId');
    final roomIds = List<Map<String, dynamic>>.from(rooms).map((r) => r['id'] as String).toList();
    if (roomIds.isEmpty) return 0;
    final result = await _client
        .from('messages')
        .select('id')
        .inFilter('room_id', roomIds)
        .neq('sender_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);
    return result.count;
  }

  Future<int> getUnreadCountForRoom(String roomId, String userId) async {
    try {
      final result = await _client
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return result.count;
    } catch (e) {
      print('Error getting unread count for room: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getLastMessage(String roomId) async {
    final data = await _client
        .from('messages')
        .select('content, created_at, sender_id')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data;
  }

  // Milestones
  Future<List<Map<String, dynamic>>> getMilestones(String roomId) async {
    final data = await _client
        .from('milestones')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    
    final list = List<Map<String, dynamic>>.from(data);
    for (var m in list) {
      if (m['status'] == 'done') {
        m['status'] = 'completed';
      }
    }
    return list;
  }

  Future<void> createMilestone(Map<String, dynamic> data) async {
    // HARDENING: sec-agent 2026-06-24
    final Map<String, dynamic> dbData = Map.from(data);
    if (dbData['status'] == 'completed') {
      dbData['status'] = 'done';
    }
    if (dbData.containsKey('title') && dbData['title'] is String) {
      dbData['title'] = InputSanitizer.sanitizeName(dbData['title'] as String, maxLength: 100);
    }
    await _client.from('milestones').insert(dbData);
  }

  Future<void> updateMilestoneStatus(String milestoneId, String status) async {
    final dbStatus = status == 'completed' ? 'done' : status;
    await _client.from('milestones').update({
      'status': dbStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', milestoneId);
  }

  Future<void> updateMilestoneTitle(String milestoneId, String title) async {
    // HARDENING: sec-agent 2026-06-24
    final sanitizedTitle = InputSanitizer.sanitizeName(title, maxLength: 100);
    await _client.from('milestones').update({
      'title': sanitizedTitle,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', milestoneId);
  }

  Future<void> updateMilestoneDueDate(String milestoneId, String? dueDate) async {
    await _client.from('milestones').update({
      'due_date': dueDate,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', milestoneId);
  }

  Future<Map<String, dynamic>> getOrCreate1to1Room({required String brandId, required String influencerId, String? cardId}) async {
    // 1. Check if ANY 1-to-1 room exists between this brand and influencer
    final existingRoom = await _client
        .from('rooms')
        .select()
        .eq('brand_id', brandId)
        .eq('influencer_id', influencerId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
        
    if (existingRoom != null) {
      return existingRoom;
    }

    // 2. If none exists, find any accepted application to auto-link
    String? linkedAppId;
    String? linkedCardId = cardId;

    try {
      // Fetch all accepted applications for this influencer
      final appsData = await _client
          .from('applications')
          .select('id, card_id')
          .eq('influencer_id', influencerId)
          .eq('status', 'accepted');
      
      // Fetch all cards belonging to this brand
      final brandCardsData = await _client
          .from('cards')
          .select('id')
          .eq('brand_id', brandId);

      final brandCardIds = List<Map<String, dynamic>>.from(brandCardsData)
          .map((c) => c['id'] as String)
          .toList();
      
      final apps = List<Map<String, dynamic>>.from(appsData);
      Map<String, dynamic>? matchingApp;
      
      if (cardId != null) {
        // If a specific cardId was requested, prioritize that one
        for (final app in apps) {
          if (app['card_id'] == cardId) {
            matchingApp = app;
            break;
          }
        }
      }
      
      // Fallback to any matching card if no specific matchingApp was found yet
      if (matchingApp == null) {
        for (final app in apps) {
          if (brandCardIds.contains(app['card_id'] as String)) {
            matchingApp = app;
            break;
          }
        }
      }

      if (matchingApp != null) {
        linkedAppId = matchingApp['id'] as String?;
        linkedCardId = matchingApp['card_id'] as String?;
      }
    } catch (e) {
      print('Error finding application to link: $e');
    }

    final data = await _client.from('rooms').insert({
      'brand_id': brandId,
      'influencer_id': influencerId,
      'card_id': linkedCardId,
      'application_id': linkedAppId,
      'status': 'active',
      'is_active': true,
    }).select().single();
    return data;
  }

  Future<Map<String, dynamic>> createGroupRoom(String brandId, String cardId) async {
    final existing = await _client
        .from('rooms')
        .select()
        .eq('card_id', cardId)
        .isFilter('influencer_id', null)
        .maybeSingle();

    if (existing != null) {
      return existing;
    }

    final data = await _client.from('rooms').insert({
      'brand_id': brandId,
      'card_id': cardId,
      'influencer_id': null,
      'status': 'group_all',
      'is_active': true,
    }).select().single();

    return data;
  }

  Future<void> updateGroupPermissions(String roomId, String status) async {
    await _client.from('rooms').update({
      'status': status,
    }).eq('id', roomId);
  }

  Future<void> addReaction(String messageId, String userId, String emoji, Map<String, dynamic> existingPayload) async {
    final payload = Map<String, dynamic>.from(existingPayload);
    final Map<String, dynamic> reactions = Map<String, dynamic>.from(payload['reactions'] ?? {});
    reactions[userId] = emoji;
    payload['reactions'] = reactions;

    await _client.from('messages').update({
      'payload': payload,
    }).eq('id', messageId);
  }

  Future<void> editMessage(String messageId, String newContent, Map<String, dynamic> existingPayload) async {
    final payload = Map<String, dynamic>.from(existingPayload);
    payload['is_edited'] = true;
    payload['edited_at'] = DateTime.now().toUtc().toIso8601String();

    await _client.from('messages').update({
      'content': newContent,
      'payload': payload,
    }).eq('id', messageId);
  }

  Future<void> starMessage(String messageId, String userId, Map<String, dynamic> existingPayload, bool isStarred) async {
    final payload = Map<String, dynamic>.from(existingPayload);
    final List<dynamic> starredBy = List<dynamic>.from(payload['starred_by'] ?? []);
    if (isStarred) {
      if (!starredBy.contains(userId)) {
        starredBy.add(userId);
      }
    } else {
      starredBy.remove(userId);
    }
    payload['starred_by'] = starredBy;

    await _client.from('messages').update({
      'payload': payload,
    }).eq('id', messageId);
  }

  Future<void> deleteMessageForEveryone(String messageId, Map<String, dynamic> existingPayload) async {
    final payload = Map<String, dynamic>.from(existingPayload);
    payload['deleted_everyone'] = true;

    await _client.from('messages').update({
      'content': 'This message was deleted',
      'attachment_url': null,
      'attachment_type': null,
      'payload': payload,
    }).eq('id', messageId);
  }

  Future<void> deleteMessageForMe(String messageId, String userId, Map<String, dynamic> existingPayload) async {
    final payload = Map<String, dynamic>.from(existingPayload);
    final List<dynamic> deletedFor = List<dynamic>.from(payload['deleted_for'] ?? []);
    if (!deletedFor.contains(userId)) {
      deletedFor.add(userId);
    }
    payload['deleted_for'] = deletedFor;

    await _client.from('messages').update({
      'payload': payload,
    }).eq('id', messageId);
  }

  Future<void> pinMessage(String messageId, Map<String, dynamic> existingPayload, bool isPinned) async {
    final payload = Map<String, dynamic>.from(existingPayload);
    payload['is_pinned'] = isPinned;

    await _client.from('messages').update({
      'payload': payload,
    }).eq('id', messageId);
  }

  Future<void> forwardMessage({
    required String targetRoomId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? forwardedFrom,
  }) async {
    final Map<String, dynamic> payload = {};
    if (forwardedFrom != null) {
      payload['forwarded_from'] = forwardedFrom;
    }
    await sendMessage(
      roomId: targetRoomId,
      senderId: senderId,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      payload: payload,
    );
  }

  Future<List<Map<String, dynamic>>> getGroupParticipants(String cardId) async {
    final data = await _client
        .from('applications')
        .select('*, influencer:profiles!applications_influencer_id_fkey(*)')
        .eq('card_id', cardId)
        .eq('status', 'accepted');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String roomId) async {
    try {
      final data = await _client
          .from('group_members')
          .select('*, profiles(*)')
          .eq('room_id', roomId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching group members: $e');
      return [];
    }
  }

  Future<void> inviteUserToGroup(String roomId, String userId, {String role = 'member'}) async {
    await _client.from('group_members').insert({
      'room_id': roomId,
      'user_id': userId,
      'role': role,
      'status': 'pending_invite',
    });
  }

  Future<void> respondToGroupInvite(String roomId, String userId, bool accept) async {
    if (accept) {
      await _client
          .from('group_members')
          .update({'status': 'joined'})
          .eq('room_id', roomId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('group_members')
          .update({'status': 'rejected_invite'})
          .eq('room_id', roomId)
          .eq('user_id', userId);
    }
  }

  Future<void> requestToJoinGroup(String roomId, String userId) async {
    await _client.from('group_members').insert({
      'room_id': roomId,
      'user_id': userId,
      'role': 'member',
      'status': 'requested_join',
    });
  }

  Future<void> respondToJoinRequest(String roomId, String userId, bool approve) async {
    if (approve) {
      await _client
          .from('group_members')
          .update({'status': 'joined'})
          .eq('room_id', roomId)
          .eq('user_id', userId);
    } else {
      await _client
          .from('group_members')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);
    }
  }

  Future<void> updateMemberRole(String roomId, String userId, String role) async {
    await _client
        .from('group_members')
        .update({'role': role})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> muteMember(String roomId, String userId, DateTime? until) async {
    await _client
        .from('group_members')
        .update({'muted_until': until?.toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> banMember(String roomId, String userId) async {
    await _client
        .from('group_members')
        .update({'status': 'banned'})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> removeMember(String roomId, String userId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> markGroupMessageAsRead(String messageId, String userId, Map<String, dynamic> existingPayload) async {
    await _client.rpc('append_message_seen_by', params: {
      'message_uuid': messageId,
      'user_uuid': userId,
    });
  }

  Future<Map<String, dynamic>> createCustomGroupRoom({
    required String brandId,
    required String title,
    String? description,
    String? cardId,
    List<String> inviteUserIds = const [],
  }) async {
    // HARDENING: sec-agent 2026-06-24
    final sanitizedTitle = InputSanitizer.sanitizeName(title, maxLength: 100);
    final sanitizedDescription = description != null ? InputSanitizer.sanitizeText(description) : null;
    final data = await _client.from('rooms').insert({
      'brand_id': brandId,
      'influencer_id': null,
      'card_id': cardId,
      'title': sanitizedTitle,
      'description': sanitizedDescription,
      'status': 'group_all',
      'is_active': true,
    }).select().single();

    final roomId = data['id'] as String;

    for (final uid in inviteUserIds) {
      try {
        await inviteUserToGroup(roomId, uid);
      } catch (e) {
        print('Error inviting user $uid to group $roomId: $e');
      }
    }

    return data;
  }
}

// ========== Milestone Extensions Classes ==========
class MilestoneExtension {
  final DateTime newDueDate;
  final String status; // 'pending', 'approved', 'rejected'
  final String reason;

  MilestoneExtension({
    required this.newDueDate,
    required this.status,
    required this.reason,
  });

  String toFormatString() {
    return '[EXT:${newDueDate.toIso8601String()}|$status|$reason]';
  }

  factory MilestoneExtension.parse(String text) {
    final reg = RegExp(r'\[EXT:([^|]+)\|([^|]+)\|([^\]]*)\]');
    final match = reg.firstMatch(text);
    if (match == null) throw const FormatException('Invalid extension format');
    return MilestoneExtension(
      newDueDate: DateTime.parse(match.group(1)!),
      status: match.group(2)!,
      reason: match.group(3)!,
    );
  }
}

class MilestoneHelper {
  static String getDisplayTitle(String rawTitle) {
    final idx = rawTitle.indexOf(' [EXT:');
    if (idx == -1) return rawTitle;
    return rawTitle.substring(0, idx);
  }

  static MilestoneExtension? getExtension(String rawTitle) {
    final idx = rawTitle.indexOf(' [EXT:');
    if (idx == -1) return null;
    try {
      return MilestoneExtension.parse(rawTitle.substring(idx + 1));
    } catch (_) {
      return null;
    }
  }

  static String buildRawTitle(String displayTitle, MilestoneExtension? ext) {
    if (ext == null) return displayTitle;
    return '$displayTitle ${ext.toFormatString()}';
  }
}