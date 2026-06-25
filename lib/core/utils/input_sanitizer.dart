// HARDENING: sec-agent 2026-06-24
class InputSanitizer {
  // Strip HTML/script tags from text inputs and truncate
  static String sanitizeText(String input, {int maxLength = 2000}) {
    String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), ''); // Strip HTML tags
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    return sanitized.trim();
  }
  
  // Validate URLs before storing
  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }
  
  // Sanitize display names — no special chars that could cause display issues
  static String sanitizeName(String input, {int maxLength = 50}) {
    String sanitized = input.replaceAll(RegExp(r'[^\w\s\-\.\@]'), ''); // Allow alphanumeric, spaces, hyphens, dots, @
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    return sanitized.trim();
  }
  
  // Clamp follower counts to valid range
  static int clampFollowerCount(int count) {
    if (count < 0) return 0;
    // Hard limit of 10 billion followers for sanity
    if (count > 10000000000) return 10000000000;
    return count;
  }
  
  // Validate budget strings — only numbers, commas, currency symbols, and spaces
  static String sanitizeBudget(String input, {int maxLength = 30}) {
    String sanitized = input.replaceAll(RegExp(r'[^\d\s\,\-\.\$\€\£\¥]'), '');
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    return sanitized.trim();
  }
}
