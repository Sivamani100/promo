import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

import '../security/session_guard.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({required String email, required String password}) async {
    // HARDENING: sec-agent 2026-06-24
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    await SessionGuard.updateActivity();
    return response;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    // HARDENING: sec-agent 2026-06-24
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
    await SessionGuard.updateActivity();
    return response;
  }

  Future<void> signOut() async {
    // HARDENING: sec-agent 2026-06-24
    await SessionGuard.clearActivity();
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    final redirectUrl = kIsWeb ? '${Uri.base.origin}/' : null;
    if (kDebugMode) {
      debugPrint('[AUTH] resetPassword for $email with redirectTo: $redirectUrl');
    }
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
  }

  Future<AuthSessionUrlResponse> exchangeCodeForSession(String code) async {
    return await _client.auth.exchangeCodeForSession(code);
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    // HARDENING: sec-agent 2026-06-24
    final response = await _client.auth.updateUser(UserAttributes(password: newPassword));
    await _client.auth.signOut(scope: SignOutScope.global);
    await SessionGuard.clearActivity();
    return response;
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    return response;
  }

  Future<String?> getUserRole(String userId) async {
    final profile = await fetchProfile(userId);
    return profile?['role'] as String?;
  }
}