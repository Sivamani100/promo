import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/providers/app_providers.dart';
import 'core/services/push_notification_manager.dart';
import 'shared/widgets/offline_banner.dart';
import 'core/config/app_config.dart';

class BrandApp extends ConsumerWidget {
  const BrandApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isSystemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    AppColors.isDarkMode = themeMode == ThemeMode.system ? isSystemDark : (themeMode == ThemeMode.dark);
    
    final router = ref.watch(routerProvider);

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
      } else if (next.user == null && previous?.user != null) {
        ref.read(pushNotificationManagerProvider).removeTokenFromDatabase();
      }
    });

    // HARDENING: devops-agent 2026-06-24
    return MaterialApp.router(
      title: 'Promo',
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: DevicePreview.locale(context),
      builder: (context, child) {
        final previewChild = DevicePreview.appBuilder(context, child);
        return OfflineBanner(child: previewChild);
      },
    );
  }
}