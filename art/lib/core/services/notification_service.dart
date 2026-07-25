import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import '../../data/repositories/chat_repository.dart';
import '../router/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Track the active room ID to suppress foreground notifications if the user is in that chat
  String? currentActiveRoomId;

  Future<void> init() async {
    // 1. Request permissions
    await _requestPermissions();

    // 2. Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // 3. Set up Firebase Cloud Messaging
    await _setupFirebaseMessaging();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle background notification tap (app was in background or terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_onFcmMessageOpenedApp);

    // Check if app was launched via a notification tap
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onFcmMessageOpenedApp(initialMessage);
    }

    // Get and save token
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        _saveFcmToken(fcmToken);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveFcmToken);

    // Re-save token when user logs in or out
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        final currentToken = await FirebaseMessaging.instance.getToken();
        if (currentToken != null) {
          _saveFcmToken(currentToken);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        currentActiveRoomId = null;
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground: ${message.data}');

      final roomId = message.data['room_id'] as String?;
      if (roomId != null && roomId == currentActiveRoomId) {
        // Do not show local notification if user is currently inside this chat room
        debugPrint('Suppressing foreground notification because user is in active room: $roomId');
        return;
      }

      if (message.notification != null) {
        _showForegroundNotification(message);
      }
    });
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await ChatRepository().upsertDeviceToken(token, platform);
    } catch (e) {
      debugPrint('Failed to save device token: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    const androidSpecifics = AndroidNotificationDetails(
      'chat_messages_channel',
      'Chat Messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFFFF7F50), // Coral color from app theme
    );
    const platformSpecifics = NotificationDetails(android: androidSpecifics);

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    // We can embed the route in the payload so `onDidReceiveNotificationResponse` can navigate
    String payload = '';
    final roomId = message.data['room_id'];
    final senderId = message.data['sender_id'];
    if (roomId != null && senderId != null) {
      payload = '/chat/$roomId?otherUserId=$senderId';
    }

    await _localNotifications.show(
      id: notificationId,
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? '',
      notificationDetails: platformSpecifics,
      payload: payload,
    );
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      _navigateToRoute(response.payload!);
    }
  }

  void _onFcmMessageOpenedApp(RemoteMessage message) {
    final roomId = message.data['room_id'];
    final senderId = message.data['sender_id'];
    if (roomId != null && senderId != null) {
      _navigateToRoute('/chat/$roomId?otherUserId=$senderId');
    }
  }

  void _navigateToRoute(String route) {
    // Delay slightly to ensure router is ready if coming from terminated state
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        appRouter.push(route);
      } catch (e) {
        debugPrint('Failed to navigate from notification: $e');
      }
    });
  }
}
