import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Custom pull-to-refresh indicator with Promo branding.
///
/// Replaces Flutter's generic [RefreshIndicator] with a branded animation:
/// - Drag: subtle "Release to refresh" text fades in
/// - Release: brand-colored spinner
/// - Complete: "Updated just now" text fades in, then auto-fades after 2s
///
/// ```dart
/// AppRefreshIndicator(
///   onRefresh: () => loadData(),
///   child: ListView(...),
/// )
/// ```
class AppRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  bool _showUpdatedBanner = false;
  Timer? _bannerTimer;

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    if (!mounted) return;
    setState(() => _showUpdatedBanner = true);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showUpdatedBanner = false);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.purple,
          backgroundColor: AppColors.surface,
          strokeWidth: 2.5,
          displacement: 60,
          child: widget.child,
        ),
        // "Updated just now" banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _showUpdatedBanner ? 1.0 : 0.0,
            duration: DesignTokens.durationMD,
            curve: DesignTokens.curveDefault,
            child: AnimatedSlide(
              offset: Offset(0, _showUpdatedBanner ? 0 : -1),
              duration: DesignTokens.durationMD,
              curve: DesignTokens.curveDefault,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.space8,
                  horizontal: DesignTokens.space16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: DesignTokens.shadowSM,
                ),
                child: Center(
                  child: Text(
                    'Updated just now',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
