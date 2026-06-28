with open('lib/features/home/screens/feed_view_all_screen.dart', 'r') as f:
    c = f.read()
c = c.replace(
    "color: AppColors.creamLight,\n                            fontSize: 10,",
    "color: Colors.white,\n                            fontSize: 10,"
)
c = c.replace(
    "color: AppColors.creamLight,\n                              fontSize: 12,",
    "color: Colors.white,\n                              fontSize: 12,"
)
c = c.replace(
    "color: _isLiked ? AppColors.coral : AppColors.creamLight,",
    "color: _isLiked ? AppColors.coral : Colors.white,"
)
with open('lib/features/home/screens/feed_view_all_screen.dart', 'w') as f:
    f.write(c)

with open('lib/features/home/screens/home_feed_screen.dart', 'r') as f:
    c = f.read()
c = c.replace(
    "color: AppColors\n                                                                  .creamLight,\n                                                              fontSize: 10,",
    "color: Colors.white,\n                                                              fontSize: 10,"
)
c = c.replace(
    "color: AppColors\n                                                                  .creamLight,\n                                                              fontSize: 11,",
    "color: Colors.white,\n                                                              fontSize: 11,"
)
c = c.replace(
    "color: AppColors\n                                                          .creamLight,\n                                                      fontSize: 14,",
    "color: Colors.white,\n                                                      fontSize: 14,"
)
with open('lib/features/home/screens/home_feed_screen.dart', 'w') as f:
    f.write(c)
