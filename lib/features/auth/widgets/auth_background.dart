import 'dart:math';
import 'package:flutter/material.dart';

class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        // Base Background
        Container(
          color: isDark ? const Color(0xFF15171C) : const Color(0xFFFAF9F6),
        ),
        
        // Animated Blobs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: BlobPainter(
                progress: _controller.value,
                isDark: isDark,
              ),
              size: Size.infinite,
            );
          },
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

class BlobPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  BlobPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final random = Random(42); // Seed for consistent randomness

    void drawBlob(double xOffset, double yOffset, double sizeFactor, Color color, double speedMultiplier) {
      paint.color = color.withOpacity(isDark ? 0.4 : 0.6);
      
      final angle = (progress * 2 * pi * speedMultiplier) + random.nextDouble() * 2 * pi;
      final dx = sin(angle) * 60;
      final dy = cos(angle) * 60;
      
      final center = Offset(xOffset + dx, yOffset + dy);
      canvas.drawCircle(center, size.width * sizeFactor, paint);
    }

    final color1 = isDark ? const Color(0xFF7E57C2) : const Color(0xFFFFCC80); // Deep purple / Soft orange
    final color2 = isDark ? const Color(0xFF03A9F4) : const Color(0xFFCE93D8); // Light Blue / Soft purple
    final color3 = isDark ? const Color(0xFFE91E63) : const Color(0xFF81D4FA); // Pink / Soft blue

    drawBlob(size.width * 0.1, size.height * 0.15, 0.4, color1, 1.0);
    drawBlob(size.width * 0.9, size.height * 0.75, 0.35, color2, -0.8);
    drawBlob(size.width * 0.6, size.height * 0.45, 0.3, color3, 1.2);
  }

  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
