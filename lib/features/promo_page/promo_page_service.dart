import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

class PromoPage {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String theme;
  final String? backgroundColor;
  final String? accentColor;
  final bool showSocialPlatforms;
  final bool showPromoBadge;
  final bool isPublished;
  final DateTime? usernameChangedAt;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoPage({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    required this.theme,
    this.backgroundColor,
    this.accentColor,
    required this.showSocialPlatforms,
    required this.showPromoBadge,
    required this.isPublished,
    this.usernameChangedAt,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoPage.fromJson(Map<String, dynamic> json) {
    return PromoPage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      theme: json['theme'] as String? ?? 'dark',
      backgroundColor: json['background_color'] as String?,
      accentColor: json['accent_color'] as String?,
      showSocialPlatforms: json['show_social_platforms'] as bool? ?? true,
      showPromoBadge: json['show_promo_badge'] as bool? ?? true,
      isPublished: json['is_published'] as bool? ?? false,
      usernameChangedAt: json['username_changed_at'] != null 
          ? DateTime.parse(json['username_changed_at'] as String) 
          : null,
      viewCount: (json['view_count'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'theme': theme,
      'background_color': backgroundColor,
      'accent_color': accentColor,
      'show_social_platforms': showSocialPlatforms,
      'show_promo_badge': showPromoBadge,
      'is_published': isPublished,
      'username_changed_at': usernameChangedAt?.toIso8601String(),
      'view_count': viewCount,
    };
  }
}

class PromoPageLink {
  final String id;
  final String pageId;
  final String userId;
  final String title;
  final String url;
  final String? icon;
  final int displayOrder;
  final bool isEnabled;
  final int clickCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoPageLink({
    required this.id,
    required this.pageId,
    required this.userId,
    required this.title,
    required this.url,
    this.icon,
    required this.displayOrder,
    required this.isEnabled,
    required this.clickCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoPageLink.fromJson(Map<String, dynamic> json) {
    return PromoPageLink(
      id: json['id'] as String,
      pageId: json['page_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      icon: json['icon'] as String?,
      displayOrder: (json['display_order'] as num? ?? 0).toInt(),
      isEnabled: json['is_enabled'] as bool? ?? true,
      clickCount: (json['click_count'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'page_id': pageId,
      'user_id': userId,
      'title': title,
      'url': url,
      'icon': icon,
      'display_order': displayOrder,
      'is_enabled': isEnabled,
      'click_count': clickCount,
    };
  }
}

class PromoPageService {
  static final _client = SupabaseService.client;

  static const List<String> reservedUsernames = [
    'admin', 'api', 'app', 'settings', 'login', 'signup', 'register', 
    'promo', 'support', 'help', 'www', 'mail', 'static', 'assets', 
    'public', 'private', 'internal', 'dashboard', 'brand', 'influencer',
    'explore', 'discover', 'search', 'map', 'chat', 'notification',
    'terms', 'privacy', 'delete', 'account', 'profile', 'about', 'contact'
  ];

  /// Check username eligibility. Returns true if valid and available.
  static Future<bool> checkUsernameAvailability(String username) async {
    final cleaned = username.trim().toLowerCase();
    
    // Regex validation: only lowercase alphanumeric and underscores, length 3-30
    final regExp = RegExp(r'^[a-z0-9_]{3,30}$');
    if (!regExp.hasMatch(cleaned)) {
      return false;
    }

    // Reserved words check
    if (reservedUsernames.contains(cleaned)) {
      return false;
    }

    try {
      final res = await _client
          .from('promo_pages')
          .select('id')
          .eq('username', cleaned)
          .maybeSingle();
      return res == null;
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error checking availability: $e');
      return false;
    }
  }

  /// Create a new Promo Page for the current user
  static Future<PromoPage> claimUsername(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    final cleaned = username.trim().toLowerCase().replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.length < 3) {
      throw Exception('Username must be at least 3 characters long.');
    }

    final data = await _client.from('promo_pages').insert({
      'user_id': user.id,
      'username': cleaned,
      'theme': 'dark',
      'is_published': false,
    }).select().single();

    return PromoPage.fromJson(data);
  }

  /// Retrieve the current logged-in user's Promo Page config
  static Future<PromoPage?> getMyPage() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('promo_pages')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (data == null) return null;
      return PromoPage.fromJson(data);
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error fetching my page: $e');
      return null;
    }
  }

  /// Update Promo Page settings
  static Future<PromoPage> updatePage(Map<String, dynamic> updates) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    // Ensure we filter updates to only allow valid columns
    final filtered = Map<String, dynamic>.from(updates);
    filtered.remove('id');
    filtered.remove('user_id');
    filtered.remove('view_count');
    filtered.remove('created_at');
    filtered.remove('updated_at');

    if (filtered.containsKey('username')) {
      final newUsername = filtered['username'] as String;
      final regExp = RegExp(r'^[a-z0-9_]{3,30}$');
      if (!regExp.hasMatch(newUsername) || reservedUsernames.contains(newUsername)) {
        throw Exception('Invalid username.');
      }
      filtered['username_changed_at'] = DateTime.now().toUtc().toIso8601String();
    }

    final data = await _client
        .from('promo_pages')
        .update(filtered)
        .eq('user_id', user.id)
        .select()
        .single();

    return PromoPage.fromJson(data);
  }

  /// Add a link
  static Future<PromoPageLink> addLink(String pageId, String title, String url, String? icon) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    if (!url.startsWith('https://')) {
      throw Exception('Only secure URLs starting with https:// are allowed.');
    }
    if (title.trim().length > 60) {
      throw Exception('Title must be at most 60 characters long.');
    }

    // Determine the next display order
    final countData = await _client
        .from('promo_page_links')
        .select('display_order')
        .eq('page_id', pageId)
        .order('display_order', ascending: false)
        .limit(1)
        .maybeSingle();
    final nextOrder = countData != null ? (countData['display_order'] as int) + 1 : 0;

    final data = await _client.from('promo_page_links').insert({
      'page_id': pageId,
      'user_id': user.id,
      'title': title.trim(),
      'url': url.trim(),
      'icon': icon?.trim(),
      'display_order': nextOrder,
      'is_enabled': true,
    }).select().single();

    return PromoPageLink.fromJson(data);
  }

  /// Update a link
  static Future<void> updateLink(String linkId, Map<String, dynamic> updates) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    if (updates.containsKey('url')) {
      final url = updates['url'] as String;
      if (!url.startsWith('https://')) {
        throw Exception('Only secure URLs starting with https:// are allowed.');
      }
    }

    await _client
        .from('promo_page_links')
        .update(updates)
        .eq('id', linkId)
        .eq('user_id', user.id);
  }

  /// Delete a link
  static Future<void> deleteLink(String linkId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    await _client
        .from('promo_page_links')
        .delete()
        .eq('id', linkId)
        .eq('user_id', user.id);
  }

  /// Reorder links
  static Future<void> reorderLinks(String pageId, List<String> orderedIds) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    // Prepare batch update mapping.
    // In Supabase client side, we can perform updates sequentially or via RPC.
    // Sequential updates are safe and easy for up to 20 links.
    for (int i = 0; i < orderedIds.length; i++) {
      await _client
          .from('promo_page_links')
          .update({'display_order': i})
          .eq('id', orderedIds[i])
          .eq('user_id', user.id);
    }
  }

  /// Retrieve all links for a given page
  static Future<List<PromoPageLink>> getLinks(String pageId, {bool enabledOnly = false}) async {
    try {
      var query = _client.from('promo_page_links').select().eq('page_id', pageId);
      if (enabledOnly) {
        query = query.eq('is_enabled', true);
      }
      final data = await query.order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(data).map(PromoPageLink.fromJson).toList();
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error fetching links: $e');
      return [];
    }
  }

  /// Get public page by username (does not require auth)
  static Future<PromoPage?> getPublicPage(String username) async {
    try {
      final data = await _client
          .from('promo_pages')
          .select()
          .eq('username', username.toLowerCase())
          .eq('is_published', true)
          .maybeSingle();
      if (data == null) return null;
      return PromoPage.fromJson(data);
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error fetching public page: $e');
      return null;
    }
  }

  /// Retrieve public profiles platforms configurations (social URLs) for the user.
  static Future<Map<String, dynamic>?> getPublicSocials(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('platforms, display_name, avatar_url, bio')
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error fetching profiles socials: $e');
      return null;
    }
  }

  /// Record a view count and view detail
  static Future<void> recordPageView(String pageId, String? referrer) async {
    try {
      // 1. Call RPC function to safely increment view count on the page
      await _client.rpc('increment_promo_page_views', params: {'p_page_id': pageId});
      
      // 2. Insert view details (IP is hashed by server or client fingerprint)
      String fingerprint = 'client_ua_${kIsWeb ? "web" : "mobile"}_fingerprint';
      await _client.from('promo_page_views').insert({
        'page_id': pageId,
        'viewer_ip_hash': fingerprint,
        'referrer': referrer ?? '',
      });
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error recording view: $e');
    }
  }

  /// Record link click
  static Future<void> incrementLinkClick(String linkId) async {
    try {
      await _client.rpc('increment_promo_link_clicks', params: {'p_link_id': linkId});
    } catch (e) {
      debugPrint('[PROMO_PAGE] Error recording link click: $e');
    }
  }
}
