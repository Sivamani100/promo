// HARDENING: devops-agent 2026-06-24
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/services/realtime_subscription_manager.dart';

class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && previous == false) {
        debugPrint('[OFFLINE_BANNER] Reconnected. Resuming subscriptions...');
        RealtimeSubscriptionManager.resumeAll();
      }
    });

    final isOnline = ref.watch(isOnlineProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: isOnline ? -80 : 0,
            left: 0,
            right: 0,
            height: 80,
            child: IgnorePointer(
              ignoring: isOnline,
              child: Material(
                color: Colors.red[800],
                elevation: 4,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No internet connection. Operating in offline mode.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
