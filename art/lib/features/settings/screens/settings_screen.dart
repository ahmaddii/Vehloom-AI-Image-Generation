import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _privateAccountEnabled = false;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.darkGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    bool isRed = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isRed ? Colors.red : AppColors.black,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isRed ? Colors.red : AppColors.black,
                ),
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withOpacity(0.4),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: AppColors.black.withOpacity(0.3),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(color: AppColors.lightGrey, height: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ACCOUNT SECTION
            _buildSectionHeader('Account'),
            _buildCardContainer([
              _buildListTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                onTap: () => context.push('/edit-profile'),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.mail_outline,
                title: 'Email',
                trailingText: 'hey@maya.art',
                onTap: () {},
              ),
            ]),

            // PREFERENCES SECTION
            _buildSectionHeader('Preferences'),
            _buildCardContainer([
              _buildListTile(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                trailingWidget: Switch(
                  value: _notificationsEnabled,
                  activeColor: AppColors.black,
                  activeTrackColor: AppColors.black,
                  inactiveThumbColor: AppColors.creamLight,
                  inactiveTrackColor: AppColors.creamDark,
                  onChanged: (val) {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                  },
                ),
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                trailingWidget: Switch(
                  value: _darkModeEnabled,
                  activeColor: AppColors.black,
                  activeTrackColor: AppColors.black,
                  inactiveThumbColor: AppColors.creamLight,
                  inactiveTrackColor: AppColors.creamDark,
                  onChanged: (val) {
                    setState(() {
                      _darkModeEnabled = val;
                    });
                  },
                ),
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.language_outlined,
                title: 'Language',
                trailingText: 'English',
                onTap: () {},
              ),
            ]),

            // PRIVACY SECTION
            _buildSectionHeader('Privacy'),
            _buildCardContainer([
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Private Account',
                trailingWidget: Switch(
                  value: _privateAccountEnabled,
                  activeColor: AppColors.black,
                  activeTrackColor: AppColors.black,
                  inactiveThumbColor: AppColors.creamLight,
                  inactiveTrackColor: AppColors.creamDark,
                  onChanged: (val) {
                    setState(() {
                      _privateAccountEnabled = val;
                    });
                  },
                ),
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.person_off_outlined,
                title: 'Blocked Users',
                onTap: () {},
              ),
            ]),

            // ACCOUNT ACTIONS SECTION
            _buildSectionHeader('Account Actions'),
            _buildCardContainer([
              _buildListTile(
                icon: Icons.logout,
                title: 'Log Out',
                isRed: true,
                onTap: () {
                  context.go('/login');
                },
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                isRed: true,
                onTap: () {},
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
