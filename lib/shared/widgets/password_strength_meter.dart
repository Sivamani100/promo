import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PasswordStrengthMeter calculates and displays a visual password strength
/// indicator: Weak → Fair → Strong → Very Strong.
///
/// MNC security spec requirement: provide visual feedback during password entry
/// to guide users toward strong passwords.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  final bool showLabel;

  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.showLabel = true,
  });

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;

    int score = 0;

    // Length scoring
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Character type scoring
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) score++;

    // Penalty for repetition
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) score--;

    // Penalty for sequential chars (abc, 123)
    if (RegExp(r'(abc|bcd|cde|def|efg|123|234|345|456|789)', caseSensitive: false)
        .hasMatch(password)) score--;

    if (score <= 1) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.fair;
    if (score <= 5) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = evaluate(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final filled = index < strength.index;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: filled ? strength.color : Colors.white12,
                ),
              ),
            );
          }),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              strength.label,
              key: ValueKey(strength),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: strength.color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum PasswordStrength {
  empty,
  weak,
  fair,
  strong,
  veryStrong;

  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak — Add uppercase, numbers, and symbols';
      case PasswordStrength.fair:
        return 'Fair — Getting better, add more variety';
      case PasswordStrength.strong:
        return 'Strong — Good password';
      case PasswordStrength.veryStrong:
        return 'Very Strong — Excellent password';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.empty:
        return Colors.transparent;
      case PasswordStrength.weak:
        return const Color(0xFFEF4444); // Red
      case PasswordStrength.fair:
        return const Color(0xFFF59E0B); // Amber
      case PasswordStrength.strong:
        return const Color(0xFF22C55E); // Green
      case PasswordStrength.veryStrong:
        return const Color(0xFF8B5CF6); // Purple
    }
  }
}
