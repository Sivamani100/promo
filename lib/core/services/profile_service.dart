import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

import '../utils/input_sanitizer.dart';
import '../cache/app_cache.dart';

class ProfileService {
  final SupabaseClient _client = SupabaseService.client;

  Map<String, dynamic> _sanitizeProfileData(Map<String, dynamic> data) {
    // HARDENING: sec-agent 2026-06-24
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('display_name') && sanitized['display_name'] is String) {
      sanitized['display_name'] = InputSanitizer.sanitizeName(sanitized['display_name'] as String, maxLength: 50);
    }
    if (sanitized.containsKey('company_name') && sanitized['company_name'] is String) {
      sanitized['company_name'] = InputSanitizer.sanitizeName(sanitized['company_name'] as String, maxLength: 50);
    }
    if (sanitized.containsKey('location') && sanitized['location'] is String) {
      sanitized['location'] = InputSanitizer.sanitizeName(sanitized['location'] as String, maxLength: 100);
    }
    if (sanitized.containsKey('bio') && sanitized['bio'] is String) {
      sanitized['bio'] = InputSanitizer.sanitizeText(sanitized['bio'] as String, maxLength: 1000);
    }
    if (sanitized.containsKey('website_url') && sanitized['website_url'] is String) {
      final url = sanitized['website_url'] as String;
      if (!InputSanitizer.isValidUrl(url)) {
        sanitized.remove('website_url'); // Do not save invalid URL
      }
    }
    if (sanitized.containsKey('follower_count')) {
      if (sanitized['follower_count'] is int) {
        sanitized['follower_count'] = InputSanitizer.clampFollowerCount(sanitized['follower_count'] as int);
      } else if (sanitized['follower_count'] is String) {
        final count = int.tryParse(sanitized['follower_count'] as String) ?? 0;
        sanitized['follower_count'] = InputSanitizer.clampFollowerCount(count);
      }
    }
    return sanitized;
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    // HARDENING: devops-agent 2026-06-24
    final cacheKey = 'profile_$userId';
    final cached = AppCache().get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    final profile = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (profile != null) {
      AppCache().set(cacheKey, profile, ttl: const Duration(minutes: 5));
    }
    return profile;
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    final sanitized = _sanitizeProfileData(data);
    sanitized['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('profiles').update(sanitized).eq('id', userId);
    // HARDENING: devops-agent 2026-06-24
    AppCache().invalidate('profile_$userId');
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
    if (niche != null) query = query.contains('niche', [niche]);
    if (platform != null) query = query.contains('platforms', [platform]);
    if (minFollowers != null) query = query.gte('follower_count', minFollowers);
    if (maxFollowers != null) query = query.lte('follower_count', maxFollowers);

    final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data);
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