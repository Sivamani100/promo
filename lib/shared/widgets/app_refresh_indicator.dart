import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Branded premium pull-to-refresh indicator (Instagram-style).
///
/// When pulled down, it creates a gap between the fixed AppBar and the list
/// content where a smooth circular progress indicator spins.
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

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  
  late AnimationController _animController;
  double _animStartOffset = 0.0;
  double _animEndOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(() {
      setState(() {
        _dragOffset = Tween<double>(begin: _animStartOffset, end: _animEndOffset)
            .evaluate(_animController);
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animStartOffset = _dragOffset;
    _animEndOffset = target;
    _animController.forward(from: 0.0);
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    _animateTo(60.0); // Keep open at 60px during refresh
    
    try {
      await widget.onRefresh();
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      _animateTo(0.0);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isRefreshing || _animController.isAnimating) return false;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        setState(() {
          _dragOffset = -notification.metrics.pixels * 0.6;
        });
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        setState(() {
          _dragOffset = (_dragOffset - notification.overscroll * 0.6).clamp(0.0, 120.0);
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset > 55.0) {
        _startRefresh();
      } else if (_dragOffset > 0) {
        _animateTo(0.0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          // Gap/Reveal space spinner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: _dragOffset,
              alignment: Alignment.center,
              child: _dragOffset > 15
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: _isRefreshing ? null : (_dragOffset / 55.0).clamp(0.0, 0.99),
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Shifted scroll body
          Transform.translate(
            offset: Offset(0, _dragOffset),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
