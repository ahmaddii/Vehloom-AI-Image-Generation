import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_animated_switch.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/story_repository.dart';
import 'package:image_cropper/image_cropper.dart';

class UploadArtworkScreen extends StatefulWidget {
  const UploadArtworkScreen({super.key});

  @override
  State<UploadArtworkScreen> createState() => _UploadArtworkScreenState();
}

class _UploadArtworkScreenState extends State<UploadArtworkScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _alsoPostToStory = false;

  final List<String> _tags = ['AI Art', 'Digital Art', 'Fantasy'];
  final List<String> _suggestedTags = [
    'Portrait',
    'Landscape',
    'Concept Art',
    'Character Design',
    'Abstract',
    'Surreal',
    'Cyberpunk',
    'Nature',
    'Sci-Fi',
    'Minimal',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _cropImage(String sourcePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Adjust Artwork',
            toolbarColor: AppColors.black,
            toolbarWidgetColor: AppColors.creamLight,
            activeControlsWidgetColor: AppColors.coral,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop & Adjust Artwork',
            aspectRatioLockEnabled: false,
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        await _cropImage(pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _postArtwork() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an artwork image first.')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title.')));
      return;
    }

    final currentUserId = AuthRepository().currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to upload.')),
      );
      context.go('/login');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. Upload file to Supabase Storage
      final imageUrl = await ArtworkRepository().uploadArtworkImage(
        _imageFile!,
        currentUserId,
      );

      // Determine orientation dynamically
      final bytes = await _imageFile!.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      final orientationTag = decodedImage.height >= decodedImage.width
          ? 'portrait'
          : 'landscape';

      final finalTags = List<String>.from(_tags);
      if (!_containsTag(finalTags, 'portrait') &&
          !_containsTag(finalTags, 'landscape')) {
        finalTags.add(orientationTag);
      }

      // 2. Save artwork record to database
      final newArtwork = await ArtworkRepository().createArtwork(
        userId: currentUserId,
        imageUrl: imageUrl,
        title: title,
        description: _descriptionController.text.trim(),
        tags: finalTags,
      );

      if (_alsoPostToStory) {
        await StoryRepository().createStory(
          userId: currentUserId,
          artworkId: newArtwork.id,
          mediaUrl: imageUrl,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artwork posted successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload artwork: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  void _addTag(String tag) {
    final cleanTag = tag.trim();
    if (cleanTag.isNotEmpty && !_containsTag(_tags, cleanTag)) {
      setState(() {
        _tags.add(cleanTag);
      });
    }
  }

  bool _containsTag(List<String> tags, String tag) {
    final cleanTag = tag.trim().toLowerCase();
    return tags.any((item) => item.trim().toLowerCase() == cleanTag);
  }

  Future<void> _closeScreen() async {
    final hasDraft =
        _imageFile != null ||
        _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _tags.length > 3;

    if (!hasDraft) {
      context.pop();
      return;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.creamBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard post?',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Your selected artwork, text, and tags will be lost.',
          style: TextStyle(color: AppColors.darkGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep editing',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AppColors.creamLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (mounted && shouldDiscard == true) {
      context.pop();
    }
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.creamBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Add New Tag',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.black),
          decoration: InputDecoration(
            hintText: 'e.g. digitalart',
            hintStyle: TextStyle(color: AppColors.black.withOpacity(0.3)),
            filled: true,
            fillColor: AppColors.creamLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.coral.withOpacity(0.55),
                width: 1.2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.black.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AppColors.creamLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addTag(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.black.withOpacity(0.34)),
      prefixIcon: Icon(icon, color: AppColors.coral, size: 20),
      filled: true,
      fillColor: AppColors.creamLight.withOpacity(0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.coral.withOpacity(0.55),
          width: 1.2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.lightGrey.withOpacity(0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.close, color: AppColors.black, size: 18),
              onPressed: _isUploading ? null : _closeScreen,
            ),
          ),
        ),
        title: Text(
          'New Post',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          _isUploading
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
                  padding: const EdgeInsets.only(right: 12.0),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.creamLight,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _postArtwork,
                    icon: const Icon(Icons.publish_outlined, size: 16),
                    label: const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.6, -0.85),
            radius: 0.7,
            colors: [AppColors.coral.withOpacity(0.12), AppColors.creamBg],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _isUploading ? null : _pickImage,
                      child: AspectRatio(
                        aspectRatio: 0.96,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _imageFile != null
                                ? AppColors.black
                                : AppColors.creamLight,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _imageFile != null
                                  ? AppColors.black
                                  : AppColors.coral.withOpacity(0.18),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.coral.withOpacity(0.08),
                                blurRadius: 26,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: _imageFile != null
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    // Soft gradient overlay at the bottom so the action label is readable
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.35),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 14,
                                      right: 14,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.creamLight
                                              .withOpacity(0.94),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.tune,
                                              size: 15,
                                              color: AppColors.black,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Adjust',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 18,
                                      right: 18,
                                      bottom: 18,
                                      child: Text(
                                        'Artwork preview',
                                        style: TextStyle(
                                          color: AppColors.creamLight,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 8,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.creamLight,
                                          AppColors.creamBg,
                                          AppColors.coral.withOpacity(0.18),
                                        ],
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 18,
                                          left: 18,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.coral
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: AppColors.coral
                                                    .withOpacity(0.18),
                                              ),
                                            ),
                                            child: const Text(
                                              'Gallery upload',
                                              style: TextStyle(
                                                color: AppColors.coral,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 78,
                                                height: 78,
                                                decoration: BoxDecoration(
                                                  color: AppColors.creamLight,
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.coral
                                                          .withOpacity(0.16),
                                                      blurRadius: 18,
                                                      offset: const Offset(
                                                        0,
                                                        8,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
                                                  color: AppColors.coral,
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                'Choose your artwork',
                                                style: TextStyle(
                                                  color: AppColors.black,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 7),
                                              Text(
                                                'Ready for the gallery.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: AppColors.darkGrey,
                                                  fontSize: 13,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'DETAILS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGrey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _titleController,
                      enabled: !_isUploading,
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        hintText: 'Title',
                        icon: Icons.drive_file_rename_outline,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isUploading,
                      minLines: 3,
                      maxLines: 5,
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 15,
                        height: 1.35,
                      ),
                      decoration: _fieldDecoration(
                        hintText: 'Description',
                        icon: Icons.notes_outlined,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tags Label
                    Text(
                      'TAGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGrey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tags List
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._tags.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final tag = entry.value;
                          return Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.coral,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 14,
                              color: AppColors.coral,
                            ),
                            onDeleted: _isUploading
                                ? null
                                : () => _removeTag(idx),
                            backgroundColor: AppColors.coral.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                          );
                        }),

                        // Add Tag Button
                        ActionChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: AppColors.black),
                              SizedBox(width: 7),
                              Text('Tag'),
                            ],
                          ),
                          onPressed: _isUploading ? null : _showAddTagDialog,
                          backgroundColor: AppColors.creamLight.withOpacity(
                            0.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'SUGGESTED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGrey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedTags.map((tag) {
                        final isSelected = _containsTag(_tags, tag);
                        return ActionChip(
                          avatar: Icon(
                            isSelected ? Icons.check : Icons.add,
                            size: 14,
                            color: isSelected
                                ? AppColors.creamLight
                                : AppColors.black,
                          ),
                          label: Text(tag),
                          onPressed: _isUploading || isSelected
                              ? null
                              : () => _addTag(tag),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.creamLight
                                : AppColors.black,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: isSelected
                              ? AppColors.black
                              : AppColors.creamLight.withOpacity(0.8),
                          disabledColor: isSelected
                              ? AppColors.black
                              : AppColors.creamLight.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.black
                                : AppColors.lightGrey,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'SHARING OPTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGrey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.creamLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.lightGrey),
                      ),
                      child: ListTile(
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
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (_isUploading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Card(
                      color: AppColors.creamLight,
                      margin: EdgeInsets.all(32),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.coral),
                            SizedBox(width: 16),
                            Text(
                              'Uploading artwork...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
