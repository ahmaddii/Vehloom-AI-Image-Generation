with open('lib/features/onboarding/screens/onboarding_screen_3.dart', 'r') as f:
    c = f.read()

# Make it rebuild on theme change
if "Theme.of(context);" not in c:
    c = c.replace(
        "  Widget build(BuildContext context) {",
        "  Widget build(BuildContext context) {\n    Theme.of(context); // Force rebuild on theme change"
    )

# Fix Scaffold background
c = c.replace(
    "backgroundColor: AppColors.black,",
    "backgroundColor: AppColors.creamBg,"
)

# Fix Gradient colors
c = c.replace(
    """                    colors: [
                      AppColors.black.withValues(alpha: 0.0),
                      AppColors.black.withValues(alpha: 0.2),
                      AppColors.black.withValues(alpha: 0.8),
                      AppColors.black,
                      AppColors.black,
                    ],""",
    """                    colors: [
                      AppColors.creamBg.withValues(alpha: 0.0),
                      AppColors.creamBg.withValues(alpha: 0.2),
                      AppColors.creamBg.withValues(alpha: 0.8),
                      AppColors.creamBg,
                      AppColors.creamBg,
                    ],"""
)

# Fix Title Text
c = c.replace(
    """                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1,
                      ),""",
    """                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1,
                      ),"""
)

# Fix Subtitle Text
c = c.replace(
    """                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),""",
    """                      style: TextStyle(
                        color: AppColors.black.withValues(alpha: 0.7),
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),"""
)

# Fix Button Container Color
c = c.replace(
    """                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2823),
                            borderRadius: BorderRadius.circular(36),
                          ),""",
    """                          decoration: BoxDecoration(
                            color: AppColors.creamLight,
                            borderRadius: BorderRadius.circular(36),
                          ),"""
)

# Fix Draggable Capsule Color
c = c.replace(
    """                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),""",
    """                                    decoration: BoxDecoration(
                                      color: AppColors.black,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),"""
)

# Fix Button Text Color
c = c.replace(
    """                                      style: TextStyle(
                                        color: AppColors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),""",
    """                                      style: TextStyle(
                                        color: AppColors.creamBg,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),"""
)

# Fix AnimatedChevrons color
c = c.replace(
    """              color: Colors.white.withValues(alpha: opacity.clamp(0.3, 1.0)),""",
    """              color: AppColors.black.withValues(alpha: opacity.clamp(0.3, 1.0)),"""
)

with open('lib/features/onboarding/screens/onboarding_screen_3.dart', 'w') as f:
    f.write(c)

