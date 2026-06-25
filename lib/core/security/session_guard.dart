// HARDENING: sec-agent 2026-06-24
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionGuard {
  static const String _keyLastActivity = 'last_session_activity';
  
  // Update last activity timestamp to current time
  static Future<void> updateActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Suppress logging in production
    }
  }
  
  // Verify session validity. Returns false if session expired due to inactivity (>7 days)
  static Future<bool> isSessionValid() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final lastActivity = prefs.getInt(_keyLastActivity);
      if (lastActivity == null) {
        // First time tracking activity after hardening. Initialize it.
        await updateActivity();
        return true;
      }
      
      final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastActivity));
      if (diff.inDays >= 7) {
        return false;
      }
      
      await updateActivity();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Clears the activity tracker on sign out
  static Future<void> clearActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastActivity);
    } catch (_) {}
  }

  // Detect session expired or session not found exceptions
  // HARDENING: sec-agent 2026-06-25 - Prevent OAuth and credentials errors from triggering session expiration
  static bool isSessionException(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final code = error.statusCode;
      
      // Do NOT classify general credential/login failures as session expired
      if (msg.contains('invalid login credentials') || 
          msg.contains('invalid_credentials') ||
          msg.contains('user_not_found') || 
          msg.contains('user not found')) {
        return false;
      }
      
      return msg.contains('session_not_found') || 
             msg.contains('refresh_token_not_found') || 
             msg.contains('invalid refresh token') ||
             msg.contains('refresh token is invalid') ||
             code == 'session_not_found' ||
             error.toString().contains('session_not_found');
    }
    return false;
  }
}
