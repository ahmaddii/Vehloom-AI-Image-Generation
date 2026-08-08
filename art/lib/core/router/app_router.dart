import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/screens/animated_splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen_1.dart';
import '../../features/onboarding/screens/onboarding_screen_2.dart';
import '../../features/onboarding/screens/onboarding_screen_3.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/auth_options_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_feed_screen.dart';
import '../../features/artwork_detail/screens/artwork_detail_screen.dart';
import '../../features/upload/screens/upload_artwork_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/top_art/screens/top_art_of_day_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/followers_list_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/story/screens/story_viewer_screen.dart';
import '../../data/models/story_model.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/home/screens/feed_view_all_screen.dart';
import '../../features/ai_art/screens/ai_art_generation_screen.dart';
import '../../features/chat/screens/inbox_screen.dart';
import '../../features/chat/screens/chat_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _authRefresh = GoRouterRefreshStream(
  Supabase.instance.client.auth.onAuthStateChange,
);

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _authRefresh,
  observers: [homeRouteObserver],
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final location = state.uri.path;
    final hasOAuthCode =
        state.uri.queryParameters.containsKey('code') ||
        state.uri.fragment.contains('access_token') ||
        state.uri.queryParameters.containsKey('error');
    final isAuthRoute =
        location == '/login' ||
        location == '/signup' ||
        location == '/forgot-password' ||
        location == '/auth-options' ||
        location.contains('login-callback');
    final isOnboardingRoute = location.startsWith('/onboarding');

    // 1. If user is logged in, redirect away from auth and onboarding routes directly to Home feed '/'
    if (isLoggedIn) {
      if (isAuthRoute || isOnboardingRoute) {
        if (location == '/splash') return null; // Let splash play
        return '/';
      }
      return null;
    }

    // 2. If OAuth code/token is present in the URI, Supabase is exchanging tokens.
    // DO NOT redirect to onboarding while OAuth exchange is in progress!
    if (hasOAuthCode || location.contains('login-callback')) {
      return null;
    }

    // 3. If not logged in, and trying to access home directly without splash (and not during OAuth)
    if (!isLoggedIn && location == '/') {
      return '/onboarding1';
    }

    return null;
  },
  routes: [
    // Splash
    GoRoute(
      path: '/splash',
      builder: (context, state) => const AnimatedSplashScreen(),
    ),

    // Onboarding
    GoRoute(
      path: '/onboarding1',
      builder: (context, state) => const OnboardingScreen1(),
    ),
    GoRoute(
      path: '/onboarding2',
      builder: (context, state) => const OnboardingScreen2(),
    ),
    GoRoute(
      path: '/onboarding3',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen3(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ),

    // Auth
    GoRoute(
      path: '/auth-options',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AuthOptionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Home / Feed
    GoRoute(path: '/', builder: (context, state) => const HomeFeedScreen()),
    GoRoute(
      path: '/feed-view-all',
      builder: (context, state) => const FeedViewAllScreen(),
    ),

    // AI Art Generation
    GoRoute(
      path: '/ai-art',
      builder: (context, state) => const AiArtGenerationScreen(),
    ),

    // Artwork Details
    GoRoute(
      path: '/artwork/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ArtworkDetailScreen(artworkId: id);
      },
    ),

    // Upload
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadArtworkScreen(),
    ),

    // Search
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),

    // Top Art of the Day
    GoRoute(
      path: '/top-art',
      builder: (context, state) => const TopArtOfDayScreen(),
    ),

    // Profiles
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        return ProfileScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/followers/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        return FollowersListScreen(userId: userId);
      },
    ),

    // Notifications
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    // Settings
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Story Viewer
    GoRoute(
      path: '/story/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        final extra = state.extra as Map<String, dynamic>;
        final stories = extra['stories'] as List<StoryModel>;
        return StoryViewerScreen(stories: stories, initialUserId: userId);
      },
    ),

    // Chat
    GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),
    GoRoute(
      path: '/chat/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? '';
        final otherUserId = state.uri.queryParameters['otherUserId'] ?? '';
        return ChatScreen(roomId: roomId, otherUserId: otherUserId);
      },
    ),
  ],
);
