import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// SecureLocalStorage encrypts authentication tokens using Keychain/Keystore.
/// It also migrates existing sessions from SharedPreferences (if any) to prevent logging out users.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _sessionKey = 'supabase.auth.token';

  @override
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_sessionKey)) {
        final legacySession = prefs.getString(_sessionKey);
        if (legacySession != null && legacySession.isNotEmpty) {
          await _secureStorage.write(key: _sessionKey, value: legacySession);
          debugPrint('[SECURE_STORAGE] Successfully migrated session from SharedPreferences.');
        }
        await prefs.remove(_sessionKey);
      }
    } catch (e) {
      debugPrint('[SECURE_STORAGE] Failed to migrate session: $e');
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _secureStorage.read(key: _sessionKey);
    } catch (e) {
      debugPrint('[SECURE_STORAGE] Error reading token: $e');
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _secureStorage.containsKey(key: _sessionKey);
    } catch (e) {
      debugPrint('[SECURE_STORAGE] Error checking token: $e');
      return false;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _secureStorage.write(key: _sessionKey, value: persistSessionString);
    } catch (e) {
      debugPrint('[SECURE_STORAGE] Error saving session: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('[SECURE_STORAGE] Error deleting session: $e');
    }
  }
}
