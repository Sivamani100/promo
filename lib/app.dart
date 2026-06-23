import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/providers/app_providers.dart';
import 'core/services/push_notification_manager.dart';

class BrandApp extends ConsumerWidget {
  const BrandApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    AppColors.isDarkMode = themeMode == ThemeMode.dark;
    
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

    return MaterialApp.router(
      title: 'Promo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}