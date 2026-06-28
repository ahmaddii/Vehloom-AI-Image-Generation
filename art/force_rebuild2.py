import re

files = [
    'lib/features/search/screens/search_screen.dart',
    'lib/features/notifications/screens/notifications_screen.dart',
]

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    if "Theme.of(context);" not in content:
        pattern = r'(@override\s+Widget build\(BuildContext context\) \{)'
        replacement = r'\1\n    Theme.of(context); // Force rebuild on theme change'
        content = re.sub(pattern, replacement, content, count=1)
        
        with open(filepath, 'w') as f:
            f.write(content)

