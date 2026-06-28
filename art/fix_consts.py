import re
import sys

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Regex to remove const before common widgets that might contain AppColors
    patterns = [
        r'const\s+(Text\()',
        r'const\s+(TextStyle\()',
        r'const\s+(Icon\()',
        r'const\s+(BoxDecoration\()',
        r'const\s+(Border\()',
        r'const\s+(BorderSide\()',
        r'const\s+(Center\()',
        r'const\s+(Padding\()',
        r'const\s+(Row\()',
        r'const\s+(Column\()',
        r'const\s+(Container\()',
        r'const\s+(SizedBox\()',
        r'const\s+(InputDecoration\()',
        r'const\s+(Divider\()',
        r'const\s+(CircleAvatar\()',
    ]

    for p in patterns:
        content = re.sub(p, r'\1', content)

    with open(filepath, 'w') as f:
        f.write(content)

fix_file('lib/features/home/screens/feed_view_all_screen.dart')
fix_file('lib/features/home/screens/home_feed_screen.dart')
