import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';

// Feature screens
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/set_new_password_screen.dart';
import '../../features/onboarding/onboarding_shell.dart';
import '../../features/brand/brand_home_screen.dart';
import '../../features/brand/brand_cards_screen.dart';
import '../../features/brand/brand_card_create_screen.dart';
import '../../features/brand/brand_card_detail_screen.dart';
import '../../features/brand/brand_applications_screen.dart';
import '../../features/brand/brand_influencers_screen.dart';
import '../../features/brand/brand_remaining_screens.dart';
import '../../features/brand/brand_influencer_detail_screen.dart';
import '../../features/influencer/influencer_home_screen.dart';
import '../../features/influencer/influencer_discover_screen.dart';
import '../../features/influencer/influencer_card_detail_screen.dart';
import '../../features/influencer/influencer_applications_screen.dart';
import '../../features/influencer/influencer_remaining_screens.dart';
import '../../features/influencer/influencer_brand_detail_screen.dart';
import '../../features/chat/chats_list_screen.dart';
import '../../features/chat/chat_room_screen.dart';
import '../../features/chat/image_viewer_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/notification_settings.dart';
import '../../features/settings/privacy_settings.dart';
import '../../features/settings/security_settings.dart';
import '../../features/settings/verification_settings.dart';
import '../../features/settings/platform_settings.dart';
import '../../features/settings/api_keys_settings.dart';
import '../../features/settings/document_viewer.dart';
import '../../features/support/support_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../shared/widgets/app_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _brandShellKey = GlobalKey<NavigatorState>();
final _influencerShellKey = GlobalKey<NavigatorState>();

class AppRouterRefreshListenable extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = AppRouterRefreshListenable();
  
  ref.listen<bool>(splashCompletedProvider, (previous, next) {
    print('[ROUTER] splashCompleted changed from $previous to $next');
    refreshListenable.refresh();
  });
  
  ref.listen<AuthState>(authProvider, (previous, next) {
    print('[ROUTER] authState changed: isLoading=${next.isLoading}, isAuthenticated=${next.isAuthenticated}, role=${next.role}');
    refreshListenable.refresh();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isSplashCompleted = ref.read(splashCompletedProvider);
      final authState = ref.read(authProvider);
      final isLoading = authState.isLoading;
      final isAuth = authState.isAuthenticated;
      final isRecovery = authState.isRecoveryMode;
      final path = state.uri.path;
      final isAuthRoute = path.startsWith('/login') || path.startsWith('/signup') || path.startsWith('/reset-password') || path.startsWith('/set-new-password');

      final isOnboardingRoute = path.startsWith('/onboarding');

      print('[ROUTER REDIRECT] path: $path, splashCompleted: $isSplashCompleted, authLoading: $isLoading, authenticated: $isAuth, role: ${authState.role}');

      // 1. If splash is not completed, we MUST stay on /splash
      if (!isSplashCompleted) {
        return '/splash';
      }

      // 2. If auth state is loading, wait on splash or show loading
      if (isLoading) {
        return path == '/splash' ? null : null;
      }

      // 3. If in password recovery, send to set-new-password
      if (isRecovery && path != '/set-new-password') {
        return '/set-new-password';
      }

      // 4. If not authenticated
      if (!isAuth) {
        if (!isAuthRoute && !isOnboardingRoute) {
          return '/login';
        }
        return null;
      }

      // 5. If authenticated, verify onboarding completion
      final hasCompletedOnboarding = authState.isOnboardingComplete;

      if (!hasCompletedOnboarding) {
        if (!isOnboardingRoute) {
          return '/onboarding/1';
        }
        return null;
      }

      // 6. User has completed onboarding and is authenticated
      if (isAuthRoute || isOnboardingRoute || path == '/splash') {
        if (authState.role == 'brand') return '/brand/home';
        if (authState.role == 'influencer') return '/influencer/home';
        return '/login';
      }
      return null;
    },
    routes: [
      // Splash
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      // Auth routes (no shell)
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/reset-password', builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(path: '/set-new-password', builder: (_, _) => const SetNewPasswordScreen()),

      // Onboarding
      GoRoute(path: '/onboarding/:step', builder: (_, state) {
        final step = int.tryParse(state.pathParameters['step'] ?? '1') ?? 1;
        return OnboardingShell(currentStep: step);
      }),

      // Full-screen routes (no bottom bar)
      GoRoute(
        path: '/brand/cards/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final card = state.extra as Map<String, dynamic>?;
          return BrandCardCreateScreen(card: card);
        },
      ),
      GoRoute(path: '/brand/cards/:id', parentNavigatorKey: _rootNavigatorKey, builder: (_, state) => BrandCardDetailScreen(cardId: state.pathParameters['id']!)),
      GoRoute(path: '/brand/chats/:roomId', parentNavigatorKey: _rootNavigatorKey, builder: (_, state) => ChatRoomScreen(roomId: state.pathParameters['roomId']!)),
      GoRoute(
        path: '/brand/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacySettingsScreen()),
          GoRoute(path: 'security', builder: (_, _) => const SecuritySettingsScreen()),
          GoRoute(path: 'verification', builder: (_, _) => const VerificationSettingsScreen()),
          GoRoute(path: 'apikeys', builder: (_, _) => const ApiKeysSettingsScreen()),
          GoRoute(path: 'tos', builder: (_, _) => const DocumentViewerScreen(title: 'Terms of Service', docType: 'tos')),
          GoRoute(path: 'privacy-policy', builder: (_, _) => const DocumentViewerScreen(title: 'Privacy Policy', docType: 'privacy')),
        ],
      ),
      GoRoute(path: '/brand/support', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const SupportScreen()),
      GoRoute(path: '/influencer/discover/:id', parentNavigatorKey: _rootNavigatorKey, builder: (_, state) => InfluencerCardDetailScreen(cardId: state.pathParameters['id']!)),
      GoRoute(path: '/influencer/chats/:roomId', parentNavigatorKey: _rootNavigatorKey, builder: (_, state) => ChatRoomScreen(roomId: state.pathParameters['roomId']!)),
      GoRoute(
        path: '/influencer/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacySettingsScreen()),
          GoRoute(path: 'security', builder: (_, _) => const SecuritySettingsScreen()),
          GoRoute(path: 'verification', builder: (_, _) => const VerificationSettingsScreen()),
          GoRoute(path: 'platforms', builder: (_, _) => const PlatformSettingsScreen()),
          GoRoute(path: 'apikeys', builder: (_, _) => const ApiKeysSettingsScreen()),
          GoRoute(path: 'tos', builder: (_, _) => const DocumentViewerScreen(title: 'Terms of Service', docType: 'tos')),
          GoRoute(path: 'privacy-policy', builder: (_, _) => const DocumentViewerScreen(title: 'Privacy Policy', docType: 'privacy')),
        ],
      ),
      GoRoute(path: '/influencer/support', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const SupportScreen()),
      GoRoute(path: '/brand/influencers/:id', parentNavigatorKey: _rootNavigatorKey, builder: (_, state) => BrandInfluencerDetailScreen(influencerId: state.pathParameters['id']!)),
      GoRoute(path: '/influencer/brands/:id', parentNavigatorKey: _rootNavigatorKey, builder: (_, state) => InfluencerBrandDetailScreen(brandId: state.pathParameters['id']!)),
      GoRoute(
        path: '/influencer/brands',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          return InfluencerBrandsScreen(initialTab: tab);
        },
      ),
      GoRoute(path: '/influencer/profile-views', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const ProfileViewsScreen()),
      GoRoute(path: '/influencer/engagement-rate', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const EngagementRateScreen()),
      GoRoute(path: '/search', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/image-viewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final rawUrls = extra['urls'] as List<dynamic>? ?? [];
          final urls = rawUrls.map((e) => e.toString()).toList();
          final initialIndex = extra['initialIndex'] as int? ?? 0;
          final title = extra['title'] as String? ?? 'Image Viewer';
          return ImageViewerScreen(
            urls: urls,
            initialIndex: initialIndex,
            title: title,
          );
        },
      ),
      GoRoute(path: '/brand/notifications', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/influencer/notifications', parentNavigatorKey: _rootNavigatorKey, builder: (_, _) => const NotificationsScreen()),

      // Brand shell (with bottom bar)
      ShellRoute(
        navigatorKey: _brandShellKey,
        builder: (_, _, child) => AppScaffold(role: 'brand', child: child),
        routes: [
          GoRoute(path: '/brand/home', builder: (_, _) => const BrandHomeScreen()),
          GoRoute(path: '/brand/cards', builder: (_, _) => const BrandCardsScreen()),
          GoRoute(path: '/brand/applications', builder: (_, _) => const BrandApplicationsScreen()),
          GoRoute(path: '/brand/influencers', builder: (_, _) => const BrandInfluencersScreen()),
          GoRoute(path: '/brand/saved-lists', builder: (_, _) => const BrandSavedListsScreen()),
          GoRoute(
            path: '/brand/saved-lists/:id',
            builder: (_, state) {
              final listId = state.pathParameters['id']!;
              final extra = state.extra as Map<String, dynamic>?;
              final listName = extra?['name'] as String? ?? 'Saved List';
              return BrandSavedListDetailScreen(listId: listId, name: listName);
            },
          ),
          GoRoute(path: '/brand/campaigns', builder: (_, _) => const BrandCampaignsScreen()),
          GoRoute(path: '/brand/chats', builder: (_, _) => const ChatsListScreen(role: 'brand')),
          GoRoute(path: '/brand/analytics', builder: (_, _) => const BrandAnalyticsScreen()),
          GoRoute(path: '/brand/profile', builder: (_, _) => const BrandProfileScreen()),
        ],
      ),

      // Influencer shell (with bottom bar)
      ShellRoute(
        navigatorKey: _influencerShellKey,
        builder: (_, _, child) => AppScaffold(role: 'influencer', child: child),
        routes: [
          GoRoute(path: '/influencer/home', builder: (_, _) => const InfluencerHomeScreen()),
          GoRoute(
            path: '/influencer/discover',
            builder: (_, state) {
              final filter = state.uri.queryParameters['filter'];
              return InfluencerDiscoverScreen(filter: filter);
            },
          ),
          GoRoute(
            path: '/influencer/my-applications',
            builder: (_, state) {
              final cardId = state.uri.queryParameters['cardId'];
              return InfluencerApplicationsScreen(cardId: cardId);
            },
          ),
          GoRoute(path: '/influencer/milestones', builder: (_, _) => const InfluencerMilestonesScreen()),
          GoRoute(path: '/influencer/saved', builder: (_, _) => const InfluencerSavedScreen()),
          GoRoute(path: '/influencer/portfolio', builder: (_, _) => const InfluencerPortfolioScreen()),
          GoRoute(path: '/influencer/chats', builder: (_, _) => const ChatsListScreen(role: 'influencer')),
          GoRoute(path: '/influencer/analytics', builder: (_, _) => const InfluencerAnalyticsScreen()),
          GoRoute(
            path: '/influencer/profile',
            builder: (_, state) {
              final editParam = state.uri.queryParameters['edit'] == 'true';
              return InfluencerProfileScreen(startInEditMode: editParam);
            },
          ),
        ],
      ),
    ],
  );
});