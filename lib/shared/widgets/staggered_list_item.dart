import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Wraps a list item with a staggered entrance animation.
///
/// Each item slides up 20px and fades in, with a delay based on its index.
/// Items at index 0 animate immediately; item 5 starts at 200ms.
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => StaggeredListItem(
///     index: index,
///     child: MyListTile(...),
///   ),
/// )
/// ```
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  /// Max number of items to animate. Items beyond this index appear instantly.
  final int maxAnimatedItems;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.maxAnimatedItems = 15,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: DesignTokens.curveDefault,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08), // ~20px on a 250px item
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: DesignTokens.curveDefault,
    ));

    // Skip animation for items beyond maxAnimatedItems (performance)
    if (widget.index >= widget.maxAnimatedItems) {
      _controller.value = 1.0;
    } else {
      // Stagger: each item delayed by 40ms from the previous
      final delay = Duration(milliseconds: widget.index * 40);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect accessibility: skip animations if user prefers reduced motion
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return widget.child;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
