import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/design_tokens.dart';

/// An icon toggle button with Instagram-style micro-animation.
///
/// Scales to 1.3x with an elastic curve, then settles back to 1.0x.
/// Triggers haptic feedback on tap.
///
/// ```dart
/// AnimatedIconButton(
///   isActive: isSaved,
///   activeIcon: Iconsax.bookmark1,
///   inactiveIcon: Iconsax.bookmark,
///   activeColor: AppColors.purple,
///   onToggle: (nowActive) => toggleSave(),
/// )
/// ```
class AnimatedIconButton extends StatefulWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final Color? inactiveColor;
  final double size;
  final ValueChanged<bool>? onToggle;

  const AnimatedIconButton({
    super.key,
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    this.inactiveColor,
    this.size = DesignTokens.iconMD,
    this.onToggle,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: DesignTokens.curveElastic)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0);
    widget.onToggle?.call(!widget.isActive);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final inactiveColor =
        widget.inactiveColor ?? Theme.of(context).iconTheme.color ?? Colors.grey;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: DesignTokens.minTapTarget,
        height: DesignTokens.minTapTarget,
        child: Center(
          child: reduceMotion
              ? Icon(
                  widget.isActive ? widget.activeIcon : widget.inactiveIcon,
                  color: widget.isActive ? widget.activeColor : inactiveColor,
                  size: widget.size,
                )
              : ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedSwitcher(
                    duration: DesignTokens.durationSM,
                    child: Icon(
                      widget.isActive
                          ? widget.activeIcon
                          : widget.inactiveIcon,
                      key: ValueKey(widget.isActive),
                      color: widget.isActive
                          ? widget.activeColor
                          : inactiveColor,
                      size: widget.size,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
