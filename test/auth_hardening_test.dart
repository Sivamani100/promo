import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:brand_mobile_app/core/utils/error_handler.dart';
import 'package:brand_mobile_app/core/security/session_guard.dart';

void main() {
  group('Auth Hardening - AppErrorHandler.toUserMessage', () {
    test('Maps wrong credentials to Incorrect email or password', () {
      final exc = AuthException('invalid_credentials', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc), 'Incorrect email or password.');

      final exc2 = AuthException('Invalid login credentials', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc2), 'Incorrect email or password.');
    });

    test('Maps Google ID token / OAuth failures to Google auth failed message', () {
      final exc = AuthException('invalid_grant: Token signature is invalid', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc), 'Google authentication failed. Please try again.');

      final exc2 = AuthException('invalid_grant: id_token is expired', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc2), 'Google authentication failed. Please try again.');

      final exc3 = AuthException('invalid_audience: The audience is invalid', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc3), 'Google authentication failed. Please try again.');
    });

    test('Maps actual session/refresh token expirations to Session expired message', () {
      final exc = AuthException('session_not_found', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc), 'Session expired. Please sign in again.');

      final exc2 = AuthException('refresh_token_not_found', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc2), 'Session expired. Please sign in again.');

      final exc3 = AuthException('Invalid refresh token', statusCode: '400');
      expect(AppErrorHandler.toUserMessage(exc3), 'Session expired. Please sign in again.');
    });
  });

  group('Auth Hardening - SessionGuard.isSessionException', () {
    test('Ignores general credential/login failures', () {
      final exc = AuthException('Invalid login credentials', statusCode: '400');
      expect(SessionGuard.isSessionException(exc), isFalse);

      final exc2 = AuthException('invalid_credentials', statusCode: '400');
      expect(SessionGuard.isSessionException(exc2), isFalse);
    });

    test('Matches actual session/refresh token expirations', () {
      final exc = AuthException('session_not_found', statusCode: '400');
      expect(SessionGuard.isSessionException(exc), isTrue);

      final exc2 = AuthException('refresh_token_not_found', statusCode: '400');
      expect(SessionGuard.isSessionException(exc2), isTrue);

      final exc3 = AuthException('invalid refresh token', statusCode: '400');
      expect(SessionGuard.isSessionException(exc3), isTrue);
    });
  });
}
