with open('lib/features/home/screens/home_feed_screen.dart', 'r') as f:
    c = f.read()

# Find the creator stories logic
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

# Find the gradient logic
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

# Wrap ListView.builder in ListenableBuilder
old_listview = """                    : ListView.builder(
                        scrollDirection: Axis.horizontal,"""

new_listview = """                    : ListenableBuilder(
                        listenable: PreferencesService(),
                        builder: (context, _) {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,"""

c = c.replace(old_listview, new_listview)

# Add closing bracket for ListenableBuilder
old_listview_end = """                            ),
                          );
                        },
                      ),
              ),"""

new_listview_end = """                            ),
                          );
                        },
                      );
                        },
                      ),
              ),"""
# Actually, it's safer to just replace using regex for the end of the builder.
import re
c = re.sub(
    r'(                            \),\n                          \);\n                        \},\n                      \),)',
    r'\1\n                        },',
    c
)

with open('lib/features/home/screens/home_feed_screen.dart', 'w') as f:
    f.write(c)
