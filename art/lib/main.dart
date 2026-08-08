import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/services/preferences_service.dart';
import 'core/services/notification_service.dart';
import 'data/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make the top status bar (wifi, battery, time) transparent globally
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android: Dark icons
      statusBarBrightness: Brightness.light, // iOS: Dark icons
    ),
  );
  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  // Automatically ensure profile exists on successful OAuth or Password login
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.tokenRefreshed) {
      AuthRepository().ensureProfileExists();
    }
  });

  // Initialize global persistent user preferences
  await PreferencesService().init();

  // Initialize notifications
  await NotificationService().init();

  runApp(const MyApp());
}
