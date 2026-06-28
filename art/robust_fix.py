import re

with open('lib/features/home/screens/home_feed_screen.dart', 'r') as f:
    c = f.read()

# 1. Strip all const wrappers
patterns = [
    r'const\s+(EdgeInsets\.all\([^\)]+\))',
    r'const\s+(EdgeInsets\.symmetric\([^\)]+\))',
    r'const\s+(SizedBox\([^\)]+\))',
    r'const\s+(BoxDecoration\([^\)]+\))',
    r'const\s+(Text\([^\)]+\))',
    r'const\s+(Icon\([^\)]+\))',
    r'const\s+(TextStyle\([^\)]+\))',
    r'const\s+(Row\([^\)]+\))',
    r'const\s+(Column\([^\)]+\))',
    r'const\s+(Center\([^\)]+\))',
    r'const\s+(Positioned\([^\)]+\))',
    r'const\s+(Padding\([^\)]+\))',
    r'const\s+(Divider\([^\)]+\))',
    r'const\s+(ThemeData\([^\)]+\))',
]

for p in patterns:
    c = re.sub(p, r'\1', c)

c = c.replace("const Text.rich(", "Text.rich(")
c = c.replace("const SliverGridDelegateWithFixedCrossAxisCount(", "SliverGridDelegateWithFixedCrossAxisCount(")

# 2. Add Theme.of(context) injection if not present
if "Theme.of(context);" not in c:
    c = c.replace(
        "  Widget build(BuildContext context) {",
        "  Widget build(BuildContext context) {\n    Theme.of(context); // Force rebuild on theme change"
    )

# 3. Add import for PreferencesService if not present
if "preferences_service.dart" not in c:
    c = c.replace(
        "import '../../../core/constants/app_colors.dart';",
        "import '../../../core/constants/app_colors.dart';\nimport '../../../core/services/preferences_service.dart';"
    )

# 4. Fix AppColors.creamLight issue for overlay texts (make them white)
c = c.replace(
    """                                                            style: TextStyle(
                                                              color: AppColors
                                                                  .creamLight,
                                                              fontSize: 10,""",
    """                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,"""
)

c = c.replace(
    """                                                            style: TextStyle(
                                                              color: AppColors
                                                                  .creamLight,
                                                              fontSize: 11,""",
    """                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 11,"""
)

# 5. Fix black person icon for user overlay
c = c.replace(
    """                                                                    color: AppColors
                                                                        .black,""",
    """                                                                    color: Colors.black,"""
)

# 6. Implement Story logic
old_logic = """                          final creatorStories = _activeStories
                              .where((story) => story.userId == creator.id)
                              .toList();
                          final hasStories = creatorStories.isNotEmpty;"""

new_logic = """                          final creatorStories = _activeStories
                              .where((story) => story.userId == creator.id)
                              .toList();
                          final hasStories = creatorStories.isNotEmpty;
                          final hasUnviewed = hasStories && PreferencesService().hasUnviewedStories(creator.id, creatorStories);"""

c = c.replace(old_logic, new_logic)

old_gradient = """                                          gradient: hasStories
                                              ? const SweepGradient(
                                                  colors: [
                                                    AppColors.coral,
                                                    Color(0xFFFF007F),
                                                    Color(0xFFFF7F00),
                                                    AppColors.coral,
                                                  ],
                                                )
                                              : null,"""

new_gradient = """                                          gradient: hasUnviewed
                                              ? const SweepGradient(
                                                  colors: [
                                                    AppColors.coral,
                                                    Color(0xFFFF007F),
                                                    Color(0xFFFF7F00),
                                                    AppColors.coral,
                                                  ],
                                                )
                                              : null,
                                          border: (hasStories && !hasUnviewed)
                                              ? Border.all(color: AppColors.lightGrey, width: 2.5)
                                              : null,"""

c = c.replace(old_gradient, new_gradient)

old_listview = """                    : ListView.builder(
                        scrollDirection: Axis.horizontal,"""

new_listview = """                    : ListenableBuilder(
                        listenable: PreferencesService(),
                        builder: (context, _) {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,"""

c = c.replace(old_listview, new_listview)

# Fix the end of the builder using strict string replacement (it's around line 730)
old_end = """                            ),
                          );
                        },
                      ),
              ),"""

new_end = """                            ),
                          );
                        },
                      );
                        },
                      ),
              ),"""

c = c.replace(old_end, new_end)

with open('lib/features/home/screens/home_feed_screen.dart', 'w') as f:
    f.write(c)

