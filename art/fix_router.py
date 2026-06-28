with open('lib/core/router/app_router.dart', 'r') as f:
    c = f.read()

# Add import
if "import '../../features/onboarding/screens/splash_screen.dart';" not in c:
    c = c.replace(
        "import '../../features/onboarding/screens/onboarding_screen_1.dart';",
        "import '../../features/onboarding/screens/splash_screen.dart';\nimport '../../features/onboarding/screens/onboarding_screen_1.dart';"
    )

# Change initialLocation
c = c.replace(
    "initialLocation: Supabase.instance.client.auth.currentSession == null\n      ? '/onboarding1'\n      : '/',",
    "initialLocation: '/splash',"
)
# Change redirect logic to allow splash
c = c.replace(
    """    if (isLoggedIn && (isAuthRoute || isOnboardingRoute)) {
      return '/';
    }

    return null;""",
    """    if (isLoggedIn && (isAuthRoute || isOnboardingRoute)) {
      if (location == '/splash') return null; // Let splash play
      return '/';
    }
    
    // If not logged in, but trying to go home directly without splash (edge case)
    if (!isLoggedIn && location == '/') {
      return '/onboarding1';
    }

    return null;"""
)

# Add splash route to routes
c = c.replace(
    "  routes: [\n    // Onboarding",
    "  routes: [\n    // Splash\n    GoRoute(\n      path: '/splash',\n      builder: (context, state) => const CustomSplashScreen(),\n    ),\n    // Onboarding"
)

with open('lib/core/router/app_router.dart', 'w') as f:
    f.write(c)
