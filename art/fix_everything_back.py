import re

# 1. ProfileScreen fixes
with open('lib/features/profile/screens/profile_screen.dart', 'r') as f:
    c = f.read()

# Top card background and border
c = c.replace(
    "decoration: const BoxDecoration(\n                          color: AppColors.black,\n                          borderRadius: BorderRadius.only(",
    "decoration: BoxDecoration(\n                          color: const Color(0xFF1E1B15),\n                          border: Border.all(color: Colors.white24, width: 1),\n                          borderRadius: const BorderRadius.only("
)
# Top card title / text colors (using regex to remove const and replace AppColors.creamLight with Colors.white)
c = c.replace("color: AppColors.creamLight", "color: Colors.white")
# But wait, we also had Colors.white70 for the secondary text.
# Let's just fix it manually below.
c = c.replace("color: AppColors.creamLight.withOpacity(0.6)", "color: Colors.white70")
# Tab divider
c = c.replace("dividerColor: AppColors.lightGrey,", "dividerColor: Colors.transparent,")
# Artwork text
c = c.replace(
"""                    style: const TextStyle(
                      color: AppColors.creamLight,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),""",
"""                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),""")

# Remove invalid consts in profile_screen
patterns = [
    r'const\s+(Text\()', r'const\s+(TextStyle\()', r'const\s+(Icon\()',
    r'const\s+(BoxDecoration\()', r'const\s+(Center\()', r'const\s+(Divider\()'
]
for p in patterns:
    c = re.sub(p, r'\1', c)

with open('lib/features/profile/screens/profile_screen.dart', 'w') as f:
    f.write(c)

# 2. HomeFeedScreen fixes (strip const)
with open('lib/features/home/screens/home_feed_screen.dart', 'r') as f:
    c = f.read()

for p in patterns:
    c = re.sub(p, r'\1', c)
c = c.replace("const Text.rich(", "Text.rich(")

with open('lib/features/home/screens/home_feed_screen.dart', 'w') as f:
    f.write(c)
