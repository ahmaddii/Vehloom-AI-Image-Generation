import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'preferences_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");

  // Note: If your server sends 'notification' payloads, Android system tray handles it automatically.
  // If you send 'data' only payloads, you can initialize flutter_local_notifications here and show it.
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  RealtimeChannel? _notificationsChannel;

  Future<void> init() async {
    // 1. Request permissions
    await _requestPermissions();

    // 2. Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap here if needed
        // Since we are running outside context, full routing requires global keys,
        // but for now we just want the popup to appear.
      },
    );

    // 3. Set up Supabase Realtime listener
    _setupRealtimeListener();

    // Listen to auth state changes to re-subscribe if user logs in/out
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        _setupRealtimeListener();
        // Save the token now that we are definitely logged in
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _saveFcmTokenToSupabase(fcmToken);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        _cancelRealtimeListener();
      }
    });

    // 4. Set up Firebase Cloud Messaging
    await _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    // Request permission for FCM (especially important for iOS)
    await FirebaseMessaging.instance.requestPermission();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get the FCM token
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $fcmToken');
      if (fcmToken != null) {
        await _saveFcmTokenToSupabase(fcmToken);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) async {
          debugPrint('FCM Token Refreshed: $fcmToken');
          await _saveFcmTokenToSupabase(fcmToken);
        })
        .onError((err) {
          debugPrint('Error refreshing FCM token: $err');
        });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        // We comment this out to prevent double-notifications in the foreground!
        // Supabase Realtime will handle the foreground pop-up instantly instead.
        // _showFcmNotification(message);
      }
    });
  }

  Future<void> _saveFcmTokenToSupabase(String fcmToken) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Update the user's profile with the new FCM token
      // Make sure your Supabase 'profiles' table has an 'fcm_token' text column!
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': fcmToken})
          .eq('id', userId);
      debugPrint('Successfully saved FCM token to Supabase for user $userId');
    } catch (e) {
      debugPrint('Failed to save FCM token to Supabase: $e');
    }
  }

  Future<void> _showFcmNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'art_sharing_fcm_channel_id',
          'Art Sharing FCM Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          color: Color(0xFFFF7F50),
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _flutterLocalNotificationsPlugin.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> _requestPermissions() async {
    // Request notification permission for Android 13+
    await Permission.notification.request();
  }

  void _setupRealtimeListener() {
    _cancelRealtimeListener();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _notificationsChannel = Supabase.instance.client
        .channel('global_notifications:$userId')
        .onPostgresChanges(
          event:
              PostgresChangeEvent.insert, // Only trigger on new notifications
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            _showNotification(newRecord);
          },
        )
        .subscribe();
  }

  void _cancelRealtimeListener() {
    if (_notificationsChannel != null) {
      Supabase.instance.client.removeChannel(_notificationsChannel!);
      _notificationsChannel = null;
    }
  }

  Future<void> _showNotification(Map<String, dynamic> record) async {
    if (!PreferencesService().notificationsEnabled) return;

    // Only show if the user isn't the one who triggered it
    final actorId = record['actor_id'] as String?;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId != null && actorId == currentUserId) return;

    final type = record['type'] as String? ?? 'Activity';

    // Fetch actor's username if possible
    String actorName = 'Someone';
    if (actorId != null) {
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('username, display_name')
            .eq('id', actorId)
            .maybeSingle();
        if (profileResponse != null) {
          actorName =
              profileResponse['username'] ??
              profileResponse['display_name'] ??
              'Someone';
        }
      } catch (e) {
        debugPrint('Error fetching actor profile for notification: $e');
      }
    }

    String title = 'New Notification';
    String body = '$actorName interacted with you.';

    switch (type) {
      case 'like':
        title = 'New Like';
        body = '$actorName liked your post.';
        break;
      case 'comment':
        title = 'New Comment';
        body = '$actorName commented on your post.';
        break;
      case 'follow':
        title = 'New Follower';
        body = '$actorName started following you.';
        break;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'art_sharing_channel_id',
          'Art Sharing Notifications',
          channelDescription: 'Notifications for likes, comments, and follows',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          color: Color(0xFFFF7F50), // Coral color
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Generate a unique ID from the UUID if possible, or just use a random number
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }
}
