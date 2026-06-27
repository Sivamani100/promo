import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';
import 'supabase_service.dart';
import '../../firebase_options.dart';

// Background Message Handler for terminated/background FCM payloads
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Ensure Firebase is initialized for background isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[PUSH BACKGROUND] Title: ${message.notification?.title}, Data: ${message.data}');

    try {
      await SupabaseService.initialize();
      await SupabaseService.client.from('audit_logs').insert({
        'action': 'push.background_received',
        'metadata': {
          'message_id': message.messageId,
          'type': message.data['type'],
          'has_notification': message.notification != null,
        },
      });
    } catch (_) {}

    // If the message has a notification block, the Android OS automatically shows the notification when in background.
    // We only show local notifications for data-only payloads to avoid duplicates.
    if (message.notification != null) {
      debugPrint('[PUSH BACKGROUND] OS handles this notification automatically. Skipping local notification.');
      return;
    }

    await _showBackgroundNotification(message);
  } catch (e, stack) {
    debugPrint('[PUSH BACKGROUND ERROR] $e\n$stack');
    try {
      await SupabaseService.initialize();
      await SupabaseService.client.from('audit_logs').insert({
        'action': 'push.background_error',
        'metadata': {
          'error': e.toString(),
          'stack': stack.toString(),
        },
      });
    } catch (_) {}
  }
}

// Show local notification in background/terminated state
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    await _showBackgroundNotificationWithIcon(message, 'launcher_icon');
  } catch (e) {
    debugPrint('[PUSH BACKGROUND SHOW WARNING] Failed with launcher_icon, trying @mipmap/launcher_icon: $e');
    try {
      await _showBackgroundNotificationWithIcon(message, '@mipmap/launcher_icon');
    } catch (e2) {
      debugPrint('[PUSH BACKGROUND SHOW WARNING] Failed with @mipmap/launcher_icon, trying @mipmap/ic_launcher: $e2');
      try {
        await _showBackgroundNotificationWithIcon(message, '@mipmap/ic_launcher');
      } catch (e3) {
        debugPrint('[PUSH BACKGROUND SHOW WARNING] Failed with @mipmap/ic_launcher, trying ic_launcher: $e3');
        try {
          await _showBackgroundNotificationWithIcon(message, 'ic_launcher');
        } catch (e4, stack) {
          debugPrint('[PUSH BACKGROUND SHOW ERROR] All icon show attempts failed: $e4\n$stack');
          try {
            await SupabaseService.client.from('audit_logs').insert({
              'action': 'push.background_show_error',
              'metadata': {
                'error': e4.toString(),
                'stack': stack.toString(),
              },
            });
          } catch (_) {}
        }
      }
    }
  }
}

Future<void> _showBackgroundNotificationWithIcon(RemoteMessage message, String iconName) async {
  final String? title = message.data['title'] ?? message.notification?.title;
  final String? body = message.data['body'] ?? message.notification?.body;
  if (title == null && body == null) return;

  final List<AndroidNotificationAction> actions = [];
  final String type = message.data['type'] as String? ?? 'general';

  if (type == 'new_message' && message.data['reference_id'] != null) {
    actions.add(
      const AndroidNotificationAction(
        'action_reply',
        'Reply',
        inputs: [
          AndroidNotificationActionInput(
            label: 'Type your message...',
          ),
        ],
      ),
    );
    actions.add(
      const AndroidNotificationAction(
        'action_mark_read',
        'Mark as Read',
      ),
    );
  }

  String channelId = 'low_priority_info';
  String channelName = 'General Info';
  String channelDesc = 'For general announcements and informational updates.';
  Importance importance = Importance.low;
  Priority priority = Priority.low;
  bool playSound = false;
  bool enableVibration = false;

  if (type == 'new_message' || type == 'campaign_invite' || type == 'payment_update' || type == 'group_invite') {
    channelId = 'high_priority_alerts';
    channelName = 'High Priority Alerts';
    channelDesc = 'For new messages, campaign invites, and payment updates.';
    importance = Importance.max;
    priority = Priority.high;
    playSound = true;
    enableVibration = true;
  } else if (type == 'application_received' || type == 'application_accepted' || type == 'application_rejected' || type == 'milestone_completed' || type == 'profile_view' || type == 'verification_update') {
    channelId = 'medium_priority_updates';
    channelName = 'Updates & Approvals';
    channelDesc = 'For application status updates and verification progress.';
    importance = Importance.high;
    priority = Priority.high;
    playSound = true;
    enableVibration = true;
  }

  final String cleanIconName = iconName.contains('/') ? iconName.split('/').last : iconName;
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDesc,
    importance: importance,
    priority: priority,
    showWhen: true,
    playSound: playSound,
    enableVibration: enableVibration,
    actions: actions,
    icon: iconName,
    largeIcon: DrawableResourceAndroidBitmap(cleanIconName),
    groupKey: type == 'new_message' ? 'chat_group_${message.data['reference_id']}' : '${type}_group',
  );

  final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize the plugin for this background isolate before showing notifications
  final AndroidInitializationSettings androidSettings = AndroidInitializationSettings(iconName);
  final InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await localNotifications.initialize(
    settings: initSettings,
    onDidReceiveBackgroundNotificationResponse: localNotificationTapBackgroundHandler,
  );

  await localNotifications.show(
    id: title.hashCode ^ body.hashCode,
    title: title,
    body: body,
    notificationDetails: platformDetails,
    payload: json.encode(message.data),
  );

  try {
    await SupabaseService.client.from('audit_logs').insert({
      'action': 'push.background_local_shown',
      'metadata': {
        'title': title,
        'body': body,
        'icon': iconName,
      },
    });
  } catch (_) {}
}


// Handle background tap responses (specifically inline replies)
@pragma('vm:entry-point')
void localNotificationTapBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[PUSH BACKGROUND TAP] Action: ${response.actionId}, Input: ${response.input}');

  if (response.payload == null) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      await SupabaseService.initialize();
    } catch (_) {}

    final client = SupabaseService.client;

    // Wait up to 1.5 seconds for the auth session to be restored from persistence
    int attempts = 0;
    while (client.auth.currentSession == null && attempts < 15) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.payload!));
    final roomId = data['reference_id'] as String?;
    final recipientId = data['recipient_id'] as String?;
    final String? title = data['title'] ?? data['body'];
    final String? body = data['body'];
    final int notifId = response.id ?? (title?.hashCode ?? 0) ^ (body?.hashCode ?? 0);

    final currentUser = client.auth.currentUser;
    // Fallback to recipientId (recipient of notification) if currentSession is not loaded
    final senderId = currentUser?.id ?? recipientId;
    if (senderId == null) {
      debugPrint('[PUSH BACKGROUND ACTION ERROR] No sender ID available (currentUser and recipientId are both null).');
      return;
    }

    if (roomId != null) {
      if (response.actionId == 'action_reply' && response.input != null && response.input!.isNotEmpty) {
        debugPrint('[PUSH BACKGROUND REPLY] Sending reply to room $roomId from sender $senderId: ${response.input}');

        // Send message using Supabase directly
        await client.from('messages').insert({
          'room_id': roomId,
          'sender_id': senderId,
          'content': response.input!,
        });

        debugPrint('[PUSH BACKGROUND REPLY SUCCESS] Reply sent.');

        // Cancel the notification to clear it from shade
        final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
        await localNotifications.cancel(id: notifId);

      } else if (response.actionId == 'action_mark_read') {
        debugPrint('[PUSH BACKGROUND MARK READ] Marking messages read in room $roomId');

        // Update all messages in the room not sent by the recipient/current user to is_read = true
        await client
            .from('messages')
            .update({'is_read': true})
            .eq('room_id', roomId)
            .neq('sender_id', senderId)
            .eq('is_read', false);

        debugPrint('[PUSH BACKGROUND MARK READ SUCCESS] Messages marked read.');

        // Cancel the notification
        final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
        await localNotifications.cancel(id: notifId);
      }
    }
  } catch (e, stack) {
    debugPrint('[PUSH BACKGROUND ACTION CRITICAL ERROR] $e\n$stack');
  }
}

final pushNotificationManagerProvider = Provider<PushNotificationManager>((ref) {
  return PushNotificationManager(ref);
});

class PushNotificationManager {
  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _initializing = false;

  PushNotificationManager(this._ref);

  Future<void> _logDiagnostic(String action, Map<String, dynamic> metadata) async {
    try {
      final user = _ref.read(authProvider).user;
      await SupabaseService.client.from('audit_logs').insert({
        'actor_id': user?.id,
        'action': action,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('[PUSH DIAGNOSTIC ERROR] Failed to write audit log: $e');
    }
  }

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    debugPrint('[PUSH] Initializing PushNotificationManager');
    await _logDiagnostic('push.initialize_start', {'time': DateTime.now().toIso8601String()});

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('push_notifications_enabled') ?? false;

    // 1. Request notification permissions only if enabled
    if (enabled) {
      try {
        await _requestPermissions();
      } catch (e) {
        await _logDiagnostic('push.permissions_step_error', {'error': e.toString()});
      }
    }

    // 2. Setup Flutter Local Notifications for foreground overlays
    try {
      await _setupLocalNotifications();
      await _logDiagnostic('push.local_notifications_success', {});
    } catch (e) {
      await _logDiagnostic('push.local_notifications_error', {'error': e.toString()});
    }

    // 3. Sync and register token in Supabase only if enabled
    if (enabled) {
      try {
        await updateTokenInDatabase();
      } catch (e) {
        await _logDiagnostic('push.sync_step_error', {'error': e.toString()});
      }
    }

    // 4. Set up message streams
    try {
      _setupMessageStreams();
    } catch (e) {
      await _logDiagnostic('push.streams_step_error', {'error': e.toString()});
    }

    _initialized = true;
    _initializing = false;
    await _logDiagnostic('push.initialize_complete', {'time': DateTime.now().toIso8601String()});
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
      await _logDiagnostic('push.permissions', {
        'status': settings.authorizationStatus.toString(),
      });

      // Request Android local notification permissions for Android 13+
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('[PUSH] Android local notifications permission granted: $granted');
      }
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to request permissions: $e');
      await _logDiagnostic('push.permissions_error', {
        'error': e.toString(),
      });
    }
  }

  Future<void> _setupLocalNotifications() async {
    try {
      await _setupLocalNotificationsWithIcon('launcher_icon');
    } catch (e) {
      debugPrint('[PUSH WARNING] Failed to initialize local notifications with launcher_icon: $e');
      try {
        await _setupLocalNotificationsWithIcon('@mipmap/launcher_icon');
      } catch (e2) {
        debugPrint('[PUSH WARNING] Failed to initialize local notifications with @mipmap/launcher_icon: $e2');
        try {
          await _setupLocalNotificationsWithIcon('@mipmap/ic_launcher');
        } catch (e3) {
          try {
            await _setupLocalNotificationsWithIcon('ic_launcher');
          } catch (e4) {
            debugPrint('[PUSH ERROR] All local notifications initializations failed: $e4');
            rethrow;
          }
        }
      }
    }
  }

  Future<void> _setupLocalNotificationsWithIcon(String iconName) async {
    final AndroidInitializationSettings androidSettings = AndroidInitializationSettings(iconName);
    final InitializationSettings initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if ((response.actionId == 'action_reply' || response.actionId == 'action_mark_read') && response.payload != null) {
          _handleForegroundAction(response);
        } else if (response.payload != null) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.payload!));
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('[PUSH ERROR] Failed to parse local notification click payload: $e');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: localNotificationTapBackgroundHandler,
    );

    // Create the default notification channels for Android 8.0+
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Create High Priority Channel
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'high_priority_alerts',
        'High Priority Alerts',
        description: 'For new messages, campaign invites, and payment updates.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));

      // Create Medium Priority Channel
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'medium_priority_updates',
        'Updates & Approvals',
        description: 'For application status updates and verification progress.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));

      // Create Low Priority Channel
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'low_priority_info',
        'General Info',
        description: 'For general announcements and informational updates.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
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
      // 1. Check if app was launched via FCM notification click
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PUSH CLICKED FROM TERMINATED] Title: ${initialMessage.notification?.title}');
        // Allow router initialization to settle before navigating
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationClick(initialMessage.data);
        });
        return;
      }

      // 2. Check if app was launched via local notification click (e.g. background/terminated)
      final NotificationAppLaunchDetails? launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null) {
          debugPrint('[PUSH LOCAL CLICKED FROM TERMINATED] Payload: $payload');
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(payload));
            // Allow router initialization to settle before navigating
            Future.delayed(const Duration(milliseconds: 800), () {
              _handleNotificationClick(data);
            });
          } catch (e) {
            debugPrint('[PUSH ERROR] Failed to parse initial local notification click payload: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to retrieve initial messaging payload: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      await _showLocalNotificationWithIcon(message, 'launcher_icon');
    } catch (e) {
      debugPrint('[PUSH WARNING] Failed to show local notification with launcher_icon: $e');
      try {
        await _showLocalNotificationWithIcon(message, '@mipmap/launcher_icon');
      } catch (e2) {
        debugPrint('[PUSH WARNING] Failed to show local notification with @mipmap/launcher_icon: $e2');
        try {
          await _showLocalNotificationWithIcon(message, '@mipmap/ic_launcher');
        } catch (e3) {
          try {
            await _showLocalNotificationWithIcon(message, 'ic_launcher');
          } catch (e4) {
            debugPrint('[PUSH ERROR] All show local notification attempts failed: $e4');
          }
        }
      }
    }
  }

  Future<void> _showLocalNotificationWithIcon(RemoteMessage message, String iconName) async {
    final String? title = message.notification?.title ?? message.data['title'] as String?;
    final String? body = message.notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    final List<AndroidNotificationAction> actions = [];
    final String type = message.data['type'] as String? ?? 'general';

    if (type == 'new_message' && message.data['reference_id'] != null) {
      actions.add(
        const AndroidNotificationAction(
          'action_reply',
          'Reply',
          inputs: [
            AndroidNotificationActionInput(
              label: 'Type your message...',
            ),
          ],
        ),
      );
      actions.add(
        const AndroidNotificationAction(
          'action_mark_read',
          'Mark as Read',
        ),
      );
    }

    // Determine Priority and Channel based on Notification type/category
    String channelId = 'low_priority_info';
    String channelName = 'General Info';
    String channelDesc = 'For general announcements and informational updates.';
    Importance importance = Importance.low;
    Priority priority = Priority.low;
    bool playSound = false;
    bool enableVibration = false;

    if (type == 'new_message' || type == 'campaign_invite' || type == 'payment_update' || type == 'group_invite') {
      channelId = 'high_priority_alerts';
      channelName = 'High Priority Alerts';
      channelDesc = 'For new messages, campaign invites, and payment updates.';
      importance = Importance.max;
      priority = Priority.high;
      playSound = true;
      enableVibration = true;
    } else if (type == 'application_received' || type == 'application_accepted' || type == 'application_rejected' || type == 'milestone_completed' || type == 'profile_view' || type == 'verification_update') {
      channelId = 'medium_priority_updates';
      channelName = 'Updates & Approvals';
      channelDesc = 'For application status updates and verification progress.';
      importance = Importance.high;
      priority = Priority.high;
      playSound = true;
      enableVibration = true;
    }

    final String cleanIconName = iconName.contains('/') ? iconName.split('/').last : iconName;
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      showWhen: true,
      playSound: playSound,
      enableVibration: enableVibration,
      actions: actions,
      icon: iconName,
      largeIcon: DrawableResourceAndroidBitmap(cleanIconName),
      groupKey: type == 'new_message' ? 'chat_group_${message.data['reference_id']}' : '${type}_group',
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: title.hashCode ^ body.hashCode,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: json.encode(message.data),
    );
  }


  Future<void> updateTokenInDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('push_notifications_enabled') ?? false;
    if (!enabled) {
      await _logDiagnostic('push.sync_ignored', {'reason': 'permission_disabled'});
      return;
    }

    final authState = _ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      await _logDiagnostic('push.sync_ignored', {'reason': 'user_null'});
      return;
    }

    await _logDiagnostic('push.sync_start', {'user_id': user.id});

    try {
      final token = await _fcm.getToken();
      if (token == null) {
        await _logDiagnostic('push.token_null', {'user_id': user.id});
        return;
      }
      debugPrint('[PUSH] Syncing FCM Token: $token');
      await _logDiagnostic('push.token_fetched', {
        'user_id': user.id,
        'token_length': token.length,
      });

      // First delete any existing registration for this token (regardless of user) to avoid RLS conflicts on update
      try {
        await SupabaseService.client
            .from('user_push_tokens')
            .delete()
            .eq('fcm_token', token);
      } catch (e) {
        debugPrint('[PUSH WARNING] Failed to delete existing token before sync: $e');
      }

      // Register token in database
      await SupabaseService.client.from('user_push_tokens').insert({
        'user_id': user.id,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _logDiagnostic('push.token_success', {
        'user_id': user.id,
      });
    } catch (e) {
      debugPrint('[PUSH ERROR] Failed to register token: $e');
      await _logDiagnostic('push.token_error', {
        'user_id': user.id,
        'error': e.toString(),
      });
    }
  }

  Future<void> removeTokenFromDatabase() async {
    _initialized = false;
    _initializing = false;
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
    final authState = _ref.read(authProvider);
    final role = authState.role;

    debugPrint('[PUSH NAVIGATION] click action triggered. type: $type, refId: $refId, role: $role');
    
    if (role == null) {
      debugPrint('[PUSH NAVIGATION] Role is null. Waiting for auth state to settle.');
      int attempts = 0;
      Timer.periodic(const Duration(milliseconds: 200), (timer) {
        attempts++;
        final currentRole = _ref.read(authProvider).role;
        if (currentRole != null) {
          timer.cancel();
          debugPrint('[PUSH NAVIGATION] Auth state settled. Role: $currentRole. Navigating now.');
          _navigateWithRole(currentRole, type, refId);
        } else if (attempts >= 15) { // 3 seconds timeout
          timer.cancel();
          debugPrint('[PUSH NAVIGATION] Timeout waiting for auth state.');
          final currentUser = _ref.read(authProvider).user;
          if (currentUser != null) {
            _ref.read(routerProvider).push('/notifications');
          }
        }
      });
      return;
    }

    _navigateWithRole(role, type, refId);
  }

  void _navigateWithRole(String role, String? type, String? refId) {
    final router = _ref.read(routerProvider);

    if ((type == 'new_message' || type == 'group_invite') && refId != null) {
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
    } else if (type == 'campaign_invite' && refId != null && role == 'influencer') {
      router.push('/influencer/discover/$refId');
    } else if (type == 'payment_update') {
      if (role == 'influencer') {
        router.push('/influencer/milestones');
      } else {
        router.push('/brand/campaigns');
      }
    } else {
      router.push('/$role/notifications');
    }
  }

  Future<void> _handleForegroundAction(NotificationResponse response) async {
    try {
      final user = _ref.read(authProvider).user;
      if (user == null || response.payload == null) return;

      final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.payload!));
      final roomId = data['reference_id'] as String?;

      if (roomId != null) {
        if (response.actionId == 'action_reply' && response.input != null) {
          debugPrint('[PUSH FOREGROUND REPLY] Sending reply to room $roomId: ${response.input}');
          await SupabaseService.client.from('messages').insert({
            'room_id': roomId,
            'sender_id': user.id,
            'content': response.input!,
          });
        } else if (response.actionId == 'action_mark_read') {
          debugPrint('[PUSH FOREGROUND MARK READ] Marking messages read in room $roomId');
          await SupabaseService.client
              .from('messages')
              .update({'is_read': true})
              .eq('room_id', roomId)
              .neq('sender_id', user.id)
              .eq('is_read', false);
        }

        if (response.id != null) {
          await _localNotifications.cancel(id: response.id!);
        }
      }
    } catch (e) {
      debugPrint('[PUSH FOREGROUND ACTION ERROR] Failed to execute action: $e');
    }
  }

  Future<void> showRationaleDialogIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('push_notifications_asked') ?? false;
    if (hasAsked) return;

    if (!context.mounted) return;

    final bool? allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Allow Notifications'),
          content: const Text(
            'Allow Promo to send notifications for new \n'
            'messages, application updates and collaboration \n'
            'alerts?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    await prefs.setBool('push_notifications_asked', true);
    if (allowed == true) {
      await prefs.setBool('push_notifications_enabled', true);
      _initialized = false;
      await initialize();
    } else {
      await prefs.setBool('push_notifications_enabled', false);
    }
  }
}
