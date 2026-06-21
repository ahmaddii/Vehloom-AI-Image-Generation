import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _privateAccountEnabled = false;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _userEmail = AuthRepository().currentUser?.email ?? 'No email';
  }

  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.creamBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Change Password',
                style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.black),
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: AppColors.darkGrey),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.coral)),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.black),
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: TextStyle(color: AppColors.darkGrey),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.coral)),
                      ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.darkGrey)),
                ),
                isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.black,
                          foregroundColor: AppColors.creamLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            setDialogState(() {
                              isSubmitting = true;
                            });
                            try {
                              await AuthRepository().updatePassword(newPasswordController.text);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('Update'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

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
                onTap: _showChangePasswordDialog,
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.mail_outline,
                title: 'Email',
                trailingText: _userEmail,
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
                onTap: () async {
                  await AuthRepository().signOut();
                  if (mounted) {
                    context.go('/login');
                  }
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
