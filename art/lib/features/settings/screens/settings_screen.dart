import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/services/preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _language = 'English';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _userEmail = AuthRepository().currentUser?.email ?? 'No email';
    final prefs = PreferencesService();
    _notificationsEnabled = prefs.notificationsEnabled;
    _darkModeEnabled = prefs.darkModeEnabled;
    _language = prefs.language;
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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDeleting = false;
        int deleteStep = 0;
        final List<String> loadingSteps = [
          'Connecting to server...',
          'Deleting personal profile data...',
          'Wiping artworks & stories...',
          'Removing comments & likes...',
          'Clearing followers list...',
          'Finalizing account deletion...',
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.creamBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isDeleting ? 'Deleting Account' : 'Are you sure?',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: isDeleting
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(color: Colors.red),
                        const SizedBox(height: 24),
                        Text(
                          loadingSteps[deleteStep],
                          style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This action cannot be undone. You will permanently lose:',
                          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildDeleteBullet('Profile & Personal Data'),
                        _buildDeleteBullet('All Artworks & Stories'),
                        _buildDeleteBullet('Comments & Likes'),
                        _buildDeleteBullet('Followers & Following'),
                      ],
                    ),
              actions: isDeleting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.darkGrey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: AppColors.creamLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          setDialogState(() {
                            isDeleting = true;
                          });

                          // Fake animated loading sequence to show deep scrubbing
                          for (int i = 0; i < loadingSteps.length; i++) {
                            if (i > 0) {
                              if (context.mounted) {
                                setDialogState(() {
                                  deleteStep = i;
                                });
                              }
                            }
                            await Future.delayed(const Duration(milliseconds: 900));
                          }

                          try {
                            final userId = AuthRepository().currentUser?.id;
                            if (userId != null) {
                              // Trigger full database wipe for the user
                              await Supabase.instance.client.rpc('delete_user');
                            }
                            await AuthRepository().signOut();
                            if (context.mounted) {
                              Navigator.pop(context); // close dialog
                              context.go('/login');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                                deleteStep = 0;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Yes, Delete Everything'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.close, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppColors.black, fontSize: 14)),
        ],
      ),
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
                  activeColor: AppColors.creamBg,
                  activeTrackColor: AppColors.black,
                  inactiveThumbColor: AppColors.darkGrey,
                  inactiveTrackColor: AppColors.creamDark,
                  onChanged: (val) async {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                    await PreferencesService().setNotificationsEnabled(val);
                    final userId = AuthRepository().currentUser?.id;
                    if (userId != null) {
                      try {
                        await Supabase.instance.client
                            .from('profiles')
                            .update({'notifications_enabled': val})
                            .eq('id', userId);
                      } catch (_) {}
                    }
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val ? 'Notifications turned on' : 'Notifications turned off',
                            style: const TextStyle(
                              color: AppColors.creamLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: AppColors.black,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                ),
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.language_outlined,
                title: 'Language',
                trailingText: _language,
                onTap: _showLanguageDialog,
              ),
            ]),


            // SUPPORT & ABOUT SECTION
            _buildSectionHeader('Support & About'),
            _buildCardContainer([
              _buildListTile(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.report_problem_outlined,
                title: 'Report a Problem',
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.info_outline,
                title: 'Terms & Privacy Policy',
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
                onTap: _showDeleteAccountDialog,
              ),
            ]),

            const SizedBox(height: 40),
            
            // APP VERSION FOOTER
            const Center(
              child: Column(
                children: [
                  Text(
                    'ArtSharing',
                    style: TextStyle(
                      color: AppColors.darkGrey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: AppColors.darkGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Spanish', 'French', 'Urdu', 'German', 'Chinese'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.creamBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Select Language',
            style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                return ListTile(
                  title: Text(lang, style: const TextStyle(color: AppColors.black)),
                  trailing: _language == lang ? const Icon(Icons.check, color: AppColors.coral) : null,
                  onTap: () {
                    setState(() {
                      _language = lang;
                    });
                    PreferencesService().setLanguage(lang);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
