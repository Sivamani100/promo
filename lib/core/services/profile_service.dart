import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ProfileService {
  final SupabaseClient _client = SupabaseService.client;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await _client.from('profiles').select().eq('id', userId).maybeSingle();
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('profiles').update(data).eq('id', userId);
  }

  Future<List<Map<String, dynamic>>> getInfluencers({
    String? niche,
    String? platform,
    int? minFollowers,
    int? maxFollowers,
    String? location,
    bool? isVerified,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client.from('profiles').select().eq('role', 'influencer').eq('is_active', true);
    if (isVerified == true) query = query.eq('is_verified', true);
    if (location != null) query = query.ilike('location', '%$location%');
    final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data);
    if (niche != null) {
      results = results.where((p) {
        final niches = p['niche'] as List<dynamic>?;
        return niches != null && niches.contains(niche);
      }).toList();
    }
    if (platform != null) {
      results = results.where((p) {
        final platforms = p['platforms'] as List<dynamic>?;
        return platforms != null && platforms.contains(platform);
      }).toList();
    }
    if (minFollowers != null) {
      results = results.where((p) => (p['follower_count'] ?? 0) >= minFollowers).toList();
    }
    if (maxFollowers != null) {
      results = results.where((p) => (p['follower_count'] ?? 0) <= maxFollowers).toList();
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getBrands({int limit = 20, int offset = 0}) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('role', 'brand')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> getProfileCompletenessPercent(Map<String, dynamic> profile) async {
    int score = 0;
    if (profile['avatar_url'] != null) score += 10;
    if (profile['bio'] != null && (profile['bio'] as String).length > 10) score += 10;
    if (profile['location'] != null) score += 15;
    if (profile['niche'] != null && (profile['niche'] as List).isNotEmpty) score += 10;
    if (profile['platforms'] != null && (profile['platforms'] as List).isNotEmpty) score += 20;
    if (profile['follower_count'] != null && profile['follower_count'] > 0) score += 15;
    // Check portfolio
    final userId = profile['id'];
    final portfolioCount = await _client
        .from('portfolio_items')
        .select('id')
        .eq('owner_id', userId)
        .count(CountOption.exact);
    if ((portfolioCount.count) >= 3) score += 20;
    return score;
  }
}