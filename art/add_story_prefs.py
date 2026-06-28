with open('lib/core/services/preferences_service.dart', 'r') as f:
    c = f.read()

import_statement = "import '../../data/models/story_model.dart';\n"
if "models/story_model.dart" not in c:
    c = c.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + import_statement)

new_methods = """  // Story viewed state
  void markStoryViewed(String userId, DateTime createdAt) {
    if (!_isInitialized) return;
    final key = 'story_viewed_$userId';
    final lastViewed = _prefs.getString(key);
    
    // Only update if the new story is newer than the last viewed
    if (lastViewed != null) {
      final lastViewedDate = DateTime.parse(lastViewed);
      if (createdAt.isBefore(lastViewedDate) || createdAt.isAtSameMomentAs(lastViewedDate)) {
        return;
      }
    }
    
    _prefs.setString(key, createdAt.toIso8601String());
    notifyListeners();
  }

  bool hasUnviewedStories(String userId, List<StoryModel> stories) {
    if (!_isInitialized || stories.isEmpty) return false;
    final key = 'story_viewed_$userId';
    final lastViewed = _prefs.getString(key);
    
    if (lastViewed == null) return true; // Never viewed any stories from this user
    
    final lastViewedDate = DateTime.parse(lastViewed);
    // If any story is strictly newer than lastViewedDate, return true
    for (var story in stories) {
      if (story.createdAt.isAfter(lastViewedDate)) return true;
    }
    return false;
  }
}"""

c = c.replace("}\n", new_methods + "\n", 1)

with open('lib/core/services/preferences_service.dart', 'w') as f:
    f.write(c)
