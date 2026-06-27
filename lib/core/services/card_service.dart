import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/input_sanitizer.dart';
import '../cache/app_cache.dart';

class CardService {
  final SupabaseClient _client = SupabaseService.client;

  Map<String, dynamic> _sanitizeCardData(Map<String, dynamic> data) {
    // HARDENING: sec-agent 2026-06-24
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('title') && sanitized['title'] is String) {
      sanitized['title'] = InputSanitizer.sanitizeName(sanitized['title'] as String, maxLength: 100);
    }
    if (sanitized.containsKey('description') && sanitized['description'] is String) {
      sanitized['description'] = InputSanitizer.sanitizeText(sanitized['description'] as String);
    }
    if (sanitized.containsKey('category') && sanitized['category'] is String) {
      sanitized['category'] = InputSanitizer.sanitizeName(sanitized['category'] as String, maxLength: 50);
    }
    if (sanitized.containsKey('budget_range') && sanitized['budget_range'] is String) {
      sanitized['budget_range'] = InputSanitizer.sanitizeBudget(sanitized['budget_range'] as String);
    }
    if (sanitized.containsKey('preferred_location') && sanitized['preferred_location'] is String) {
      sanitized['preferred_location'] = InputSanitizer.sanitizeName(sanitized['preferred_location'] as String, maxLength: 100);
    }
    if (sanitized.containsKey('languages') && sanitized['languages'] is List) {
      sanitized['languages'] = (sanitized['languages'] as List)
          .map((e) => InputSanitizer.sanitizeName(e.toString(), maxLength: 50))
          .toList();
    }
    return sanitized;
  }

  Future<List<Map<String, dynamic>>> getBrandCards(String brandId) async {
    // HARDENING: devops-agent 2026-06-24
    final cacheKey = 'brand_cards_$brandId';
    final cached = AppCache().get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('brand_id', brandId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      final result = List<Map<String, dynamic>>.from(data);
      AppCache().set(cacheKey, result, ttl: const Duration(minutes: 5));
      return result;
    } catch (e) {
      print('Error getting brand cards: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveCards({int limit = 50}) async {
    // HARDENING: devops-agent 2026-06-24
    final cacheKey = 'active_cards_$limit';
    final cached = AppCache().get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 15));
      final result = List<Map<String, dynamic>>.from(data);
      AppCache().set(cacheKey, result, ttl: const Duration(minutes: 5));
      return result;
    } catch (e) {
      print('Error getting active cards: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCardById(String cardId) async {
    // HARDENING: devops-agent 2026-06-24
    final cacheKey = 'card_$cardId';
    final cached = AppCache().get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    try {
      final card = await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('id', cardId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (card != null) {
        AppCache().set(cacheKey, card, ttl: const Duration(minutes: 5));
      }
      return card;
    } catch (e) {
      print('Error getting card by id: $e');
      return null;
    }
  }

  Future<void> createCard(Map<String, dynamic> cardData) async {
    try {
      final sanitized = _sanitizeCardData(cardData);
      await _client.from('cards').insert(sanitized).timeout(const Duration(seconds: 15));
      // HARDENING: devops-agent 2026-06-24
      final brandId = cardData['brand_id']?.toString();
      if (brandId != null) {
        AppCache().invalidate('brand_cards_$brandId');
      } else {
        AppCache().invalidatePattern('brand_cards_');
      }
      AppCache().invalidatePattern('active_cards_');
    } catch (e) {
      print('Error creating card: $e');
      rethrow;
    }
  }

  Future<void> updateCard(String cardId, Map<String, dynamic> data) async {
    final sanitized = _sanitizeCardData(data);
    sanitized['updated_at'] = DateTime.now().toIso8601String();
    try {
      await _client.from('cards').update(sanitized).eq('id', cardId).timeout(const Duration(seconds: 15));
      // HARDENING: devops-agent 2026-06-24
      AppCache().invalidate('card_$cardId');
      AppCache().invalidatePattern('brand_cards_');
      AppCache().invalidatePattern('active_cards_');
    } catch (e) {
      print('Error updating card: $e');
      rethrow;
    }
  }

  Future<void> deleteCard(String cardId) async {
    try {
      await _client.from('cards').delete().eq('id', cardId).timeout(const Duration(seconds: 15));
      // HARDENING: devops-agent 2026-06-24
      AppCache().invalidate('card_$cardId');
      AppCache().invalidatePattern('brand_cards_');
      AppCache().invalidatePattern('active_cards_');
    } catch (e) {
      print('Error deleting card: $e');
      rethrow;
    }
  }

  Future<int> getApplicationCount(String cardId) async {
    try {
      final result = await _client
          .from('applications')
          .select('id')
          .eq('card_id', cardId)
          .count(CountOption.exact)
          .timeout(const Duration(seconds: 15));
      return result.count;
    } catch (e) {
      print('Error getting application count: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getRecommendedCards(String influencerId) async {
    final cacheKey = 'recommended_cards_$influencerId';
    final cached = AppCache().get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _client
          .rpc('get_recommended_cards', params: {'p_influencer_id': influencerId})
          .timeout(const Duration(seconds: 15));
      final result = List<Map<String, dynamic>>.from(response as List);
      AppCache().set(cacheKey, result, ttl: const Duration(minutes: 5));
      return result;
    } catch (e) {
      print('Error getting recommended cards: $e');
      return getActiveCards(limit: 20);
    }
  }
}