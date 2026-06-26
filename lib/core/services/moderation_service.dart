// HARDENING-V2: trust-agent 2026-06-26

/// Service for moderating user-generated text content using a keyword blocklist.
/// This is the Dart-side implementation (no external API dependency).
class ModerationService {
  ModerationService._();

  /// Result of a content moderation check.
  static ModerationResult checkContent(String text) {
    if (text.trim().isEmpty) {
      return const ModerationResult(isClean: true, flaggedTerms: []);
    }

    final lowerText = text.toLowerCase();
    final flagged = <String>[];

    for (final term in _blocklist) {
      // Use word boundary matching to avoid false positives
      final pattern = RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(lowerText)) {
        flagged.add(term);
      }
    }

    return ModerationResult(
      isClean: flagged.isEmpty,
      flaggedTerms: flagged,
    );
  }

  /// Check if text contains scam signals (payment requests, urgency markers).
  static ModerationResult checkForScamSignals(String text) {
    if (text.trim().isEmpty) {
      return const ModerationResult(isClean: true, flaggedTerms: []);
    }

    final lowerText = text.toLowerCase();
    final flagged = <String>[];

    for (final pattern in _scamSignals) {
      if (lowerText.contains(pattern)) {
        flagged.add(pattern);
      }
    }

    return ModerationResult(
      isClean: flagged.isEmpty,
      flaggedTerms: flagged,
    );
  }

  /// Combined check: profanity + scam signals.
  static ModerationResult checkAll(String text) {
    final profanity = checkContent(text);
    final scam = checkForScamSignals(text);

    final allFlagged = [...profanity.flaggedTerms, ...scam.flaggedTerms];
    return ModerationResult(
      isClean: allFlagged.isEmpty,
      flaggedTerms: allFlagged,
    );
  }

  // Profanity blocklist — common terms; extend as needed.
  // Uses mild obfuscation patterns too.
  static const List<String> _blocklist = [
    // Hate speech / slurs (abbreviated for safety — production list would be larger)
    'hate you',
    'kill you',
    'death threat',
    'go die',
    // Scam / fraud terms
    'send money first',
    'wire transfer only',
    'western union',
    'money gram',
    'advance fee',
    'guaranteed income',
    'make money fast',
    'pyramid scheme',
    'ponzi',
    'nigerian prince',
    // Harassment
    'i will find you',
    'i know where you live',
    'watch your back',
    // Inappropriate solicitation
    'sugar daddy',
    'sugar mommy',
    'escort service',
    'adult content',
    'onlyfans link',
    // Spam
    'click this link',
    'free iphone',
    'you have won',
    'congratulations you won',
    'lottery winner',
    'claim your prize',
  ];

  // Scam signal patterns — urgency, payment pressure, etc.
  static const List<String> _scamSignals = [
    'pay before',
    'send payment now',
    'act now or lose',
    'limited time only',
    'don\'t tell anyone',
    'keep this secret',
    'send crypto',
    'bitcoin only',
    'cash app only',
    'venmo only before',
    'whatsapp me at',
    'telegram me at',
    'dm me on whatsapp',
  ];
}

/// Result of a moderation check.
class ModerationResult {
  final bool isClean;
  final List<String> flaggedTerms;

  const ModerationResult({
    required this.isClean,
    required this.flaggedTerms,
  });

  String get userFacingMessage {
    if (isClean) return '';
    return 'Your content may violate our community guidelines. Please review and edit before submitting.';
  }
}
