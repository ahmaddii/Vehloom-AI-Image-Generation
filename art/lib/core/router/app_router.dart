import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/screens/onboarding_screen_1.dart';
import '../../features/onboarding/screens/onboarding_screen_2.dart';
import '../../features/onboarding/screens/onboarding_screen_3.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
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
  initialLocation: Supabase.instance.client.auth.currentSession == null
      ? '/onboarding1'
      : '/',
  refreshListenable: _authRefresh,
  observers: [homeRouteObserver],
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final location = state.uri.path;
    final isAuthRoute =
        location == '/login' ||
        location == '/signup' ||
        location == '/forgot-password';
    final isOnboardingRoute = location.startsWith('/onboarding');

    if (isLoggedIn && (isAuthRoute || isOnboardingRoute)) {
      return '/';
    }

    return null;
  },
  routes: [
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
      builder: (context, state) => const OnboardingScreen3(),
    ),

    // Auth
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
        return StoryViewerScreen(
          stories: stories,
          initialUserId: userId,
        );
      },
    ),
  ],
);
