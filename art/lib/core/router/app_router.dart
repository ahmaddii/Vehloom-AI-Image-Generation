import 'package:go_router/go_router.dart';

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
import '../../features/settings/screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding1',
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
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Home / Feed
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeFeedScreen(),
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
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),

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
  ],
);
