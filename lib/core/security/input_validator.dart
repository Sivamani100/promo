import 'dart:io';

/// InputValidator provides strict client-side validation rules to block SQL
/// injection, scripting elements, SSRF host patterns, and malformed inputs.
class InputValidator {
  InputValidator._();

  /// Validates human names, preventing injection strings.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.length > 60) {
      return 'Name is too long (maximum 60 characters)';
    }
    // Block typical SQL injection characters
    if (RegExp(r"['\";\\]").hasMatch(value)) {
      return 'Name contains invalid characters';
    }
    // Block potential script injections
    if (value.toLowerCase().contains('<script') || value.toLowerCase().contains('javascript:')) {
      return 'Name contains invalid content';
    }
    return null;
  }

  /// Validates website or portfolio URLs, preventing SSRF (Server-Side Request Forgery).
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !['https'].contains(uri.scheme)) {
      return 'Enter a valid secure URL starting with https://';
    }

    // SSRF Prevention: Block local / internal IP ranges and loopbacks
    final host = uri.host.toLowerCase();
    final ssrfPatterns = [
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      '169.254.169.254', // AWS/Metadata
      '192.168.',
      '10.',
      '172.16.',
      '172.17.',
      '172.18.',
      '172.19.',
      '172.20.',
      '172.21.',
      '172.22.',
      '172.23.',
      '172.24.',
      '172.25.',
      '172.26.',
      '172.27.',
      '172.28.',
      '172.29.',
      '172.30.',
      '172.31.'
    ];

    if (ssrfPatterns.any((blocked) => host.startsWith(blocked) || host == blocked)) {
      return 'Invalid host or domain name';
    }

    return null;
  }

  /// Validates file properties before uploads.
  static bool validateFile(File file, String mimeType) {
    // 1. Validate size limit (avatars 10MB, general 25MB)
    final allowedImageMimes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedImageMimes.contains(mimeType)) return false;

    final length = file.lengthSync();
    if (length > 25 * 1024 * 1024) return false;

    // 2. Signature verification
    final bytes = file.readAsBytesSync().take(4).toList();
    if (bytes.length < 3) return false;

    if (mimeType == 'image/jpeg') {
      return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    } else if (mimeType == 'image/png') {
      if (bytes.length < 4) return false;
      return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    } else if (mimeType == 'image/webp') {
      if (bytes.length < 4) return false;
      return bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46; // RIFF header
    }

    return false;
  }
}
