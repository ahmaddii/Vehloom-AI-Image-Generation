with open('lib/features/upload/screens/upload_artwork_screen.dart', 'r') as f:
    c = f.read()

# Import the custom animated switch if not present
if "custom_animated_switch.dart" not in c:
    c = c.replace(
        "import '../../../core/constants/app_colors.dart';",
        "import '../../../core/constants/app_colors.dart';\nimport '../../../core/widgets/custom_animated_switch.dart';"
    )

old_switch = """                      child: SwitchListTile(
                        title: Text(
                          'Also post to Story',
                          style: TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Followers will see this artwork on your active stories for 24 hours.',
                          style: TextStyle(
                            color: AppColors.darkGrey,
                            fontSize: 11,
                          ),
                        ),
                        activeColor: AppColors.coral,
                        activeTrackColor: AppColors.coral.withOpacity(0.3),
                        value: _alsoPostToStory,
                        onChanged: _isUploading
                            ? null
                            : (val) {
                                setState(() {
                                  _alsoPostToStory = val;
                                });
                              },
                      ),"""

new_switch = """                      child: ListTile(
                        onTap: _isUploading
                            ? null
                            : () {
                                setState(() {
                                  _alsoPostToStory = !_alsoPostToStory;
                                });
                              },
                        title: Text(
                          'Also post to Story',
                          style: TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Followers will see this artwork on your active stories for 24 hours.',
                          style: TextStyle(
                            color: AppColors.darkGrey,
                            fontSize: 11,
                          ),
                        ),
                        trailing: CustomAnimatedSwitch(
                          value: _alsoPostToStory,
                          activeColor: AppColors.coral,
                          activeIcon: Icons.auto_awesome,
                          inactiveIcon: Icons.circle_outlined,
                          onChanged: _isUploading
                              ? (val) {}
                              : (val) {
                                  setState(() {
                                    _alsoPostToStory = val;
                                  });
                                },
                        ),
                      ),"""

c = c.replace(old_switch, new_switch)

with open('lib/features/upload/screens/upload_artwork_screen.dart', 'w') as f:
    f.write(c)
