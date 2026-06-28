with open('lib/features/story/screens/story_viewer_screen.dart', 'r') as f:
    c = f.read()

old_start = """  void _startStory() {
    _percent = 0.0;
    _isPaused = false;
    // Mark story as viewed as soon as it starts displaying
    PreferencesService().markStoryViewed(_currentStory.userId, _currentStory.createdAt);
    _resumeStory();
  }"""

new_start = """  void _startStory() {
    _percent = 0.0;
    _isPaused = false;
    // Mark story as viewed as soon as it starts displaying, safely after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PreferencesService().markStoryViewed(_currentStory.userId, _currentStory.createdAt);
    });
    _resumeStory();
  }"""

c = c.replace(old_start, new_start)

with open('lib/features/story/screens/story_viewer_screen.dart', 'w') as f:
    f.write(c)

