with open('lib/features/profile/screens/profile_screen.dart', 'r') as f:
    c = f.read()

# Fix card background
c = c.replace(
    "color: AppColors.black,\n                          borderRadius: BorderRadius.only(",
    "color: const Color(0xFF1E1B15),\n                          borderRadius: BorderRadius.only("
)

# Fix back arrow
c = c.replace(
    "color: AppColors.creamLight,\n                                    ),\n                                  ),\n                                  if (_isMe)",
    "color: Colors.white,\n                                    ),\n                                  ),\n                                  if (_isMe)"
)

# Fix settings icon
c = c.replace(
    "color: AppColors.creamLight,\n                                      ),\n                                    )\n                                  else",
    "color: Colors.white,\n                                      ),\n                                    )\n                                  else"
)

# Fix avatar person icon
c = c.replace(
    "color: AppColors.creamLight,\n                                          )\n                                        : null,",
    "color: Colors.white,\n                                          )\n                                        : null,"
)

# Fix display name
c = c.replace(
    "color: AppColors.creamLight,\n                                        ),\n                                        maxLines: 1,",
    "color: Colors.white,\n                                        ),\n                                        maxLines: 1,"
)

# Fix @username
c = c.replace(
    "color: AppColors.creamLight\n                                              .withOpacity(0.6),",
    "color: Colors.white70,"
)

# Fix stats text
c = c.replace(
    "color: AppColors.creamLight,\n            ),\n          ),\n          const SizedBox(height: 2),\n          Text(\n            label,\n            style: TextStyle(\n              fontSize: 12,\n              fontWeight: FontWeight.w600,\n              color: AppColors.creamLight.withOpacity(0.6),",
    "color: Colors.white,\n            ),\n          ),\n          const SizedBox(height: 2),\n          Text(\n            label,\n            style: TextStyle(\n              fontSize: 12,\n              fontWeight: FontWeight.w600,\n              color: Colors.white70,"
)

# Fix action button text
c = c.replace(
    "color: AppColors.creamLight,\n            fontWeight: FontWeight.bold,\n            fontSize: 13,",
    "color: Colors.white,\n            fontWeight: FontWeight.bold,\n            fontSize: 13,"
)

# Fix action button background (when not primary)
c = c.replace(
    "AppColors.creamLight.withOpacity(0.1)",
    "Colors.white.withOpacity(0.1)"
)

with open('lib/features/profile/screens/profile_screen.dart', 'w') as f:
    f.write(c)
