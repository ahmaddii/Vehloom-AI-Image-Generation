with open('lib/features/settings/screens/settings_screen.dart', 'r') as f:
    c = f.read()

# Add Cupertino import if not exists
if "import 'package:flutter/cupertino.dart';" not in c:
    c = c.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/cupertino.dart';"
    )

# Replace Notifications Switch
c = c.replace(
    "trailingWidget: Switch(\n                  value: _notificationsEnabled,\n                  activeColor: AppColors.creamBg,\n                  activeTrackColor: AppColors.black,\n                  inactiveThumbColor: AppColors.darkGrey,\n                  inactiveTrackColor: AppColors.creamDark,",
    "trailingWidget: CupertinoSwitch(\n                  value: _notificationsEnabled,\n                  activeColor: AppColors.coral,\n                  trackColor: AppColors.creamDark,\n                  thumbColor: AppColors.creamBg,"
)

# Replace Dark Theme Switch
c = c.replace(
    "trailingWidget: Switch(\n                  value: _darkModeEnabled,\n                  activeColor: AppColors.creamBg,\n                  activeTrackColor: AppColors.coral,\n                  inactiveThumbColor: AppColors.darkGrey,\n                  inactiveTrackColor: AppColors.creamDark,",
    "trailingWidget: CupertinoSwitch(\n                  value: _darkModeEnabled,\n                  activeColor: AppColors.black,\n                  trackColor: AppColors.creamDark,\n                  thumbColor: AppColors.creamBg,"
)

with open('lib/features/settings/screens/settings_screen.dart', 'w') as f:
    f.write(c)
