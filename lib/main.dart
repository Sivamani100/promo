import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/supabase_service.dart';
import 'core/services/push_notification_manager.dart';
import 'core/config/app_config.dart';
import 'core/lifecycle/app_lifecycle_manager.dart';
import 'core/config/url_strategy_stub.dart'
    if (dart.library.html) 'core/config/url_strategy_web.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  // Explicit ProviderContainer for background/lifecycle sync
  final container = ProviderContainer();
  WidgetsBinding.instance.addObserver(AppLifecycleManager(ref: container));

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
        UncontrolledProviderScope(
          container: container,
          child: const BrandApp(),
        ),
      ),
    );
  } else {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const BrandApp(),
      ),
    );
  }
}