import re

with open('lib/features/story/screens/story_viewer_screen.dart', 'r') as f:
    c = f.read()

# Add import for PreferencesService if not present
if "preferences_service.dart" not in c:
    c = c.replace(
        "import '../../../data/models/story_model.dart';",
        "import '../../../data/models/story_model.dart';\nimport '../../../core/services/preferences_service.dart';"
    )

old_start = """  void _startStory() {
    _percent = 0.0;
    _isPaused = false;
    _resumeStory();
  }"""

new_start = """  void _startStory() {
    _percent = 0.0;
    _isPaused = false;
    // Mark story as viewed as soon as it starts displaying
    PreferencesService().markStoryViewed(_currentStory.userId, _currentStory.createdAt);
    _resumeStory();
  }"""

c = c.replace(old_start, new_start)

with open('lib/features/story/screens/story_viewer_screen.dart', 'w') as f:
    f.write(c)

