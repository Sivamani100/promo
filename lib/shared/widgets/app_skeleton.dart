import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORE SKELETON PRIMITIVES
// A unified, premium skeleton loading system with a slow, elegant shimmer.
// ─────────────────────────────────────────────────────────────────────────────

/// The root shimmer wrapper. Wraps any skeleton bone tree with a sweeping
/// linear-gradient animation. Use ONE per skeleton screen — never nest.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final baseColor = isDark ? const Color(0xFF1A1A24) : const Color(0xFFE8E8ED);
    final highlightColor = isDark ? const Color(0xFF272736) : const Color(0xFFF5F5F8);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              final double slide = _controller.value * 2.0 - 0.5;
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.centerRight,
                colors: [baseColor, highlightColor, baseColor],
                stops: [
                  (slide - 0.3).clamp(0.0, 1.0),
                  slide.clamp(0.0, 1.0),
                  (slide + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A rectangular bone placeholder.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular bone placeholder — ideal for avatars.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A single text-line bone with natural proportions.
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({super.key, this.width = 120, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Multiple text lines with naturally decreasing widths.
class SkeletonParagraph extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;

  const SkeletonParagraph({
    super.key,
    this.lines = 3,
    this.lineHeight = 12,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final widthFraction = i == lines - 1 ? 0.6 : (i == 0 ? 1.0 : 0.85);
        return Padding(
          padding: EdgeInsets.only(bottom: i < lines - 1 ? spacing : 0),
          child: FractionallySizedBox(
            widthFactor: widthFraction,
            child: Container(
              height: lineHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(lineHeight / 2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A pill-shaped button bone.
class SkeletonButton extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonButton({
    super.key,
    this.width = double.infinity,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
    );
  }
}

/// An aspect-ratio image placeholder.
class SkeletonImage extends StatelessWidget {
  final double aspectRatio;
  final double borderRadius;

  const SkeletonImage({
    super.key,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A card bone — a rounded container with border that matches the app's card style.
class SkeletonCard extends StatelessWidget {
  final double? height;
  final double? width;
  final Widget? child;
  final EdgeInsetsGeometry? padding;

  const SkeletonCard({
    super.key,
    this.height,
    this.width,
    this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Container(
      height: height,
      width: width,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}
