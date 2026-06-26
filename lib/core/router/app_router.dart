import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app_transitions.dart';
import '../providers/app_providers.dart';

// Feature screens
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/set_new_password_screen.dart';
import '../../features/auth/terms_gate_screen.dart';
import '../../features/auth/consent_screen.dart';
import '../../features/onboarding/onboarding_shell.dart';
import '../../features/onboarding/dashboard_tour_screen.dart';
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
import '../../features/influencer/discover_map_screen.dart';
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
import '../../features/settings/developer_settings_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../features/trust/account_status_screens.dart';
import '../../features/trust/blocked_users_screen.dart';
import '../../features/agreements/raise_dispute_screen.dart';
import '../../features/agreements/agreement_builder_screen.dart';
import '../../features/agreements/agreement_review_screen.dart';
import '../../features/agreements/payment_tracker_screen.dart';

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

  // HARDENING: observability-agent 2026-06-24
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    observers: [SentryNavigatorObserver()],
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

      // 3. If in password recovery, send to set-new-password and allow the route
      if (isRecovery) {
        if (path != '/set-new-password') {
          return '/set-new-password';
        }
        return null; // Exempt password recovery from other gates
      }

      // 4. If not authenticated
      if (!isAuth) {
        if (!isAuthRoute && !isOnboardingRoute) {
          return '/login';
        }
        return null;
      }

      // 4.5. Check user account status (suspension/ban)
      final status = authState.profile?['account_status'] as String? ?? 'active';
      if (status == 'banned') {
        if (path != '/banned') return '/banned';
        return null;
      }
      if (status == 'suspended') {
        if (path != '/suspended') return '/suspended';
        return null;
      }
      if (path == '/banned' || path == '/suspended') {
        if (authState.role == 'brand') return '/brand/home';
        if (authState.role == 'influencer') return '/influencer/home';
        return '/login';
      }

      // 4.7. Check TOS and Consent Gate
      final preferences = authState.profile?['preferences'] as Map<String, dynamic>? ?? {};
      final tosVersionAccepted = preferences['tos_version_accepted']?.toString();
      const currentTosVersion = '1.0';

      final consents = preferences['consents'] as Map<String, dynamic>?;
      final needsConsent = consents == null;

      final isLegalDocRoute = path.endsWith('/tos') || path.endsWith('/privacy-policy');
      final isGateRoute = path == '/terms-gate' || path == '/consent';

      if (tosVersionAccepted != currentTosVersion) {
        if (path != '/terms-gate' && !isLegalDocRoute) {
          return '/terms-gate';
        }
        return null;
      }

      if (needsConsent) {
        if (path != '/consent' && !isLegalDocRoute) {
          return '/consent';
        }
        return null;
      }

      if (isGateRoute) {
        final isFromSettings = state.uri.queryParameters['from_settings'] == 'true';
        if (!isFromSettings) {
          final hasCompletedOnboarding = authState.isOnboardingComplete;
          if (!hasCompletedOnboarding) {
            return '/onboarding/1';
          }
          if (authState.role == 'brand') return '/brand/home';
          if (authState.role == 'influencer') return '/influencer/home';
          return '/login';
        }
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
      if (isAuthRoute || isOnboardingRoute || path == '/splash' || isGateRoute) {
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
      
      // Terms Gate & Consent
      GoRoute(path: '/terms-gate', builder: (_, _) => const TermsGateScreen()),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),

      // Onboarding
      GoRoute(path: '/onboarding/:step', builder: (_, state) {
        final step = int.tryParse(state.pathParameters['step'] ?? '1') ?? 1;
        return OnboardingShell(currentStep: step);
      }),

      // Dashboard Tour (Full-page onboarding)
      GoRoute(
        path: '/dashboard-tour',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const DashboardTourScreen(),
      ),

      // Full-screen routes (no bottom bar)
      GoRoute(
        path: '/brand/cards/new',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final card = state.extra as Map<String, dynamic>?;
          return AppTransitions.slideUpModal(
            key: state.pageKey,
            child: BrandCardCreateScreen(card: card),
          );
        },
      ),
      GoRoute(
        path: '/brand/cards/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: BrandCardDetailScreen(cardId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/brand/chats/:roomId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: ChatRoomScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/brand/agreements/new',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final roomId = state.uri.queryParameters['roomId']!;
          final cardId = state.uri.queryParameters['cardId']!;
          final influencerId = state.uri.queryParameters['influencerId']!;
          return AppTransitions.slideLeft(
            key: state.pageKey,
            child: AgreementBuilderScreen(roomId: roomId, cardId: cardId, influencerId: influencerId),
          );
        },
      ),
      GoRoute(
        path: '/brand/agreements/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: AgreementReviewScreen(agreementId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/brand/payments/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: PaymentTrackerScreen(agreementId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/brand/disputes/new',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final agreementId = state.uri.queryParameters['agreementId']!;
          final paymentId = state.uri.queryParameters['paymentId'];
          return AppTransitions.slideLeft(
            key: state.pageKey,
            child: RaiseDisputeScreen(agreementId: agreementId, paymentId: paymentId),
          );
        },
      ),
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
          GoRoute(path: 'developers', builder: (_, _) => const DeveloperSettingsScreen()),
          GoRoute(path: 'tos', builder: (_, _) => const DocumentViewerScreen(title: 'Terms of Service', docType: 'tos')),
          GoRoute(path: 'privacy-policy', builder: (_, _) => const DocumentViewerScreen(title: 'Privacy Policy', docType: 'privacy')),
        ],
      ),
      GoRoute(
        path: '/brand/support',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const SupportScreen(),
        ),
      ),
      GoRoute(
        path: '/influencer/discover/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: InfluencerCardDetailScreen(cardId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/influencer/chats/:roomId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: ChatRoomScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/influencer/agreements/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: AgreementReviewScreen(agreementId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/influencer/payments/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: PaymentTrackerScreen(agreementId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/influencer/disputes/new',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final agreementId = state.uri.queryParameters['agreementId']!;
          final paymentId = state.uri.queryParameters['paymentId'];
          return AppTransitions.slideLeft(
            key: state.pageKey,
            child: RaiseDisputeScreen(agreementId: agreementId, paymentId: paymentId),
          );
        },
      ),
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
          GoRoute(path: 'developers', builder: (_, _) => const DeveloperSettingsScreen()),
          GoRoute(path: 'tos', builder: (_, _) => const DocumentViewerScreen(title: 'Terms of Service', docType: 'tos')),
          GoRoute(path: 'privacy-policy', builder: (_, _) => const DocumentViewerScreen(title: 'Privacy Policy', docType: 'privacy')),
        ],
      ),
      GoRoute(
        path: '/influencer/support',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const SupportScreen(),
        ),
      ),
      GoRoute(
        path: '/influencer/map',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const DiscoverMapScreen(),
        ),
      ),
      GoRoute(
        path: '/brand/map',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const DiscoverMapScreen(),
        ),
      ),
      GoRoute(
        path: '/brand/influencers/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: BrandInfluencerDetailScreen(influencerId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/influencer/brands/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: InfluencerBrandDetailScreen(brandId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/influencer/brands',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return AppTransitions.slideLeft(
            key: state.pageKey,
            child: InfluencerBrandsScreen(initialTab: tab),
          );
        },
      ),
      GoRoute(
        path: '/influencer/profile-views',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const ProfileViewsScreen(),
        ),
      ),
      GoRoute(
        path: '/influencer/engagement-rate',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const EngagementRateScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/image-viewer',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final rawUrls = extra['urls'] as List<dynamic>? ?? [];
          final urls = rawUrls.map((e) => e.toString()).toList();
          final initialIndex = extra['initialIndex'] as int? ?? 0;
          final title = extra['title'] as String? ?? 'Image Viewer';
          return AppTransitions.slideUpModal(
            key: state.pageKey,
            child: ImageViewerScreen(
              urls: urls,
              initialIndex: initialIndex,
              title: title,
            ),
          );
        },
      ),
      GoRoute(
        path: '/brand/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/influencer/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppTransitions.slideLeft(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),

      // Brand shell (with bottom bar)
      ShellRoute(
        navigatorKey: _brandShellKey,
        builder: (_, _, child) => AppScaffold(role: 'brand', child: child),
        routes: [
          GoRoute(path: '/brand/home', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandHomeScreen())),
          GoRoute(path: '/brand/cards', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandCardsScreen())),
          GoRoute(path: '/brand/applications', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandApplicationsScreen())),
          GoRoute(path: '/brand/influencers', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandInfluencersScreen())),
          GoRoute(path: '/brand/saved-lists', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandSavedListsScreen())),
          GoRoute(
            path: '/brand/saved-lists/:id',
            pageBuilder: (context, state) {
              final listId = state.pathParameters['id']!;
              final extra = state.extra as Map<String, dynamic>?;
              final listName = extra?['name'] as String? ?? 'Saved List';
              return AppTransitions.fade(
                key: state.pageKey,
                child: BrandSavedListDetailScreen(listId: listId, name: listName),
              );
            },
          ),
          GoRoute(path: '/brand/campaigns', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandCampaignsScreen())),
          GoRoute(path: '/brand/chats', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const ChatsListScreen(role: 'brand'))),
          GoRoute(path: '/brand/analytics', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandAnalyticsScreen())),
          GoRoute(path: '/brand/profile', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const BrandProfileScreen())),
        ],
      ),

      // Influencer shell (with bottom bar)
      ShellRoute(
        navigatorKey: _influencerShellKey,
        builder: (_, _, child) => AppScaffold(role: 'influencer', child: child),
        routes: [
          GoRoute(path: '/influencer/home', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const InfluencerHomeScreen())),
          GoRoute(
            path: '/influencer/discover',
            pageBuilder: (context, state) {
              final filter = state.uri.queryParameters['filter'];
              return AppTransitions.fade(
                key: state.pageKey,
                child: InfluencerDiscoverScreen(filter: filter),
              );
            },
          ),
          GoRoute(
            path: '/influencer/my-applications',
            pageBuilder: (context, state) {
              final cardId = state.uri.queryParameters['cardId'];
              return AppTransitions.fade(
                key: state.pageKey,
                child: InfluencerApplicationsScreen(cardId: cardId),
              );
            },
          ),
          GoRoute(path: '/influencer/milestones', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const InfluencerMilestonesScreen())),
          GoRoute(path: '/influencer/saved', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const InfluencerSavedScreen())),
          GoRoute(path: '/influencer/portfolio', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const InfluencerPortfolioScreen())),
          GoRoute(path: '/influencer/chats', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const ChatsListScreen(role: 'influencer'))),
          GoRoute(path: '/influencer/analytics', pageBuilder: (context, state) => AppTransitions.fade(key: state.pageKey, child: const InfluencerAnalyticsScreen())),
          GoRoute(
            path: '/influencer/profile',
            pageBuilder: (context, state) {
              final editParam = state.uri.queryParameters['edit'] == 'true';
              return AppTransitions.fade(
                key: state.pageKey,
                child: InfluencerProfileScreen(startInEditMode: editParam),
              );
            },
          ),
        ],
      ),
    ],
  );
});