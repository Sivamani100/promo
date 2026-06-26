import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/input_sanitizer.dart';

class AgreementService {
  final SupabaseClient _client = SupabaseService.client;

  Map<String, dynamic> _sanitizeAgreementData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('total_budget') && sanitized['total_budget'] is String) {
      sanitized['total_budget'] = InputSanitizer.sanitizeBudget(sanitized['total_budget'] as String);
    }
    return sanitized;
  }

  Future<Map<String, dynamic>?> getAgreement(String id) async {
    final data = await _client
        .from('collaboration_agreements')
        .select('*, brand:profiles!brand_id_fkey(*), influencer:profiles!influencer_id_fkey(*), card:cards(*)')
        .eq('id', id)
        .maybeSingle();
    return data;
  }

  Future<List<Map<String, dynamic>>> getAgreementsForRoom(String roomId) async {
    final data = await _client
        .from('collaboration_agreements')
        .select('*, brand:profiles!brand_id_fkey(*), influencer:profiles!influencer_id_fkey(*)')
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> getActiveAgreementForRoom(String roomId) async {
    final list = await getAgreementsForRoom(roomId);
    if (list.isEmpty) return null;
    return list.first; // return latest agreement
  }

  Future<Map<String, dynamic>> createAgreement({
    required String roomId,
    required String cardId,
    required String brandId,
    required String influencerId,
    required List<dynamic> deliverables,
    required String totalBudget,
    required String paymentTerms,
    int timelineDays = 30,
    int revisionRounds = 2,
    required String usageRights,
    int exclusivityDays = 0,
  }) async {
    final data = {
      'room_id': roomId,
      'card_id': cardId,
      'brand_id': brandId,
      'influencer_id': influencerId,
      'deliverables': deliverables,
      'total_budget': totalBudget,
      'payment_terms': paymentTerms,
      'timeline_days': timelineDays,
      'revision_rounds': revisionRounds,
      'usage_rights': usageRights,
      'exclusivity_days': exclusivityDays,
      'status': 'sent_to_influencer',
      'brand_accepted_at': DateTime.now().toIso8601String(),
    };

    final sanitized = _sanitizeAgreementData(data);
    final response = await _client
        .from('collaboration_agreements')
        .insert(sanitized)
        .select()
        .single();
    return response;
  }

  Future<void> updateAgreementStatus(String id, String status) async {
    await _client.from('collaboration_agreements').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> acceptAgreement(String id, String userId, String role) async {
    final timestamp = DateTime.now().toIso8601String();
    final Map<String, dynamic> updates = {};

    if (role == 'brand') {
      updates['brand_accepted_at'] = timestamp;
    } else if (role == 'influencer') {
      updates['influencer_accepted_at'] = timestamp;
    }

    // Load agreement to check both side states
    final agreement = await _client
        .from('collaboration_agreements')
        .select('brand_accepted_at, influencer_accepted_at')
        .eq('id', id)
        .single();

    final bAccepted = agreement['brand_accepted_at'] != null || role == 'brand';
    final iAccepted = agreement['influencer_accepted_at'] != null || role == 'influencer';

    if (bAccepted && iAccepted) {
      updates['status'] = 'both_accepted';
    } else {
      updates['status'] = 'negotiating';
    }
    updates['updated_at'] = timestamp;

    await _client.from('collaboration_agreements').update(updates).eq('id', id);
  }

  Future<void> proposeChanges(String id) async {
    await _client.from('collaboration_agreements').update({
      'status': 'negotiating',
      'brand_accepted_at': null,
      'influencer_accepted_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
