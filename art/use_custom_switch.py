with open('lib/features/settings/screens/settings_screen.dart', 'r') as f:
    c = f.read()

# Add import for CustomAnimatedSwitch
if "custom_animated_switch.dart" not in c:
    c = c.replace(
        "import 'package:flutter/cupertino.dart';",
        "import 'package:flutter/cupertino.dart';\nimport '../../../core/widgets/custom_animated_switch.dart';"
    )

# Replace Notifications switch
c = c.replace(
    "trailingWidget: CupertinoSwitch(\n                  value: _notificationsEnabled,\n                  activeColor: AppColors.coral,\n                  trackColor: AppColors.creamDark,\n                  thumbColor: AppColors.creamBg,\n                  onChanged: (val) async {",
    "trailingWidget: CustomAnimatedSwitch(\n                  value: _notificationsEnabled,\n                  activeColor: AppColors.coral,\n                  activeIcon: Icons.notifications_active,\n                  inactiveIcon: Icons.notifications_off_outlined,\n                  onChanged: (val) async {"
)

# Replace Dark Theme switch
c = c.replace(
    "trailingWidget: CupertinoSwitch(\n                  value: _darkModeEnabled,\n                  activeColor: AppColors.black,\n                  trackColor: AppColors.creamDark,\n                  thumbColor: AppColors.creamBg,\n                  onChanged: (val) async {",
    "trailingWidget: CustomAnimatedSwitch(\n                  value: _darkModeEnabled,\n                  activeColor: AppColors.black,\n                  activeIcon: Icons.dark_mode,\n                  inactiveIcon: Icons.light_mode_outlined,\n                  onChanged: (val) async {"
)

with open('lib/features/settings/screens/settings_screen.dart', 'w') as f:
    f.write(c)
