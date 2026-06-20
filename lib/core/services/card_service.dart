import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CardService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getBrandCards(String brandId) async {
    try {
      final data = await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('brand_id', brandId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting brand cards: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveCards({int limit = 50}) async {
    try {
      final data = await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting active cards: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCardById(String cardId) async {
    try {
      return await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('id', cardId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      print('Error getting card by id: $e');
      return null;
    }
  }

  Future<void> createCard(Map<String, dynamic> cardData) async {
    try {
      await _client.from('cards').insert(cardData).timeout(const Duration(seconds: 15));
    } catch (e) {
      print('Error creating card: $e');
      rethrow;
    }
  }

  Future<void> updateCard(String cardId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    try {
      await _client.from('cards').update(data).eq('id', cardId).timeout(const Duration(seconds: 15));
    } catch (e) {
      print('Error updating card: $e');
      rethrow;
    }
  }

  Future<void> deleteCard(String cardId) async {
    try {
      await _client.from('cards').delete().eq('id', cardId).timeout(const Duration(seconds: 15));
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
}