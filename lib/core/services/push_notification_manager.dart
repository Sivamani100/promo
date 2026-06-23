import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';
import 'supabase_service.dart';

// Background Message Handler for terminated/background FCM payloads
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background isolate
  await Firebase.initializeApp();
  debugPrint('[PUSH BACKGROUND] Title: ${message.notification?.title}, Data: ${message.data}');
}

final pushNotificationManagerProvider = Provider<PushNotificationManager>((ref) {
  return PushNotificationManager(ref);
});

class PushNotificationManager {
  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  PushNotificationManager(this._ref);

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('[PUSH] Initializing PushNotificationManager');

    // 1. Request notification permissions
    await _requestPermissions();

    // 2. Setup Flutter Local Notifications for foreground overlays
    await _setupLocalNotifications();

    // 3. Sync and register token in Supabase
    await updateTokenInDatabase();

    // 4. Set up message streams
    _setupMessageStreams();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[PUSH] Notification Permission State: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to request permissions: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.payload!));
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('[PUSH ERROR] Failed to parse local notification click payload: $e');
          }
        }
      },
    );

    // Create the default notification channel for Android 8.0+
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'fcm_default_channel',
        'Default Notifications',
        description: 'FCM push notification channel',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
    }
  }

  void _setupMessageStreams() {
    // Listen to messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[PUSH FOREGROUND] Title: ${message.notification?.title}, Body: ${message.notification?.body}');
      _showLocalNotification(message);
    });

    // Listen to messages when app is clicked from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[PUSH CLICKED FROM BACKGROUND] Title: ${message.notification?.title}');
      _handleNotificationClick(message.data);
    });

    // Handle token refresh
    _fcm.onTokenRefresh.listen((token) async {
      debugPrint('[PUSH] FCM Token refreshed: $token');
      await updateTokenInDatabase();
    });

    // Handle terminated state app launch via notification click
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PUSH CLICKED FROM TERMINATED] Title: ${initialMessage.notification?.title}');
        // Allow router initialization to settle before navigating
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationClick(initialMessage.data);
        });
      }
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to retrieve initial messaging payload: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fcm_default_channel',
      'Default Notifications',
      channelDescription: 'FCM push notification channel',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformDetails,
      payload: json.encode(message.data),
    );
  }

  Future<void> updateTokenInDatabase() async {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      debugPrint('[PUSH] Syncing FCM Token: $token');

      // Register or update token in database
      await SupabaseService.client.from('user_push_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'fcm_token');
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to register token: $e');
    }
  }

  Future<void> removeTokenFromDatabase() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      debugPrint('[PUSH] Deleting FCM Token on sign-out: $token');
      await SupabaseService.client
          .from('user_push_tokens')
          .delete()
          .eq('fcm_token', token);
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to remove token: $e');
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final refId = data['reference_id'] as String?;
    final role = _ref.read(authProvider).role;

    debugPrint('[PUSH NAVIGATION] click action triggered. type: $type, refId: $refId, role: $role');
    if (role == null) return;

    final router = _ref.read(routerProvider);

    if (type == 'new_message' && refId != null) {
      router.push('/$role/chats/$refId');
    } else if (type == 'application_received' && refId != null && role == 'brand') {
      router.push('/brand/cards/$refId');
    } else if (type == 'application_accepted' && refId != null && role == 'influencer') {
      router.push('/influencer/discover/$refId');
    } else if (type == 'application_rejected' && role == 'influencer') {
      router.push('/influencer/my-applications');
    } else if (type == 'milestone_completed' && refId != null) {
      router.push('/$role/chats/$refId');
    } else if (type == 'profile_view' && role == 'influencer') {
      router.push('/influencer/profile-views');
    } else {
      router.push('/$role/notifications');
    }
  }
}
