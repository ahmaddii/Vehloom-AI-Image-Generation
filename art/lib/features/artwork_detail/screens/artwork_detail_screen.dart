import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class ArtworkDetailScreen extends StatefulWidget {
  final String artworkId;

  const ArtworkDetailScreen({super.key, required this.artworkId});

  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ArtworkModel? _artwork;
  List<CommentModel> _comments = [];
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadArtworkDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArtworkDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final artwork = await ArtworkRepository().getArtwork(widget.artworkId);
      if (artwork != null) {
        final comments = await ArtworkRepository().fetchComments(widget.artworkId);
        bool liked = false;
        if (_currentUserId.isNotEmpty) {
          liked = await ArtworkRepository().isLiked(widget.artworkId, _currentUserId);
        }

        if (mounted) {
          setState(() {
            _artwork = artwork;
            _comments = comments;
            _isLiked = liked;
            _likesCount = artwork.likesCount;
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUserId.isEmpty || _artwork == null) return;

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likesCount = wasLiked ? _likesCount - 1 : _likesCount + 1;
    });

    try {
      await ArtworkRepository().toggleLike(widget.artworkId, _currentUserId);
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = wasLiked ? _likesCount + 1 : _likesCount - 1;
        });
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _currentUserId.isEmpty || _artwork == null) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final newComment = await ArtworkRepository().addComment(
        artworkId: widget.artworkId,
        userId: _currentUserId,
        content: text,
      );

      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _commentController.clear();
        });
        
        // Scroll to the bottom of comment list
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        title: Text(
          _artwork?.title ?? 'Artwork Detail',
          style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : _artwork == null
              ? const Center(
                  child: Text(
                    'Artwork not found',
                    style: TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Large Artwork Image
                            AspectRatio(
                              aspectRatio: 1,
                              child: CachedNetworkImage(
                                imageUrl: _artwork!.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: AppColors.creamDark),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.creamDark,
                                  child: const Icon(Icons.broken_image, size: 48, color: AppColors.darkGrey),
                                ),
                              ),
                            ),

                            // Creator details and Likes row
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => context.push('/profile/${_artwork!.userId}'),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: _artwork!.authorAvatarUrl != null && _artwork!.authorAvatarUrl!.isNotEmpty
                                          ? CachedNetworkImageProvider(_artwork!.authorAvatarUrl!)
                                          : null,
                                      child: _artwork!.authorAvatarUrl == null || _artwork!.authorAvatarUrl!.isEmpty
                                          ? const Icon(Icons.person, color: AppColors.black)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _artwork!.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.black,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => context.push('/profile/${_artwork!.userId}'),
                                          child: Text(
                                            _artwork!.authorUsername != null
                                                ? '@${_artwork!.authorUsername}'
                                                : 'Creator profile',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.black.withOpacity(0.6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Like Actions
                                  IconButton(
                                    icon: Icon(
                                      _isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: _isLiked ? AppColors.coral : AppColors.black,
                                      size: 28,
                                    ),
                                    onPressed: _toggleLike,
                                  ),
                                  Text(
                                    '$_likesCount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Description & Date
                            if (_artwork!.description != null && _artwork!.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _artwork!.description!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.black,
                                    height: 1.4,
                                  ),
                                ),
                              ),

                            const Divider(height: 32, thickness: 1, color: AppColors.lightGrey),

                            // Comments Section Header
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Comments',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Comments List
                            _comments.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                    child: Center(
                                      child: Text(
                                        'No comments yet. Start the conversation!',
                                        style: TextStyle(color: AppColors.darkGrey, fontSize: 14),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: _comments.length,
                                    itemBuilder: (context, index) {
                                      final comment = _comments[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () => context.push('/profile/${comment.userId}'),
                                              child: CircleAvatar(
                                                radius: 16,
                                                backgroundImage: comment.authorAvatarUrl != null && comment.authorAvatarUrl!.isNotEmpty
                                                    ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
                                                    : null,
                                                child: comment.authorAvatarUrl == null || comment.authorAvatarUrl!.isEmpty
                                                    ? const Icon(Icons.person, size: 16, color: AppColors.black)
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        WidgetSpan(
                                                          child: GestureDetector(
                                                            onTap: () => context.push('/profile/${comment.userId}'),
                                                            child: Text(
                                                              comment.authorUsername != null
                                                                  ? '@${comment.authorUsername}  '
                                                                  : 'user  ',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                color: AppColors.black,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: comment.content,
                                                          style: const TextStyle(
                                                            color: AppColors.black,
                                                            fontSize: 13.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${comment.createdAt.hour}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.black.withOpacity(0.4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Add Comment Bar at bottom
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.creamLight,
                        border: Border(
                          top: BorderSide(color: AppColors.lightGrey, width: 1),
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.creamBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.lightGrey, width: 1),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _commentController,
                                  decoration: const InputDecoration(
                                    hintText: 'Add a comment...',
                                    hintStyle: TextStyle(color: AppColors.darkGrey, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _isSubmittingComment
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.send, color: AppColors.coral),
                                    onPressed: _postComment,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
