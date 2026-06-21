import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ApplicationService {
  final SupabaseClient _client = SupabaseService.client;

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
    await _client.from('applications').insert(appData);
  }

  Future<void> updateApplication(String applicationId, Map<String, dynamic> appData) async {
    await _client.from('applications').update(appData).eq('id', applicationId);
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
    await _client.from('applications').update(data).eq('id', applicationId);
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