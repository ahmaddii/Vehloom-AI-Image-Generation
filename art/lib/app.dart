import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/preferences_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = PreferencesService();
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Art Sharing',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: preferences.darkModeEnabled
              ? ThemeMode.dark
              : ThemeMode.light,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
