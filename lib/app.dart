import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/providers/app_providers.dart';
import 'core/services/push_notification_manager.dart';
import 'core/services/app_update_service.dart';
import 'shared/widgets/offline_banner.dart';
import 'shared/widgets/blocker_screens.dart';
import 'shared/widgets/privacy_guard.dart';
import 'core/security/resume_auth_gate.dart';
import 'core/security/security_hardening_service.dart';
import 'core/deeplink/deeplink_service.dart';
import 'core/config/app_config.dart';

class BrandApp extends ConsumerStatefulWidget {
  const BrandApp({super.key});

  @override
  ConsumerState<BrandApp> createState() => _BrandAppState();
}

class _BrandAppState extends ConsumerState<BrandApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    SecurityHardeningService.initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).validateSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isSystemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    AppColors.isDarkMode = themeMode == ThemeMode.system ? isSystemDark : (themeMode == ThemeMode.dark);
    
    final router = ref.watch(routerProvider);

    // Initialize deep linking on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.initialize(ref);
    });

    // Initialize push notifications if user is already logged in
    final user = ref.watch(authProvider).user;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pushNotificationManagerProvider).initialize();
      });
    }

    // Listen to login/logout to register/unregister tokens
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && previous?.user == null) {
        ref.read(pushNotificationManagerProvider).initialize();
        // Handle any pending deep link navigation after successful login
        DeepLinkService.handlePendingLink(ref);
      } else if (next.user == null && previous?.user != null) {
        ref.read(pushNotificationManagerProvider).removeTokenFromDatabase();
      }
    });

    // HARDENING: devops-agent 2026-06-24
    return MaterialApp.router(
      title: 'Promo',
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
      useInheritedMediaQuery: true,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final config = ref.watch(appConfigCheckerProvider);
        if (config.isInMaintenance) {
          return const MaintenanceBlockerScreen();
        }
        if (config.needsForceUpdate) {
          return const ForceUpdateBlockerScreen();
        }
        return AppPrivacyGuard(
          child: ResumeAuthGate(
            child: OfflineBanner(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}