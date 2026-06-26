import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';

/// Custom page transitions for the Promo app.
///
/// Every route in [AppRouter] should use one of these instead of
/// Flutter's platform-default transitions.
///
/// Duration standards:
/// - Tab switch: 200ms
/// - Push to new screen: 280ms
/// - Modal/sheet open: 350ms
/// - Dialog appear: 180ms
class AppTransitions {
  AppTransitions._();

  /// Standard push — slide up from bottom (280ms, easeOutCubic).
  /// Used for: new screens pushed onto the stack.
  static CustomTransitionPage<void> slideUp({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: DesignTokens.curveDefault,
          )),
          child: child,
        );
      },
    );
  }

  /// Modal-style slide up with subtle scale on the background (350ms).
  /// Used for: profile views, card detail, bottom-sheet-style screens.
  static CustomTransitionPage<void> slideUpModal({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: DesignTokens.durationLG,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideIn = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: DesignTokens.curveDefault,
        ));

        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: fadeIn,
          child: SlideTransition(
            position: slideIn,
            child: child,
          ),
        );
      },
    );
  }

  /// Fade transition for tab navigation (200ms).
  /// No slide — it's jarring for bottom-tab switches.
  static CustomTransitionPage<void> fade({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeIn,
          ),
          child: child,
        );
      },
    );
  }

  /// Slide left (right-to-left) for drilling into detail (280ms).
  /// Used for: card → card detail, list item → item detail.
  static CustomTransitionPage<void> slideLeft({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideIn = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: DesignTokens.curveDefault,
        ));

        // Subtle scale-down for the outgoing page
        final scaleOut = Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: DesignTokens.curveDefault,
          ),
        );

        final fadeOut = Tween<double>(begin: 1.0, end: 0.5).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeIn,
          ),
        );

        return SlideTransition(
          position: slideIn,
          child: child,
        );
      },
    );
  }

  /// No transition — for the splash/initial route.
  static CustomTransitionPage<void> none({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, __, ___, child) => child,
    );
  }
}
