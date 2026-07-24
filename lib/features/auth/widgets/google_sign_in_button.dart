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
          width: double.infinity,
          transform: Matrix4.identity()..scale(scale, scale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Inline Google "G" logo using colored circles — no network needed
              _GoogleGLogo(size: 20),
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

/// Draws a simplified Google "G" logo using CustomPainter — no network required.
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle (white)
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // Draw four colored quadrant arcs to mimic the Google logo
    final colors = [
      const Color(0xFF4285F4), // Blue  (top-right)
      const Color(0xFFEA4335), // Red   (top-left)
      const Color(0xFFFBBC04), // Yellow(bottom-left)
      const Color(0xFF34A853), // Green (bottom-right)
    ];

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.round;

    final arcRadius = radius * 0.62;
    final rect = Rect.fromCircle(
      center: center,
      radius: arcRadius,
    );

    for (int i = 0; i < 4; i++) {
      strokePaint.color = colors[i];
      canvas.drawArc(
        rect,
        (i * 90 - 45) * (3.14159265 / 180),
        85 * (3.14159265 / 180),
        false,
        strokePaint,
      );
    }

    // White center cutout
    canvas.drawCircle(center, arcRadius * 0.5, Paint()..color = Colors.white);

    // Blue right bar (the "G" crossbar)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx,
          center.dy - size.height * 0.11,
          radius * 0.7,
          size.height * 0.22,
        ),
        Radius.circular(size.width * 0.04),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
