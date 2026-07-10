/// ContentSanitizer provides utilities to strip out dangerous script and HTML tags
/// from inputs to prevent Cross-Site Scripting (XSS).
class ContentSanitizer {
  ContentSanitizer._();

  /// Strip all HTML tags, events, and javascript links from user input.
  static String sanitizeText(String input) {
    // 1. Remove HTML tags
    String clean = input.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // 2. Remove script links
    clean = clean.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    
    // 3. Remove script triggers/events
    clean = clean.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
    
    // 4. Escape special HTML entities
    clean = clean
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');

    return clean.trim();
  }

  /// Sanitizes and validates a URL, returning null if insecure.
  static String? sanitizeUrl(String input) {
    final trimmed = input.trim();
    if (!trimmed.toLowerCase().startsWith('https://')) {
      return null;
    }
    return trimmed;
  }
}
