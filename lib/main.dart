import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/supabase_service.dart';
import 'core/services/push_notification_manager.dart';
import 'core/config/app_config.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[MAIN] Failed to initialize Firebase: $e');
  }

  // HARDENING: observability-agent 2026-06-24
  if (AppConfig.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate = AppConfig.isProduction ? 0.1 : 1.0;
        options.environment = AppConfig.env;
      },
      appRunner: () => runApp(
        DevicePreview(
          enabled: !kReleaseMode,
          builder: (context) => const ProviderScope(
            child: BrandApp(),
          ),
        ),
      ),
    );
  } else {
    runApp(
      DevicePreview(
        enabled: !kReleaseMode,
        builder: (context) => const ProviderScope(
          child: BrandApp(),
        ),
      ),
    );
  }
}