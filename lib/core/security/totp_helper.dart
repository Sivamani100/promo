import 'dart:math';
import 'package:crypto/crypto.dart';

/// TotpHelper implements standard RFC 6238 Time-based One-time Password algorithm
/// using HMAC-SHA1 to generate and verify codes.
class TotpHelper {
  TotpHelper._();

  static const String base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Generates a random 16-character Base32 secret key.
  static String generateSecret() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      buffer.write(base32Alphabet[random.nextInt(base32Alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Verifies a 6-digit TOTP code against the secret key.
  /// Allows a 30-second window before/after to handle clock drift.
  static bool verifyCode(String secret, String code) {
    if (code.trim().length != 6) return false;
    
    try {
      final currentCounter = DateTime.now().millisecondsSinceEpoch ~/ 30000;
      // Allow clock drift of +/- 1 time step (30 seconds)
      for (int i = -1; i <= 1; i++) {
        if (generateCode(secret, currentCounter + i) == code.trim()) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Generates the 6-digit TOTP code for a specific time index.
  static String generateCode(String secret, int timeIndex) {
    final key = _base32Decode(secret);
    
    // Convert time index to 8-byte big-endian format
    final List<int> counterBytes = List<int>.filled(8, 0);
    int temp = timeIndex;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = temp & 0xFF;
      temp >>= 8;
    }

    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(counterBytes);
    final hash = digest.bytes;

    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
                   ((hash[offset + 1] & 0xFF) << 16) |
                   ((hash[offset + 2] & 0xFF) << 8) |
                   (hash[offset + 3] & 0xFF);

    final code = binary % 1000000;
    return code.toString().padLeft(6, '0');
  }

  /// Decodes a Base32 string to binary bytes.
  static List<int> _base32Decode(String base32) {
    final clean = base32.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final List<int> bytes = [];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < clean.length; i++) {
      final val = base32Alphabet.indexOf(clean[i]);
      if (val == -1) continue;

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 0xFF);
        bitsLeft -= 8;
      }
    }
    return bytes;
  }
}
