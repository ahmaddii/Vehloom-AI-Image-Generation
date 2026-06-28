with open('lib/core/router/app_router.dart', 'r') as f:
    c = f.read()

c = c.replace(
"""    GoRoute(
      path: '/onboarding1',
      builder: (context, state) => const OnboardingScreen1(),
    ),""",
"""    GoRoute(
      path: '/onboarding1',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen1(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ),"""
)

c = c.replace(
"""    GoRoute(path: '/', builder: (context, state) => const HomeFeedScreen()),""",
"""    GoRoute(
      path: '/',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const HomeFeedScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ),"""
)

with open('lib/core/router/app_router.dart', 'w') as f:
    f.write(c)
