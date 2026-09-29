import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/social_icons.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import 'package:image_cropper/image_cropper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxBioLength = 80; // TikTok standard bio character limit

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();

  int _bioCharCount = 0;
  List<String> _selectedSpecialties = [];

  final List<String> _allSpecialties = const [
    'Digital Art',
    'Concept Art',
    '3D & Animation',
    'Traditional Painting',
    'Anime & Manga',
    'Pixel Art',
    'Illustration',
    'Photography',
  ];

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';

  // --- Lock/edit state for social & portfolio links ---
  // Fields start locked (read-only display) and only become editable
  // once the user explicitly taps the pencil icon, like most apps do.
  bool _isEditingWebsite = false;
  bool _isEditingInstagram = false;
  String? _websiteError;
  String? _instagramError;

  // Snapshots so we can revert if the user cancels an in-progress edit.
  String _websiteSnapshot = '';
  String _instagramSnapshot = '';

  @override
  void initState() {
    super.initState();
    _bioController.addListener(_updateBioCount);
    _loadProfileData();
  }

  void _updateBioCount() {
    if (mounted) {
      setState(() {
        _bioCharCount = _bioController.text.length;
      });
    }
  }

  @override
  void dispose() {
    _bioController.removeListener(_updateBioCount);
    _displayNameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUserId.isNotEmpty) {
        final profile = await ProfileRepository().getProfile(_currentUserId);
        if (profile != null) {
          _profile = profile;
          _displayNameController.text = profile.displayName ?? '';
          _bioController.text = profile.bio ?? '';
          _websiteController.text = profile.websiteUrl ?? '';
          _instagramController.text = profile.instagramUsername ?? '';
          _selectedSpecialties = List<String>.from(profile.specialties);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cropAvatarImage(String sourcePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: AppColors.black,
            toolbarWidgetColor: AppColors.creamLight,
            activeControlsWidgetColor: AppColors.coral,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _imageFile = File(croppedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to crop image: $e')));
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        await _cropAvatarImage(pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // URL / username handling helpers
  // ---------------------------------------------------------------------

  /// Normalizes a website URL (adds https:// if missing) and validates it.
  /// Returns the normalized URL, or null if the input is invalid.
  String? _normalizeAndValidateUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) return ''; // empty is allowed (field is optional)

    if (!text.contains('://')) {
      text = 'https://$text';
    }

    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty ||
        !uri.host.contains('.')) {
      return null;
    }
    return uri.toString();
  }

  /// Validates an Instagram handle (letters, numbers, dots, underscores).
  /// Strips a leading '@' if present. Returns null if invalid.
  String? _normalizeAndValidateInstagram(String input) {
    var text = input.trim();
    if (text.isEmpty) return ''; // empty is allowed (field is optional)

    if (text.startsWith('@')) {
      text = text.substring(1);
    }

    final validPattern = RegExp(r'^[a-zA-Z0-9._]{1,30}$');
    if (!validPattern.hasMatch(text)) return null;
    return text;
  }

  void _startEditingWebsite() {
    setState(() {
      _websiteSnapshot = _websiteController.text;
      _websiteError = null;
      _isEditingWebsite = true;
    });
  }

  void _confirmWebsite() {
    final normalized = _normalizeAndValidateUrl(_websiteController.text);
    if (normalized == null) {
      setState(() {
        _websiteError = 'Enter a valid URL, e.g. yourportfolio.com';
      });
      return;
    }
    setState(() {
      _websiteController.text = normalized;
      _websiteError = null;
      _isEditingWebsite = false;
    });
  }

  void _cancelEditingWebsite() {
    setState(() {
      _websiteController.text = _websiteSnapshot;
      _websiteError = null;
      _isEditingWebsite = false;
    });
  }

  void _startEditingInstagram() {
    setState(() {
      _instagramSnapshot = _instagramController.text;
      _instagramError = null;
      _isEditingInstagram = true;
    });
  }

  void _confirmInstagram() {
    final normalized = _normalizeAndValidateInstagram(
      _instagramController.text,
    );
    if (normalized == null) {
      setState(() {
        _instagramError = 'Letters, numbers, "." and "_" only';
      });
      return;
    }
    setState(() {
      _instagramController.text = normalized;
      _instagramError = null;
      _isEditingInstagram = false;
    });
  }

  void _cancelEditingInstagram() {
    setState(() {
      _instagramController.text = _instagramSnapshot;
      _instagramError = null;
      _isEditingInstagram = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_currentUserId.isEmpty || _profile == null) return;

    // If a link field was left open in edit mode, try to confirm it first
    // so unsaved edits aren't silently lost.
    if (_isEditingWebsite) _confirmWebsite();
    if (_isEditingInstagram) _confirmInstagram();
    if (_websiteError != null || _instagramError != null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? avatarUrl = _profile!.avatarUrl;

      // 1. Upload avatar if selected
      if (_imageFile != null) {
        avatarUrl = await ProfileRepository().uploadAvatar(
          _imageFile!,
          _currentUserId,
        );
      }

      // 2. Update profile table row
      await ProfileRepository().updateProfile(
        id: _currentUserId,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: avatarUrl,
        websiteUrl: _websiteController.text.trim(),
        instagramUsername: _instagramController.text.trim(),
        specialties: _selectedSpecialties,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // UI building blocks
  // ---------------------------------------------------------------------

  Widget _sectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.darkGrey),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            color: AppColors.darkGrey,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    String? hint,
    String? label,
    Widget? prefixIcon,
    Color? borderColor,
  }) {
    final resolvedBorder = borderColor ?? AppColors.lightGrey;
    return InputDecoration(
      hintText: hint,
      labelText: label,
      prefixIcon: prefixIcon,
      fillColor: AppColors.creamLight,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: resolvedBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: resolvedBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  /// A locked/editable row for a social or portfolio link.
  /// Shows a read-only display with a pencil icon until the user taps it;
  /// only then does it turn into an editable text field with confirm/cancel.
  Widget _buildLockableLinkField({
    required String label,
    required Widget icon,
    required TextEditingController controller,
    required String emptyHint,
    required String editHint,
    required bool isEditing,
    required VoidCallback onEditTap,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final hasValue = controller.text.trim().isNotEmpty;

    if (!isEditing) {
      // Locked / display mode
      return Container(
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue ? controller.text : emptyHint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue ? AppColors.black : AppColors.lightGrey,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit $label',
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.darkGrey,
              onPressed: onEditTap,
            ),
          ],
        ),
      );
    }

    // Editable mode
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: _fieldDecoration(
            hint: editHint,
            prefixIcon: Padding(padding: const EdgeInsets.all(12), child: icon),
            borderColor: errorText != null ? Colors.redAccent : AppColors.black,
          ),
          onFieldSubmitted: (_) => onConfirm(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.lightGrey),
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.creamBg,
        title: Text(
          'Edit Profile',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _saveProfile,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.coral))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar section
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatarImage,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.coral,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: AppColors.creamLight,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (_profile?.avatarUrl != null &&
                                                _profile!.avatarUrl!.isNotEmpty
                                            ? CachedNetworkImageProvider(
                                                _profile!.avatarUrl!,
                                              )
                                            : null)
                                        as ImageProvider?,
                              child:
                                  _imageFile == null &&
                                      (_profile?.avatarUrl == null ||
                                          _profile!.avatarUrl!.isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      size: 52,
                                      color: AppColors.black,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.black,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.creamBg,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: AppColors.creamBg,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _pickAvatarImage,
                      child: const Text(
                        'Change Profile Photo',
                        style: TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Display Name field
                  _sectionHeader('Display Name', icon: Icons.badge_outlined),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: _fieldDecoration(hint: 'Enter display name'),
                  ),

                  const SizedBox(height: 24),

                  // Bio field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader('Bio', icon: Icons.short_text_rounded),
                      Text(
                        '$_bioCharCount / $_maxBioLength',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _bioCharCount >= _maxBioLength
                              ? AppColors.coral
                              : AppColors.lightGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bioController,
                    maxLength: _maxBioLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    maxLines: 3,
                    minLines: 2,
                    style: TextStyle(fontSize: 14, color: AppColors.black),
                    decoration:
                        _fieldDecoration(
                          hint: 'Add a bio to your profile...',
                          borderColor: _bioCharCount >= _maxBioLength
                              ? AppColors.coral
                              : AppColors.lightGrey,
                        ).copyWith(
                          counterText: '',
                          suffixIcon: _bioCharCount > 0
                              ? IconButton(
                                  icon: Icon(
                                    Icons.cancel,
                                    size: 18,
                                    color: AppColors.lightGrey,
                                  ),
                                  onPressed: () => _bioController.clear(),
                                )
                              : null,
                        ),
                  ),

                  const SizedBox(height: 24),

                  // Art Specialties
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader(
                        'Art Specialty (Pick 1 or 2)',
                        icon: Icons.palette_outlined,
                      ),
                      Text(
                        '${_selectedSpecialties.length} / 2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allSpecialties.map((specialty) {
                      final isSelected = _selectedSpecialties.contains(
                        specialty,
                      );
                      return ChoiceChip(
                        label: Text(specialty),
                        selected: isSelected,
                        selectedColor: AppColors.coral,
                        backgroundColor: AppColors.creamLight,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.black,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.coral
                                : AppColors.lightGrey,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (_selectedSpecialties.length < 2) {
                                _selectedSpecialties.add(specialty);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You can select up to 2 art specialties.',
                                    ),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            } else {
                              _selectedSpecialties.remove(specialty);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Social & Portfolio Links
                  _sectionHeader(
                    'Social & Portfolio Links',
                    icon: Icons.link_rounded,
                  ),
                  const SizedBox(height: 12),

                  _buildLockableLinkField(
                    label: 'website',
                    icon: const WebsiteGlobeIcon(size: 18),
                    controller: _websiteController,
                    emptyHint: 'Add your website or portfolio URL',
                    editHint: 'https://yourportfolio.com',
                    isEditing: _isEditingWebsite,
                    onEditTap: _startEditingWebsite,
                    onConfirm: _confirmWebsite,
                    onCancel: _cancelEditingWebsite,
                    errorText: _websiteError,
                    keyboardType: TextInputType.url,
                  ),

                  const SizedBox(height: 14),

                  _buildLockableLinkField(
                    label: 'Instagram username',
                    icon: const InstagramLogoIcon(size: 18),
                    controller: _instagramController,
                    emptyHint: 'Add your Instagram username',
                    editHint: 'e.g. artist_handle',
                    isEditing: _isEditingInstagram,
                    onEditTap: _startEditingInstagram,
                    onConfirm: _confirmInstagram,
                    onCancel: _cancelEditingInstagram,
                    errorText: _instagramError,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }
}
