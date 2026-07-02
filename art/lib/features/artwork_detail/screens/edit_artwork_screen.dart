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

import '../../../data/models/artwork_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditArtworkScreen extends StatefulWidget {
  final ArtworkModel artwork;
  const EditArtworkScreen({super.key, required this.artwork});

  @override
  State<EditArtworkScreen> createState() => _EditArtworkScreenState();
}

class _EditArtworkScreenState extends State<EditArtworkScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedAiTool;
  final _otherAiToolController = TextEditingController();
  final _aiPromptController = TextEditingController();
  final List<String> _aiTools = [
    'Midjourney',
    'DALL-E',
    'Stable Diffusion',
    'Adobe Firefly',
    'Leonardo AI',
    'Ideogram',
    'Flux',
    'Other',
  ];
  List<String> _tags = [];
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

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.artwork.title;
    _descriptionController.text = widget.artwork.description ?? '';
    _aiPromptController.text = widget.artwork.aiPrompt ?? '';

    _tags = List.from(widget.artwork.tags);

    if (widget.artwork.aiTool != null && widget.artwork.aiTool!.isNotEmpty) {
      if (_aiTools.contains(widget.artwork.aiTool)) {
        _selectedAiTool = widget.artwork.aiTool;
      } else {
        _selectedAiTool = 'Other';
        _otherAiToolController.text = widget.artwork.aiTool!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _otherAiToolController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _updateArtwork() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title.')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final updatedArtwork = await ArtworkRepository().updateArtwork(
        artworkId: widget.artwork.id,
        title: title,
        description: _descriptionController.text.trim(),
        tags: _tags,
        aiTool: _selectedAiTool == 'Other'
            ? (_otherAiToolController.text.trim().isEmpty
                  ? null
                  : _otherAiToolController.text.trim())
            : _selectedAiTool,
        aiPrompt: _aiPromptController.text.trim().isEmpty
            ? null
            : _aiPromptController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artwork updated successfully!')),
        );
        context.pop(updatedArtwork);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update artwork: ${e.toString()}')),
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
    context.pop();
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

  void _showAiToolPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.creamBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull indicator
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select AI Generator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _aiTools.length + 1, // +1 for "None"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 32,
                        ),
                        title: Text(
                          'None / Clear',
                          style: TextStyle(
                            color: AppColors.black.withOpacity(0.4),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedAiTool = null;
                            _otherAiToolController.clear();
                          });
                          Navigator.pop(context);
                        },
                      );
                    }
                    final tool = _aiTools[index - 1];
                    final isSelected = _selectedAiTool == tool;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 32,
                      ),
                      title: Text(
                        tool,
                        style: TextStyle(
                          color: isSelected ? AppColors.coral : AppColors.black,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.coral,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedAiTool = tool;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
          'Edit Post',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: _isUploading ? null : _updateArtwork,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.creamLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isUploading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.creamLight,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: widget.artwork.imageUrl,
                            fit: BoxFit.cover,
                          ),
                          Container(color: Colors.black.withOpacity(0.2)),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Image cannot be changed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
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

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _aiPromptController,
                      enabled: !_isUploading,
                      minLines: 2,
                      maxLines: 4,
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 15,
                        height: 1.35,
                      ),
                      decoration: _fieldDecoration(
                        hintText: 'AI Prompt (Optional)',
                        icon: Icons.code,
                      ),
                    ),

                    const SizedBox(height: 16),

                    GestureDetector(
                      onTap: _isUploading ? null : _showAiToolPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.creamLight.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.lightGrey),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: AppColors.coral,
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _selectedAiTool ?? 'AI Generator (Optional)',
                                style: TextStyle(
                                  color: _selectedAiTool == null
                                      ? AppColors.black.withOpacity(0.34)
                                      : AppColors.black,
                                  fontSize: 16,
                                  fontWeight: _selectedAiTool == null
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.coral,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_selectedAiTool == 'Other') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherAiToolController,
                        enabled: !_isUploading,
                        style: TextStyle(
                          color: AppColors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(
                          hintText: 'Specify AI Tool',
                          icon: Icons.edit_note,
                        ),
                      ),
                    ],

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
                    const SizedBox(height: 120),
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
                              'Saving changes...',
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
