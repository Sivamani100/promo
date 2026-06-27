// HARDENING: sec-agent 2026-06-24
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppErrorHandler {
  // Maps internal errors to user-friendly messages
  static String toUserMessage(dynamic error) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('500') || errStr.contains('status: 500') || errStr.contains('internal server error')) {
      return 'Server error. Please try again in a moment.';
    }
    if (errStr.contains('422') || errStr.contains('status: 422')) {
      return 'Something went wrong. Please try again.';
    }

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid_credentials') || msg.contains('invalid login credentials')) {
        return 'Incorrect email or password.';
      }
      if (msg.contains('email_not_confirmed') || msg.contains('email not confirmed')) {
        return 'Please verify your email first.';
      }
      if (msg.contains('user_not_found') || msg.contains('user not found')) {
        return 'No account found with that email.';
      }
      if (msg.contains('invalid_grant')) {
        return 'Session expired. Please sign in again.';
      }
      if (msg.contains('jwt expired')) {
        return "You've been signed out. Please log in again.";
      }
      // Precise checks for actual session / refresh token expiration
      if (msg.contains('session_not_found') || 
          msg.contains('refresh_token_not_found') || 
          msg.contains('invalid refresh token') ||
          msg.contains('refresh token is invalid') ||
          msg.contains('session expired')) {
        return 'Session expired. Please sign in again.';
      }
      
      // Google ID token validation failures or OAuth errors should return a friendly error message, NOT "Session expired"
      if (msg.contains('id_token') || 
          msg.contains('id token') || 
          msg.contains('oauth') || 
          msg.contains('google') ||
          msg.contains('token signature') ||
          msg.contains('invalid token') ||
          msg.contains('invalid id token')) {
        return 'Google authentication failed. Please try again.';
      }
      
      return error.message; // AuthExceptions are usually user-facing already, but we guard them
    }
    
    if (error is PostgrestException) {
      // NEVER expose SQL/DB internals to users
      // Map common Postgres error codes
      final code = error.code;
      final msg = error.message.toLowerCase();
      if (code == '23505' || msg.contains('duplicate key value') || msg.contains('duplicate key')) {
        return 'This already exists.';
      }
      if (code == '42501') {
        return "You don't have permission to do this.";
      }
      return 'Something went wrong. Please try again.';
    }
    
    if (error is StorageException) {
      return 'File upload failed. Please try again.';
    }
    
    if (errStr.contains('timeout') || errStr.contains('connection timed out') || errStr.contains('deadline')) {
      return 'Connection timed out. Please try again.';
    }
    if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    
    // HARDENING: devops-agent 2026-06-25
    if (errStr.contains('unexpected end of json input') || errStr.contains('syntaxerror') || errStr.contains('formatexception')) {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (url.isEmpty || key.isEmpty) {
        return 'Configuration Error: Environment variables are not set. Please launch the app using compile-time defines (e.g. make dev).';
      }
      return 'Server response error. Please try again.';
    }
    
    return 'Something went wrong. Please try again.';
  }
  
  // Internal logging — never shown to user
  static void logError(String context, dynamic error, [StackTrace? stack]) {
    if (kDebugMode) {
      print('[ERROR][$context] $error');
      if (stack != null) {
        print(stack);
      }
    }
    // HARDENING: observability-agent 2026-06-24
    try {
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('context', context);
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ERROR] Sentry failed to capture exception: $e');
      }
    }
  }
}
