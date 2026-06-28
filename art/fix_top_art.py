with open('lib/features/top_art/screens/top_art_of_day_screen.dart', 'r') as f:
    c = f.read()

# Change Colors.white to AppColors.creamLight for the runner up and top art cards
c = c.replace(
    "color: Colors.white,\n              borderRadius: BorderRadius.circular(16),",
    "color: AppColors.creamLight,\n              borderRadius: BorderRadius.circular(16),"
)
c = c.replace(
    "color: Colors.white,\n              borderRadius: BorderRadius.circular(24),",
    "color: AppColors.creamLight,\n              borderRadius: BorderRadius.circular(24),"
)
c = c.replace(
    "color: Colors.white,\n                  borderRadius: BorderRadius.circular(20),",
    "color: AppColors.creamLight,\n                  borderRadius: BorderRadius.circular(20),"
)
c = c.replace(
    "color: Colors.white,\n          borderRadius: BorderRadius.circular(24),",
    "color: AppColors.creamLight,\n          borderRadius: BorderRadius.circular(24),"
)
c = c.replace(
    "color: Colors.white,\n            borderRadius: BorderRadius.circular(20),",
    "color: AppColors.creamLight,\n            borderRadius: BorderRadius.circular(20),"
)

with open('lib/features/top_art/screens/top_art_of_day_screen.dart', 'w') as f:
    f.write(c)
