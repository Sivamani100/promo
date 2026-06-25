import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

import '../utils/input_sanitizer.dart';

class ApplicationService {
  final SupabaseClient _client = SupabaseService.client;

  Map<String, dynamic> _sanitizeApplicationData(Map<String, dynamic> data) {
    // HARDENING: sec-agent 2026-06-24
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('pitch_message') && sanitized['pitch_message'] is String) {
      sanitized['pitch_message'] = InputSanitizer.sanitizeText(sanitized['pitch_message'] as String);
    }
    if (sanitized.containsKey('brand_note') && sanitized['brand_note'] is String) {
      sanitized['brand_note'] = InputSanitizer.sanitizeText(sanitized['brand_note'] as String);
    }
    if (sanitized.containsKey('proposed_rate') && sanitized['proposed_rate'] is String) {
      sanitized['proposed_rate'] = InputSanitizer.sanitizeBudget(sanitized['proposed_rate'] as String);
    }
    return sanitized;
  }

  Future<List<Map<String, dynamic>>> getApplicationsForBrand(String brandId) async {
    final data = await _client
        .from('applications')
        .select('*, card:cards!inner(*, brand:profiles!cards_brand_id_fkey(*)), influencer:profiles!applications_influencer_id_fkey(*)')
        .eq('cards.brand_id', brandId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getApplicationsForInfluencer(String influencerId) async {
    final data = await _client
        .from('applications')
        .select('*, card:cards!applications_card_id_fkey(*, brand:profiles!cards_brand_id_fkey(*))')
        .eq('influencer_id', influencerId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createApplication(Map<String, dynamic> appData) async {
    final sanitized = _sanitizeApplicationData(appData);
    await _client.from('applications').insert(sanitized);
  }

  Future<void> updateApplication(String applicationId, Map<String, dynamic> appData) async {
    final sanitized = _sanitizeApplicationData(appData);
    await _client.from('applications').update(sanitized).eq('id', applicationId);
  }

  Future<Map<String, dynamic>?> getApplicationForCardAndInfluencer(String cardId, String influencerId) async {
    final data = await _client
        .from('applications')
        .select('*')
        .eq('card_id', cardId)
        .eq('influencer_id', influencerId)
        .maybeSingle();
    return data;
  }

  Future<void> updateApplicationStatus(String applicationId, String status, {String? brandNote}) async {
    final data = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (brandNote != null) data['brand_note'] = brandNote;
    final sanitized = _sanitizeApplicationData(data);
    await _client.from('applications').update(sanitized).eq('id', applicationId);
  }

  Future<List<String>> getAppliedCardIds(String influencerId) async {
    final data = await _client
        .from('applications')
        .select('card_id')
        .eq('influencer_id', influencerId);
    return List<Map<String, dynamic>>.from(data).map((e) => e['card_id'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getApplicationsForCard(String cardId) async {
    final data = await _client
        .from('applications')
        .select('*, influencer:profiles!applications_influencer_id_fkey(*)')
        .eq('card_id', cardId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> getApplicationCountForBrand(String brandId) async {
    final result = await _client
        .from('applications')
        .select('*, cards!inner(*)')
        .eq('cards.brand_id', brandId)
        .count(CountOption.exact);
    return result.count;
  }
}