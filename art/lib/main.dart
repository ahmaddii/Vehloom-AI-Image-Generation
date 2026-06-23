import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/services/preferences_service.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  // Initialize global persistent user preferences
  await PreferencesService().init();

  runApp(const MyApp());

  // Initialize push notifications asynchronously after the app UI starts
  // so that permission dialogs have an Activity to attach to.
  PushNotificationService().init().catchError((e) {
    debugPrint('Error initializing push notifications: $e');
  });
}
