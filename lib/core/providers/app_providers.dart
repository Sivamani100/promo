import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/chat_service.dart';
import '../services/social_agent.dart';
import '../services/notification_service.dart';
import '../services/realtime_subscription_manager.dart';
import '../security/session_guard.dart';
import '../security/totp_helper.dart';
import '../utils/error_handler.dart';

// ---------- Auth Provider ----------

class AuthState {
  final User? user;
  final Map<String, dynamic>? profile;
  final String? role; // 'brand' | 'influencer' | 'admin'
  final bool isLoading;
  final String? error;
  final bool isRecoveryMode;
  final bool isOnboardingComplete;
  final bool isTwoFactorVerified;

  const AuthState({
    this.user,
    this.profile,
    this.role,
    this.isLoading = true,
    this.error,
    this.isRecoveryMode = false,
    this.isOnboardingComplete = false,
    this.isTwoFactorVerified = false,
  });

  AuthState copyWith({
    User? user,
    Map<String, dynamic>? profile,
    String? role,
    bool? isLoading,
    String? error,
    bool? isRecoveryMode,
    bool? isOnboardingComplete,
    bool? isTwoFactorVerified,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRecoveryMode: isRecoveryMode ?? this.isRecoveryMode,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      isTwoFactorVerified: isTwoFactorVerified ?? this.isTwoFactorVerified,
    );
  }

  bool get isAuthenticated => user != null;
  bool get isBrand => role == 'brand';
  bool get isInfluencer => role == 'influencer';
  bool get isAdmin => role == 'admin';
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();
  StreamSubscription<dynamic>? _authSub;

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final uri = Uri.base;
      final isRecoveryPath = kIsWeb && (uri.fragment.contains('recovery') || uri.toString().contains('recovery') || uri.fragment.contains('/set-new-password') || uri.path.contains('set-new-password'));

      // Check if there is a manual PKCE code exchange needed (e.g. on Web redirect)
      if (uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code']!;
        print('[AUTH] Found PKCE code in URL on startup. isRecoveryPath: $isRecoveryPath. Exchanging...');
        try {
          state = const AuthState(isLoading: true);
          final response = await _authService.exchangeCodeForSession(code);
          print('[AUTH] Manual exchange success. User: ${response.session?.user.id}');
          if (response.session != null) {
            if (isRecoveryPath) {
              state = AuthState(
                user: response.session.user,
                isLoading: false,
                isRecoveryMode: true,
              );
            } else {
              await _loadProfile(response.session.user).timeout(
                const Duration(seconds: 6),
                onTimeout: () {
                  print('[AUTH] _loadProfile manual exchange timed out');
                  if (state.profile == null) {
                    state = AuthState(
                      user: response.session.user,
                      isLoading: false,
                      error: 'Profile load timeout',
                    );
                  }
                },
              );
            }
          } else {
            state = const AuthState(isLoading: false);
          }
        } catch (e) {
          print('[AUTH] Manual exchange error: $e');
          state = AuthState(isLoading: false, error: e.toString());
        }
      } else {
        final user = _authService.currentUser;
        if (user != null) {
          if (isRecoveryPath) {
            print('[AUTH] Restoring session in recovery mode');
            state = AuthState(
              user: user,
              isLoading: false,
              isRecoveryMode: true,
            );
          } else {
            // Restore from SharedPreferences first to bypass network call delay
            try {
              final prefs = await SharedPreferences.getInstance();
              final cachedProfileStr = prefs.getString('cached_profile_${user.id}');
              if (cachedProfileStr != null) {
                final cachedProfile = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
                final cachedRole = cachedProfile['role'] as String?;
                final cachedOnboarding = prefs.getBool('onboarding_complete_${user.id}') ?? (cachedProfile['onboarding_complete'] == true);
                print('[AUTH] Restored cached profile on startup: role=$cachedRole');
                state = AuthState(
                  user: user,
                  profile: cachedProfile,
                  role: cachedRole,
                  isLoading: false,
                  isOnboardingComplete: cachedOnboarding,
                  isTwoFactorVerified: !(cachedProfile['totp_enabled'] == true),
                );
              }
            } catch (e) {
              print('[AUTH] Startup cache restore error: $e');
            }

            await _loadProfile(user).timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                print('[AUTH] _loadProfile startup timed out');
                if (state.profile == null) {
                  state = AuthState(
                    user: user,
                    isLoading: false,
                    error: 'Profile load timeout',
                  );
                }
              },
            );
          }
        } else {
          state = const AuthState(isLoading: false);
        }
      }

      _authSub = _authService.authStateChanges.listen((authState) async {
        final event = authState.event;
        print('[AUTH] authStateChange event: $event');
        final isRecoveryPathCurrent = kIsWeb && (Uri.base.fragment.contains('recovery') || Uri.base.toString().contains('recovery') || Uri.base.fragment.contains('/set-new-password') || Uri.base.path.contains('set-new-password'));

        if (event == AuthChangeEvent.passwordRecovery) {
          if (authState.session?.user != null) {
            state = AuthState(
              user: authState.session!.user,
              isLoading: false,
              isRecoveryMode: true,
            );
          }
        } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
          final newUser = authState.session?.user;
          if (newUser != null) {
            final isSameUser = state.user?.id == newUser.id;
            final hasProfile = state.profile != null;
            if (state.isLoading || (isSameUser && hasProfile)) {
              print('[AUTH] Skipping redundant profile load (isLoading: ${state.isLoading}, sameUser: $isSameUser, hasProfile: $hasProfile)');
              // Ensure we still update the user object if it changed
              if (state.user != newUser && !state.isLoading) {
                state = state.copyWith(user: newUser);
              }
              return;
            }
            final isRecovery = state.isRecoveryMode || isRecoveryPathCurrent;
            await _loadProfile(newUser, isRecoveryMode: isRecovery).timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                print('[AUTH] _loadProfile listener timed out');
                if (state.profile == null) {
                  state = AuthState(
                    user: newUser,
                    isLoading: false,
                    isRecoveryMode: isRecovery,
                    error: 'Profile load timeout',
                  );
                }
              },
            );
          }
        } else if (event == AuthChangeEvent.signedOut) {
          state = const AuthState(isLoading: false);
        }
      });
    } catch (e) {
      print('[AUTH] Error during _init: $e');
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> _autoAcceptGatesForSignIn(String userId) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      final currentProfile = await _authService.fetchProfile(userId);
      final currentPrefs = Map<String, dynamic>.from(currentProfile?['preferences'] ?? {});

      bool updated = false;
      if (currentPrefs['tos_version_accepted'] != '1.0') {
        currentPrefs['tos_accepted_at'] = nowStr;
        currentPrefs['tos_version_accepted'] = '1.0';
        updated = true;
      }
      if (currentPrefs['consents'] == null) {
        currentPrefs['consents'] = {
          'essential': {'granted': true, 'timestamp': nowStr},
          'location': {'granted': true, 'timestamp': nowStr},
          'analytics': {'granted': true, 'timestamp': nowStr},
          'marketing': {'granted': false, 'timestamp': nowStr},
        };
        updated = true;
      }

      if (updated) {
        final updates = <String, dynamic>{
          'preferences': currentPrefs,
        };
        await SupabaseService.client.from('profiles').update(updates).eq('id', userId);
        print('[AUTH] Auto-completed sign-in legal consent gates on DB for user: $userId');
      }

      final onboardingAlreadyComplete = currentProfile?['onboarding_complete'] == true;
      if (onboardingAlreadyComplete) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete_$userId', true);
        await prefs.setBool('first_time_tour_shown_$userId', true);
      }
    } catch (e) {
      print('[AUTH] Error auto-accepting onboarding gates for sign-in: $e');
    }
  }

  Future<void> _loadProfile(User user, {bool isRecoveryMode = false}) async {
    // If we don't have a profile in state, try reading cache first to avoid flashing loading
    if (state.profile == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedProfileStr = prefs.getString('cached_profile_${user.id}');
        if (cachedProfileStr != null) {
          final cachedProfile = jsonDecode(cachedProfileStr) as Map<String, dynamic>;
          final cachedRole = cachedProfile['role'] as String?;
          final cachedOnboarding = prefs.getBool('onboarding_complete_${user.id}') ?? (cachedProfile['onboarding_complete'] == true);
          state = state.copyWith(
            user: user,
            profile: cachedProfile,
            role: cachedRole,
            isLoading: false,
            isOnboardingComplete: cachedOnboarding,
            isTwoFactorVerified: !(cachedProfile['totp_enabled'] == true),
          );
        }
      } catch (e) {
        print('[AUTH] Error loading cached profile in _loadProfile: $e');
      }
    }

    state = state.copyWith(isLoading: state.profile == null, error: null);
    try {
      final profile = await _authService.fetchProfile(user.id);
      
      Map<String, dynamic>? activeProfile = profile;
      if (activeProfile != null && activeProfile['account_status'] == 'suspended') {
        final untilStr = activeProfile['suspension_until'] as String?;
        if (untilStr != null) {
          final until = DateTime.tryParse(untilStr);
          if (until != null && until.isBefore(DateTime.now())) {
            try {
              // Suspension expired! Update DB status to active
              await SupabaseService.client.from('profiles').update({
                'account_status': 'active',
                'suspension_reason': null,
                'suspension_until': null,
              }).eq('id', user.id);
              
              // Refetch profile
              activeProfile = await _authService.fetchProfile(user.id);
              print('[AUTH] Account suspension expired. Automatically unsuspended user: ${user.id}');
            } catch (e) {
              print('[AUTH] Error auto-reversing expired suspension: $e');
            }
          }
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      if (activeProfile != null) {
        await prefs.setString('cached_profile_${user.id}', jsonEncode(activeProfile));
      }
      // Cache the access token in SharedPreferences so the background notification
      // reply isolate can authenticate (SecureLocalStorage doesn't work in background isolates)
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        await prefs.setString('bg_access_token', session.accessToken);
        await prefs.setString('bg_user_id', user.id);
      }
      final localComplete = prefs.getBool('onboarding_complete_${user.id}') ?? false;
      final bio = activeProfile?['bio']?.toString().trim();
      final hasBio = bio != null && bio.isNotEmpty;
      final isComplete = (activeProfile?['onboarding_complete'] == true) ||
                         (activeProfile?['onboarding_complete'] == null && hasBio) ||
                         localComplete;
      if (isComplete && !localComplete) {
        await prefs.setBool('onboarding_complete_${user.id}', true);
      }

      final totpEnabled = activeProfile?['totp_enabled'] == true;
      state = AuthState(
        user: user,
        profile: activeProfile,
        role: activeProfile?['role'] as String?,
        isLoading: false,
        isRecoveryMode: isRecoveryMode,
        isOnboardingComplete: isComplete,
        isTwoFactorVerified: !totpEnabled,
      );

      if (activeProfile != null && activeProfile['role'] == 'influencer') {
        unawaited(SocialAgent.syncFollowersIfNecessary(user.id, activeProfile).catchError((_) {}));
      }
    } catch (e) {
      // HARDENING: sec-agent 2026-06-24
      if (SessionGuard.isSessionException(e)) {
        await signOut();
        state = const AuthState(
          isLoading: false,
          error: 'Session expired. Please sign in again.',
        );
        return;
      }

      bool localComplete = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        localComplete = prefs.getBool('onboarding_complete_${user.id}') ?? false;
      } catch (_) {}

      state = AuthState(
        user: user,
        isLoading: false,
        error: AppErrorHandler.toUserMessage(e),
        isRecoveryMode: isRecoveryMode,
        isOnboardingComplete: localComplete,
      );
    }
  }

  Future<String?> signInWithGoogle({required String idToken, String? accessToken}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      if (response.user != null) {
        await _autoAcceptGatesForSignIn(response.user!.id);
        await _loadProfile(response.user!);
        return state.role;
      }
      state = state.copyWith(isLoading: false, error: 'Sign in failed. Please try again.');
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserMessage(e));
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserMessage(e));
      return null;
    }
  }

  Future<String?> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    print('[AUTH] signIn called with email: $email');
    try {
      final response = await _authService.signIn(email: email, password: password);
      print('[AUTH] signIn response user: ${response.user?.id}');
      if (response.user != null) {
        await _autoAcceptGatesForSignIn(response.user!.id);
        await _loadProfile(response.user!);
        print('[AUTH] profile loaded, role: ${state.role}, error: ${state.error}');
        return state.role;
      }
      print('[AUTH] signIn: response.user was null');
      state = state.copyWith(isLoading: false, error: 'Sign in failed. Please try again.');
      return null;
    } on AuthException catch (e) {
      print('[AUTH] AuthException: ${e.message} (statusCode: ${e.statusCode})');
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserMessage(e));
      return null;
    } catch (e) {
      print('[AUTH] Unexpected error: $e');
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserMessage(e));
      return null;
    }
  }

  Future<String?> signUp(String email, String password, Map<String, dynamic> metadata) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authService.signUp(email: email, password: password, metadata: metadata);
      if (response.user != null) {
        // Wait for profile trigger to complete
        await Future.delayed(const Duration(seconds: 1));
        await _loadProfile(response.user!);
        return metadata['role'] as String?;
      }
      state = state.copyWith(isLoading: false, error: 'Sign up failed. Please try again.');
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserMessage(e));
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserMessage(e));
      return null;
    }
  }

  Future<void> signOut() async {
    final userId = state.user?.id;
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_profile_$userId');
        await prefs.remove('onboarding_complete_$userId');
        await prefs.remove('bg_access_token');
        await prefs.remove('bg_user_id');
      } catch (e) {
        print('[AUTH] Error clearing cache on signOut: $e');
      }

      // Delete push token from DB while still authenticated
      if (!kIsWeb) {
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            print('[AUTH] Deleting FCM Token on sign-out: $fcmToken');
            await SupabaseService.client
                .from('user_push_tokens')
                .delete()
                .eq('fcm_token', fcmToken);
          }
        } catch (e) {
          print('[AUTH] Error deleting FCM token on sign-out: $e');
        }
      }
    }
    try {
      if (!kIsWeb) {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (e) {
      print('Google signout error: $e');
    }
    try {
      await _authService.signOut();
    } catch (e) {
      print('Supabase signout error: $e');
    }
    state = const AuthState(isLoading: false);
  }

  Future<void> validateSession() async {
    final user = state.user;
    if (user == null) return;

    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null && session.isExpired) {
        try {
          await SupabaseService.client.auth.refreshSession();
        } catch (_) {
          throw AuthException('Session expired. Please sign in again.');
        }
      }
      await SupabaseService.client.auth.getUser();
    } on AuthException catch (ae) {
      final msg = ae.message.toLowerCase();
      if (msg.contains('invalid_grant') || 
          msg.contains('jwt expired') || 
          msg.contains('session expired') || 
          msg.contains('session_not_found') ||
          msg.contains('refresh_token_not_found')) {
        print('[AUTH] AuthException session expired on app resume: $msg');
        await signOut();
        state = const AuthState(
          isLoading: false,
          error: 'Session expired. Please sign in again.',
        );
      }
    } catch (e) {
      print('[AUTH] Non-auth error during session validation: $e');
    }
  }

  Future<void> deleteAccount() async {
    final userId = state.user?.id;
    if (userId == null) return;

    // 1. Mark account as deleted in database (soft deletion request)
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      print('[AUTH] Error during account soft deletion: $e');
    }

    // 2. Clear Shared Preferences local cache for user
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_profile_$userId');
      await prefs.remove('onboarding_complete_$userId');
      await prefs.remove('first_open_date_$userId');
      await prefs.remove('biometric_lock_enabled');
      await prefs.remove('push_notifications_asked');
      await prefs.remove('push_notifications_enabled');
    } catch (e) {
      print('[AUTH] Error clearing preferences: $e');
    }

    // 3. Sign out
    try {
      await _authService.signOut();
    } catch (_) {}
    state = const AuthState(isLoading: false);
  }

  void clearRecoveryMode() {
    state = state.copyWith(isRecoveryMode: false);
  }

  Future<void> refreshProfile() async {
    if (state.user != null) {
      await _loadProfile(state.user!);
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> newPrefs) async {
    final user = state.user;
    if (user == null) return;
    try {
      await SupabaseService.client.from('profiles').update({
        'preferences': newPrefs,
      }).eq('id', user.id);
      
      final updatedProfile = Map<String, dynamic>.from(state.profile ?? {});
      updatedProfile['preferences'] = newPrefs;
      state = state.copyWith(profile: updatedProfile);
    } catch (e) {
      print('Error updating preferences: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
  bool verifyTwoFactorCode(String code) {
    final secret = state.profile?['totp_secret'] as String?;
    if (secret == null) {
      state = state.copyWith(isTwoFactorVerified: true);
      return true;
    }

    final isValid = TotpHelper.verifyCode(secret, code);
    if (isValid) {
      state = state.copyWith(isTwoFactorVerified: true);
      return true;
    }
    return false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

final splashCompletedProvider = StateProvider<bool>((ref) => false);

final hideBottomNavProvider = StateProvider<bool>((ref) => false);

// ---------- Notification Count Provider ----------

class UnreadNotificationCountNotifier extends StateNotifier<int> {
  final String? userId;
  RealtimeChannel? _subscription;

  UnreadNotificationCountNotifier(this.userId) : super(0) {
    if (userId != null) {
      _init();
    }
  }

  void _init() {
    _fetchCount();
    try {
      final channel = NotificationService().subscribeToNotifications(
        userId!,
        () {
          _fetchCount();
        },
      );
      _subscription = channel;
      RealtimeSubscriptionManager.subscribe('notifications:$userId', channel);
    } catch (e) {
      print('Error subscribing to notifications count: $e');
    }
  }

  Future<void> _fetchCount() async {
    final uid = userId;
    if (uid == null) return;
    try {
      final count = await NotificationService().getUnreadCount(uid);
      if (mounted) {
        state = count;
      }
    } catch (e) {
      print('Error fetching unread notification count: $e');
    }
  }

  void updateCount(int count) {
    if (mounted) {
      state = count;
    }
  }

  @override
  void dispose() {
    if (userId != null) {
      RealtimeSubscriptionManager.unsubscribe('notifications:$userId');
    }
    super.dispose();
  }
}

final unreadNotificationCountProvider = StateNotifierProvider<UnreadNotificationCountNotifier, int>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return UnreadNotificationCountNotifier(userId);
});
class UnreadMessageCountNotifier extends StateNotifier<int> {
  final String? userId;
  RealtimeChannel? _subscription;

  UnreadMessageCountNotifier(this.userId) : super(0) {
    if (userId != null) {
      _init();
    }
  }

  void _init() {
    _fetchCount();

    // Subscribe to all changes in public:messages to keep unread counts in sync
    try {
      _subscription = SupabaseService.client
          .channel('unread_messages_count:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              _fetchCount();
            },
          );
      RealtimeSubscriptionManager.subscribe('unread_messages_count:$userId', _subscription!);
    } catch (e) {
      print('Error subscribing to unread messages count: $e');
    }
  }

  Future<void> _fetchCount() async {
    final uid = userId;
    if (uid == null) return;
    try {
      final count = await ChatService().getUnreadMessageCount(uid);
      if (mounted) {
        state = count;
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
  }

  @override
  void dispose() {
    if (userId != null) {
      RealtimeSubscriptionManager.unsubscribe('unread_messages_count:$userId');
    }
    super.dispose();
  }
}

final unreadMessageCountProvider = StateNotifierProvider<UnreadMessageCountNotifier, int>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return UnreadMessageCountNotifier(userId);
});

// ---------- Navigation Provider ----------

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ---------- Pinned Rooms Provider ----------

final pinnedRoomsProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(authProvider.select((s) => s.profile));
  final prefs = profile?['preferences'] as Map<String, dynamic>?;
  return List<String>.from(prefs?['pinned_rooms'] ?? []);
});

final archivedRoomsProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(authProvider.select((s) => s.profile));
  final prefs = profile?['preferences'] as Map<String, dynamic>?;
  return List<String>.from(prefs?['archived_rooms'] ?? []);
});

final mutedRoomsProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(authProvider.select((s) => s.profile));
  final prefs = profile?['preferences'] as Map<String, dynamic>?;
  return List<String>.from(prefs?['muted_rooms'] ?? []);
});

final unreadOverridesProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(authProvider.select((s) => s.profile));
  final prefs = profile?['preferences'] as Map<String, dynamic>?;
  return List<String>.from(prefs?['unread_overrides'] ?? []);
});

// ---------- Theme Provider (Persisted) ----------

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      if (value == 'dark') {
        state = ThemeMode.dark;
      } else if (value == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.system) {
        await prefs.setString(_key, 'system');
      } else {
        await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
      }
    } catch (_) {}
  }

  void toggle() {
    if (state == ThemeMode.system) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class BiometricLockNotifier extends StateNotifier<bool> {
  static const _key = 'biometric_lock_enabled';

  BiometricLockNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {}
  }
}

final biometricLockProvider = StateNotifierProvider<BiometricLockNotifier, bool>(
  (ref) => BiometricLockNotifier(),
);