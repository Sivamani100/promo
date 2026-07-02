import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';
import '../services/supabase_service.dart';

/// Pending deep link destination — stored when a deep link arrives
/// but user is not yet authenticated.
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

/// Handles Universal Links (iOS) and App Links (Android).
///
/// Must be initialized in [BrandApp] after the router is ready.
/// Handles both cold-start links and links arriving while the app is open.
class DeepLinkService {
  DeepLinkService._();

  static AppLinks? _appLinks;
  static StreamSubscription? _linkSubscription;

  /// Initialize deep link handling. Call once from app.dart.
  static Future<void> initialize(WidgetRef ref) async {
    _appLinks = AppLinks();

    // 1. Handle cold start — user tapped a link that launched the app
    try {
      final initialLink = await _appLinks!.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink, ref);
      }
    } catch (e) {
      debugPrint('[DEEPLINK] Failed to get initial link: $e');
    }

    // 2. Handle links arriving while the app is already running
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) => _handleLink(uri, ref),
      onError: (err) => debugPrint('[DEEPLINK] Stream error: $err'),
    );
  }

  /// Parse the incoming URI and navigate accordingly.
  static void _handleLink(Uri uri, WidgetRef ref) {
    debugPrint('[DEEPLINK] Received: $uri');
    
    // Check for password recovery deep link
    final uriStr = uri.toString().toLowerCase();
    if (uriStr.contains('recovery') || uri.fragment.contains('type=recovery') || uri.queryParameters['type'] == 'recovery') {
      debugPrint('[DEEPLINK] Detected password recovery link, passing to Supabase Auth');
      try {
        SupabaseService.client.auth.getSessionFromUrl(uri).then((_) {
          debugPrint('[DEEPLINK] Supabase session established from recovery link');
        }).catchError((err) {
          debugPrint('[DEEPLINK ERROR] Failed to process recovery session: $err');
        });
      } catch (e) {
        debugPrint('[DEEPLINK ERROR] Exception while handling recovery link: $e');
      }
      return;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    String? destination;
    switch (segments[0]) {
      case 'leaderboard':
        ref.read(routerProvider).go('/leaderboard');
        return;
      case 'card':
        if (segments.length > 1) {
          destination = '/card/${segments[1]}';
        }
        break;
      case 'brand':
        if (segments.length > 1) {
          final sub = segments[1];
          const brandAppRoutes = {
            'home', 'cards', 'applications', 'influencers', 'saved-lists',
            'campaigns', 'chats', 'analytics', 'profile', 'settings',
            'support', 'map'
          };
          if (!brandAppRoutes.contains(sub)) {
            destination = '/brand/profile/$sub';
          }
        }
        break;
      case 'influencer':
        if (segments.length > 1) {
          final sub = segments[1];
          const influencerAppRoutes = {
            'home', 'discover', 'my-applications', 'milestones', 'saved',
            'portfolio', 'chats', 'analytics', 'profile', 'settings',
            'support', 'map', 'brands'
          };
          if (!influencerAppRoutes.contains(sub)) {
            destination = '/influencer/profile/$sub';
          }
        }
        break;
      case 'collab':
        if (segments.length > 1) {
          destination = '/chat/room/${segments[1]}';
        }
        break;
      case 'invite':
        // Referral link — store ref param for after signup
        final refId = uri.queryParameters['ref'];
        if (refId != null && refId.isNotEmpty) {
          ref.read(pendingDeepLinkProvider.notifier).state = 'ref:$refId';
        }
        return;
    }

    if (destination != null) {
      _navigateWithAuthCheck(destination, ref);
    }
  }

  /// If authenticated, navigate immediately.
  /// If not, save destination and let the auth flow handle it after login.
  static void _navigateWithAuthCheck(String destination, WidgetRef ref) {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      // User is logged in — navigate directly
      final context = _appLinks != null ? null : null; // router handles it
      ref.read(routerProvider).go(destination);
    } else {
      // Save destination for after login/signup
      ref.read(pendingDeepLinkProvider.notifier).state = destination;
      debugPrint('[DEEPLINK] Saved pending destination: $destination');
    }
  }

  /// Call after successful login to navigate to any pending deep link.
  static void handlePendingLink(WidgetRef ref) {
    final pending = ref.read(pendingDeepLinkProvider);
    if (pending != null && !pending.startsWith('ref:')) {
      ref.read(pendingDeepLinkProvider.notifier).state = null;
      ref.read(routerProvider).go(pending);
      debugPrint('[DEEPLINK] Navigating to pending: $pending');
    }
  }

  /// Clean up subscriptions.
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
