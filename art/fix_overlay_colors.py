with open('lib/features/home/screens/home_feed_screen.dart', 'r') as f:
    c = f.read()

# Replace the specific multi-line AppColors.creamLight with Colors.white
c = c.replace(
    "color: AppColors\n                                                                  .creamLight,",
    "color: Colors.white,"
)

c = c.replace(
    "color: AppColors\n                                                                        .black,",
    "color: Colors.black,"
)

c = c.replace(
    """                                                        Text(
                                                          artwork.title,
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .creamLight,""",
    """                                                        Text(
                                                          artwork.title,
                                                          style: TextStyle(
                                                            color: Colors.white,"""
)

with open('lib/features/home/screens/home_feed_screen.dart', 'w') as f:
    f.write(c)

with open('lib/features/home/screens/feed_view_all_screen.dart', 'r') as f:
    c = f.read()

c = c.replace(
    "color: AppColors\n                                                                  .creamLight,",
    "color: Colors.white,"
)

c = c.replace(
    "color: AppColors\n                                                                        .black,",
    "color: Colors.black,"
)

c = c.replace(
    """                                                        Text(
                                                          artwork.title,
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .creamLight,""",
    """                                                        Text(
                                                          artwork.title,
                                                          style: TextStyle(
                                                            color: Colors.white,"""
)

with open('lib/features/home/screens/feed_view_all_screen.dart', 'w') as f:
    f.write(c)
