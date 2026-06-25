import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/chat_service.dart';
import '../services/social_agent.dart';
import '../services/notification_service.dart';
import '../security/session_guard.dart';
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

  const AuthState({
    this.user,
    this.profile,
    this.role,
    this.isLoading = true,
    this.error,
    this.isRecoveryMode = false,
    this.isOnboardingComplete = false,
  });

  AuthState copyWith({
    User? user,
    Map<String, dynamic>? profile,
    String? role,
    bool? isLoading,
    String? error,
    bool? isRecoveryMode,
    bool? isOnboardingComplete,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRecoveryMode: isRecoveryMode ?? this.isRecoveryMode,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
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
          );
        }
      } catch (e) {
        print('[AUTH] Error loading cached profile in _loadProfile: $e');
      }
    }

    state = state.copyWith(isLoading: state.profile == null, error: null);
    try {
      final profile = await _authService.fetchProfile(user.id);
      
      final prefs = await SharedPreferences.getInstance();
      if (profile != null) {
        await prefs.setString('cached_profile_${user.id}', jsonEncode(profile));
      }
      final localComplete = prefs.getBool('onboarding_complete_${user.id}') ?? false;
      final bio = profile?['bio']?.toString().trim();
      final hasBio = bio != null && bio.isNotEmpty;
      final isComplete = (profile?['onboarding_complete'] == true) ||
                         (profile?['onboarding_complete'] == null && hasBio) ||
                         localComplete;
      if (isComplete && !localComplete) {
        await prefs.setBool('onboarding_complete_${user.id}', true);
      }

      state = AuthState(
        user: user,
        profile: profile,
        role: profile?['role'] as String?,
        isLoading: false,
        isRecoveryMode: isRecoveryMode,
        isOnboardingComplete: isComplete,
      );

      if (profile != null && profile['role'] == 'influencer') {
        unawaited(SocialAgent.syncFollowersIfNecessary(user.id, profile).catchError((_) {}));
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
      } catch (e) {
        print('[AUTH] Error clearing cache on signOut: $e');
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
      _subscription = NotificationService().subscribeToNotifications(
        userId!,
        () {
          _fetchCount();
        },
      );
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
    if (_subscription != null) {
      try {
        SupabaseService.client.removeChannel(_subscription!);
      } catch (e) {
        print('Error removing notification channel: $e');
      }
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
          )
          .subscribe();
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
    if (_subscription != null) {
      SupabaseService.client.removeChannel(_subscription!);
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

  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      if (value == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.light;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);