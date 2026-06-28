import re

files = [
    'lib/features/profile/screens/profile_screen.dart',
    'lib/features/home/screens/home_feed_screen.dart',
    'lib/features/home/screens/feed_view_all_screen.dart',
    'lib/features/top_art/screens/top_art_of_day_screen.dart',
    'lib/features/upload/screens/upload_artwork_screen.dart',
]

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    # Find the first build method in the file which is usually the screen's build method
    # and inject Theme.of(context);
    
    if "Theme.of(context);" not in content:
        pattern = r'(@override\s+Widget build\(BuildContext context\) \{)'
        replacement = r'\1\n    Theme.of(context); // Force rebuild on theme change'
        content = re.sub(pattern, replacement, content, count=1)
        
        with open(filepath, 'w') as f:
            f.write(content)

