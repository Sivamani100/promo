import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;

  const GoogleSignInButton({
    super.key, 
    this.onPressed,
    this.label = 'Continue with Google',
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark
        ? (_isHovered ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.04))
        : (_isHovered ? Colors.black.withOpacity(0.04) : Colors.transparent);
    final borderColor = isDark
        ? (_isHovered ? Colors.white30 : Colors.white24)
        : (_isHovered ? Colors.black26 : Colors.black12);
    final textColor = isDark ? Colors.white : Colors.black87;
    final scale = _isPressed ? 0.96 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: 54,
          transform: Matrix4.identity()..scale(scale, scale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
