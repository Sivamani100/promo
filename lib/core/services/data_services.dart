import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CampaignService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getCampaigns(String brandId) async {
    final data = await _client
        .from('brand_campaigns')
        .select()
        .eq('brand_id', brandId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createCampaign(Map<String, dynamic> data) async {
    await _client.from('brand_campaigns').insert(data);
  }

  Future<void> updateCampaign(String id, Map<String, dynamic> data) async {
    await _client.from('brand_campaigns').update(data).eq('id', id);
  }

  Future<void> deleteCampaign(String id) async {
    await _client.from('brand_campaigns').delete().eq('id', id);
  }
}

class PortfolioService {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Map<String, dynamic>>> getPortfolioItems(String ownerId) async {
    final data = await _client
        .from('portfolio_items')
        .select()
        .eq('owner_id', ownerId)
        .order('sort_order', ascending: true)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addPortfolioItem(Map<String, dynamic> data) async {
    await _client.from('portfolio_items').insert(data);
  }

  Future<void> updatePortfolioItem(String id, Map<String, dynamic> data) async {
    await _client.from('portfolio_items').update(data).eq('id', id);
  }

  Future<void> deletePortfolioItem(String id) async {
    await _client.from('portfolio_items').delete().eq('id', id);
  }
}

class SavedService {
  final SupabaseClient _client = SupabaseService.client;

  // Influencer saved cards
  Future<List<Map<String, dynamic>>> getSavedCards(String influencerId) async {
    final data = await _client
        .from('saved_cards')
        .select('*, card:cards!saved_cards_card_id_fkey(*, brand:profiles!cards_brand_id_fkey(*))')
        .eq('influencer_id', influencerId)
        .order('saved_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> saveCard(String influencerId, String cardId) async {
    await _client.from('saved_cards').insert({'influencer_id': influencerId, 'card_id': cardId});
  }

  Future<void> unsaveCard(String influencerId, String cardId) async {
    await _client.from('saved_cards').delete().eq('influencer_id', influencerId).eq('card_id', cardId);
  }

  Future<bool> isCardSaved(String influencerId, String cardId) async {
    final data = await _client
        .from('saved_cards')
        .select('id')
        .eq('influencer_id', influencerId)
        .eq('card_id', cardId)
        .maybeSingle();
    return data != null;
  }

  // Brand saved influencer lists
  Future<List<Map<String, dynamic>>> getSavedLists(String brandId) async {
    final data = await _client
        .from('influencer_lists')
        .select('*, items:influencer_list_items(*, influencer:profiles!influencer_list_items_influencer_id_fkey(*))')
        .eq('brand_id', brandId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createList(String brandId, String name) async {
    await _client.from('influencer_lists').insert({'brand_id': brandId, 'name': name});
  }

  Future<void> addToList(String listId, String influencerId) async {
    await _client.from('influencer_list_items').insert({'list_id': listId, 'influencer_id': influencerId});
  }

  Future<void> removeFromList(String listId, String influencerId) async {
    await _client.from('influencer_list_items').delete().eq('list_id', listId).eq('influencer_id', influencerId);
  }

  Future<void> deleteList(String listId) async {
    await _client.from('influencer_list_items').delete().eq('list_id', listId);
    await _client.from('influencer_lists').delete().eq('id', listId);
  }
}

class AnalyticsService {
  final SupabaseClient _client = SupabaseService.client;

  Future<int> getProfileViewCount(String profileId) async {
    final result = await _client
        .from('profile_views')
        .select('id')
        .eq('profile_id', profileId)
        .count(CountOption.exact);
    return result.count;
  }

  Future<List<Map<String, dynamic>>> getReviews(String userId) async {
    final data = await _client
        .from('reviews')
        .select('*, reviewer:profiles!reviews_reviewer_id_fkey(display_name, avatar_url)')
        .eq('reviewed_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> submitReview({
    required String reviewerId,
    required String reviewedId,
    required int rating,
    required String comment,
    required String roomId,
  }) async {
    await _client.from('reviews').insert({
      'reviewer_id': reviewerId,
      'reviewed_id': reviewedId,
      'rating': rating,
      'comment': comment.trim(),
      'room_id': roomId,
    });
  }

  Future<List<Map<String, dynamic>>> getProfileViews(String profileId) async {
    try {
      final data = await _client
          .from('profile_views')
          .select('*, viewer:profiles!profile_views_viewer_id_fkey(*)')
          .eq('profile_id', profileId)
          .order('viewed_at', ascending: false)
          .limit(30)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting profile views fkey: $e');
      try {
        final data = await _client
            .from('profile_views')
            .select('*, viewer:profiles(*)')
            .eq('profile_id', profileId)
            .order('viewed_at', ascending: false)
            .limit(30)
            .timeout(const Duration(seconds: 15));
        return List<Map<String, dynamic>>.from(data);
      } catch (e2) {
        print('Error getting profile views fallback: $e2');
        return [];
      }
    }
  }

  Future<void> recordProfileView(String viewerId, String profileId) async {
    await _client.from('profile_views').insert({'viewer_id': viewerId, 'profile_id': profileId});
  }
}

class SearchService {
  final SupabaseClient _client = SupabaseService.client;

  Future<Map<String, List<Map<String, dynamic>>>> search(String query) async {
    if (query.trim().isEmpty) {
      final cards = await _client
          .from('cards')
          .select('*, brand:profiles!cards_brand_id_fkey(*)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      final brands = await _client
          .from('profiles')
          .select()
          .eq('role', 'brand')
          .order('created_at', ascending: false)
          .limit(10);
      final influencers = await _client
          .from('profiles')
          .select()
          .eq('role', 'influencer')
          .order('created_at', ascending: false)
          .limit(10);
      return {
        'cards': List<Map<String, dynamic>>.from(cards),
        'brands': List<Map<String, dynamic>>.from(brands),
        'influencers': List<Map<String, dynamic>>.from(influencers),
      };
    }

    // Text search with ilike fallback
    final cards = await _client
        .from('cards')
        .select('*, brand:profiles!cards_brand_id_fkey(*)')
        .eq('status', 'active')
        .or('title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%');
    final brands = await _client
        .from('profiles')
        .select()
        .eq('role', 'brand')
        .or('display_name.ilike.%$query%,company_name.ilike.%$query%,bio.ilike.%$query%');
    final influencers = await _client
        .from('profiles')
        .select()
        .eq('role', 'influencer')
        .or('display_name.ilike.%$query%,bio.ilike.%$query%');

    return {
      'cards': List<Map<String, dynamic>>.from(cards),
      'brands': List<Map<String, dynamic>>.from(brands),
      'influencers': List<Map<String, dynamic>>.from(influencers),
    };
  }
}

class StorageService {
  final SupabaseClient _client = SupabaseService.client;

  Future<String> uploadFile(String bucket, String path, List<int> bytes, String contentType) async {
    await _client.storage.from(bucket).uploadBinary(path, bytes as dynamic, fileOptions: FileOptions(contentType: contentType, upsert: true));
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}

class FollowService {
  final SupabaseClient _client = SupabaseService.client;

  Future<bool> isFollowing(String followerId, String followingId) async {
    final data = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return data != null;
  }

  Future<void> follow(String followerId, String followingId) async {
    await _client.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  Future<void> unfollow(String followerId, String followingId) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  Future<Set<String>> getFollowingIds(String followerId) async {
    final data = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', followerId);
    return List<Map<String, dynamic>>.from(data)
        .map((e) => e['following_id'] as String)
        .toSet();
  }
}