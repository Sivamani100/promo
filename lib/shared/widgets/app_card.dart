import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Standardized card component used throughout the app.
///
/// Ensures consistent corner radius, shadow depth, and tap effects
/// across all card-like UI elements (discover cards, brand cards,
/// influencer cards, dashboard sections, etc.).
///
/// ```dart
/// AppCard(
///   onTap: () => navigateToDetail(),
///   child: Column(children: [...]),
/// )
/// ```
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool hasShadow;
  final double? borderRadius;
  final Color? backgroundColor;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.hasShadow = true,
    this.borderRadius,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DesignTokens.radiusMD;
    final bgColor = backgroundColor ?? AppColors.surface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasShadow ? DesignTokens.shadowMD : null,
        border: border,
      ),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.accent.withOpacity(0.06),
          highlightColor: AppColors.accent.withOpacity(0.03),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(DesignTokens.space16),
            child: child,
          ),
        ),
      ),
    );
  }
}
