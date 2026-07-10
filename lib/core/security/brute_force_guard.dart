import 'package:flutter/foundation.dart';

/// BruteForceGuard provides client-side progressive login attempt tracking.
///
/// Security tiers per the MNC security spec:
/// - 3 failed attempts  → enforce 30-second delay before next attempt
/// - 5 failed attempts  → require email verification (shows warning)
/// - 10 failed attempts → account locked, user must wait 1 hour
///
/// This is a client-side guard. The server-side `login_attempts` table in
/// Supabase provides additional IP-level rate limiting and permanent bans
/// enforced through the `record_login_attempt` database RPC function.
class BruteForceGuard {
  BruteForceGuard._();

  /// Per-email attempt tracking: email → list of attempt timestamps
  static final Map<String, List<DateTime>> _attempts = {};

  /// Time when a given email becomes unlocked after max attempts
  static final Map<String, DateTime> _lockUntil = {};

  /// Thresholds per MNC security specification
  static const int _delayThreshold = 3;
  static const int _warningThreshold = 5;
  static const int _lockThreshold = 10;
  static const Duration _lockDuration = Duration(hours: 1);
  static const Duration _delayDuration = Duration(seconds: 30);
  static const Duration _windowDuration = Duration(minutes: 15);

  /// Records a failed login attempt for [email].
  /// Returns the [LoginAttemptResult] describing what action to take.
  static LoginAttemptResult recordFailure(String email) {
    _pruneOldAttempts(email);

    final attempts = _attempts[email] ??= [];
    attempts.add(DateTime.now());

    final count = attempts.length;
    debugPrint('[BRUTE_FORCE] Failed attempt #$count for $email');

    if (count >= _lockThreshold) {
      final lockUntil = DateTime.now().add(_lockDuration);
      _lockUntil[email] = lockUntil;
      _attempts.remove(email); // Reset counter after lock
      return LoginAttemptResult.locked(lockUntil);
    }

    if (count >= _warningThreshold) {
      return LoginAttemptResult.requireVerification(count);
    }

    if (count >= _delayThreshold) {
      return LoginAttemptResult.delayed(_delayDuration, count);
    }

    return LoginAttemptResult.allowed(count);
  }

  /// Records a successful login and clears the attempt history for [email].
  static void recordSuccess(String email) {
    _attempts.remove(email);
    _lockUntil.remove(email);
    debugPrint('[BRUTE_FORCE] Successful login, cleared attempt history for $email');
  }

  /// Checks whether [email] is currently locked or in a delay period.
  /// Returns null if allowed, or a [LoginAttemptResult] describing the block.
  static LoginAttemptResult? checkStatus(String email) {
    // Check hard lock
    final lockUntil = _lockUntil[email];
    if (lockUntil != null) {
      if (DateTime.now().isBefore(lockUntil)) {
        return LoginAttemptResult.locked(lockUntil);
      } else {
        // Lock expired — clear it
        _lockUntil.remove(email);
      }
    }

    _pruneOldAttempts(email);
    final count = (_attempts[email] ?? []).length;

    if (count == 0) return null;

    if (count >= _warningThreshold) {
      return LoginAttemptResult.requireVerification(count);
    }

    if (count >= _delayThreshold) {
      final lastAttempt = (_attempts[email]!).last;
      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      if (timeSinceLastAttempt < _delayDuration) {
        final remaining = _delayDuration - timeSinceLastAttempt;
        return LoginAttemptResult.delayed(remaining, count);
      }
    }

    return null;
  }

  /// How many seconds remain before the next attempt is allowed (0 if none).
  static int remainingDelaySeconds(String email) {
    final result = checkStatus(email);
    if (result == null) return 0;
    return result.delayRemaining?.inSeconds ?? 0;
  }

  /// Removes attempts outside the 15-minute rolling window.
  static void _pruneOldAttempts(String email) {
    final cutoff = DateTime.now().subtract(_windowDuration);
    _attempts[email]?.removeWhere((t) => t.isBefore(cutoff));
    if (_attempts[email]?.isEmpty ?? false) {
      _attempts.remove(email);
    }
  }
}

/// Result of a brute force check describing what action to take in the UI.
class LoginAttemptResult {
  final LoginBlockType type;
  final int attemptCount;
  final DateTime? lockedUntil;
  final Duration? delayRemaining;

  const LoginAttemptResult._({
    required this.type,
    this.attemptCount = 0,
    this.lockedUntil,
    this.delayRemaining,
  });

  factory LoginAttemptResult.allowed(int count) => LoginAttemptResult._(
        type: LoginBlockType.allowed,
        attemptCount: count,
      );

  factory LoginAttemptResult.delayed(Duration delay, int count) =>
      LoginAttemptResult._(
        type: LoginBlockType.delayed,
        attemptCount: count,
        delayRemaining: delay,
      );

  factory LoginAttemptResult.requireVerification(int count) =>
      LoginAttemptResult._(
        type: LoginBlockType.requireVerification,
        attemptCount: count,
      );

  factory LoginAttemptResult.locked(DateTime until) => LoginAttemptResult._(
        type: LoginBlockType.locked,
        lockedUntil: until,
      );

  bool get isBlocked => type != LoginBlockType.allowed;

  /// Human-readable message for the UI to display.
  String get message {
    switch (type) {
      case LoginBlockType.delayed:
        final secs = delayRemaining?.inSeconds ?? 0;
        return 'Too many failed attempts. Please wait ${secs}s before trying again.';
      case LoginBlockType.requireVerification:
        return 'Multiple failed attempts detected. Check your email for a verification link.';
      case LoginBlockType.locked:
        final mins = lockedUntil?.difference(DateTime.now()).inMinutes ?? 60;
        return 'Account temporarily locked due to too many failed attempts. Try again in ${mins > 0 ? mins : 1} minute(s).';
      case LoginBlockType.allowed:
        return '';
    }
  }
}

enum LoginBlockType { allowed, delayed, requireVerification, locked }
