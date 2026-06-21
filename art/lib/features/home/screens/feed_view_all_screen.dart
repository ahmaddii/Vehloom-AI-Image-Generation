import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class FeedViewAllScreen extends StatefulWidget {
  const FeedViewAllScreen({super.key});

  @override
  State<FeedViewAllScreen> createState() => _FeedViewAllScreenState();
}

class _FeedViewAllScreenState extends State<FeedViewAllScreen> {
  List<ArtworkModel> _artworks = [];
  bool _isLoading = true;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final artworks = await ArtworkRepository().fetchLatestArtworks();
      if (mounted) {
        setState(() {
          _artworks = artworks;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _getAspectRatioForIndex(int index) {
    final ratios = [0.75, 1.0, 1.25, 0.9, 1.1];
    return ratios[index % ratios.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          'Feed',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.creamBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        color: AppColors.creamBg,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.coral),
              )
            : _artworks.isEmpty
            ? const Center(
                child: Text(
                  'No artworks uploaded yet',
                  style: TextStyle(
                    color: AppColors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadFeed,
                color: AppColors.coral,
                child: MasonryGridView.count(
                  padding: const EdgeInsets.only(
                    left: 4,
                    right: 4,
                    top: 0,
                    bottom: 12,
                  ),
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  itemCount: _artworks.length,
                  itemBuilder: (context, index) {
                    final artwork = _artworks[index];
                    final aspectRatio = _getAspectRatioForIndex(index);
                    return GridArtworkCard(
                      artwork: artwork,
                      currentUserId: _currentUserId,
                      aspectRatio: aspectRatio,
                    );
                  },
                ),
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          border: const Border(
            top: BorderSide(color: AppColors.lightGrey, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: AppColors.coral),
                onPressed: () => context.go('/'),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.darkGrey),
                onPressed: () => context.go('/search'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_box_outlined,
                  color: AppColors.darkGrey,
                ),
                onPressed: () => context.push('/upload'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.darkGrey,
                ),
                onPressed: () => context.go('/top-art'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.person_outline,
                  color: AppColors.darkGrey,
                ),
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridArtworkCard extends StatefulWidget {
  final ArtworkModel artwork;
  final String currentUserId;
  final double aspectRatio;

  const GridArtworkCard({
    super.key,
    required this.artwork,
    required this.currentUserId,
    required this.aspectRatio,
  });

  @override
  State<GridArtworkCard> createState() => _GridArtworkCardState();
}

class _GridArtworkCardState extends State<GridArtworkCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.artwork.likesCount;
    _commentsCount = widget.artwork.commentsCount;
    _checkLikeStatus();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.currentUserId.isEmpty) return;
    try {
      final favorited = await ArtworkRepository().isFavorited(
        widget.artwork.id,
        widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          _isFavorited = favorited;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (widget.currentUserId.isEmpty) return;

    final wasFavorited = _isFavorited;
    setState(() {
      _isFavorited = !wasFavorited;
    });

    try {
      await ArtworkRepository().toggleFavorite(
        widget.artwork.id,
        widget.currentUserId,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFavorited = wasFavorited;
        });
      }
    }
  }

  Future<void> _checkLikeStatus() async {
    if (widget.currentUserId.isEmpty) return;
    try {
      final liked = await ArtworkRepository().isLiked(
        widget.artwork.id,
        widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          _isLiked = liked;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId.isEmpty) return;

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likesCount = wasLiked ? _likesCount - 1 : _likesCount + 1;
    });

    try {
      await ArtworkRepository().toggleLike(
        widget.artwork.id,
        widget.currentUserId,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = wasLiked ? _likesCount + 1 : _likesCount - 1;
        });
      }
    }
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedCommentBottomSheet(
        artworkId: widget.artwork.id,
        initialCommentsCount: _commentsCount,
        onCommentsCountUpdated: (newCount) {
          setState(() {
            _commentsCount = newCount;
          });
        },
      ),
    );
  }

  void _showQuickActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.creamBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pull handler line
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Artwork Details Row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.artwork.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.artwork.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            if (widget.artwork.authorUsername != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '@${widget.artwork.authorUsername}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.darkGrey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Like Action
                      _buildQuickActionItem(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        iconColor: _isLiked ? AppColors.coral : AppColors.black,
                        label: '$_likesCount Likes',
                        onTap: () async {
                          await _toggleLike();
                          setModalState(() {});
                          setState(() {});
                        },
                      ),
                      // Comment Action
                      _buildQuickActionItem(
                        icon: Icons.chat_bubble_outline,
                        iconColor: AppColors.black,
                        label: '$_commentsCount Comments',
                        onTap: () {
                          Navigator.pop(context);
                          _showCommentsBottomSheet();
                        },
                      ),
                      // Favorite Action
                      _buildQuickActionItem(
                        icon: _isFavorited
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        iconColor: _isFavorited
                            ? AppColors.coral
                            : AppColors.black,
                        label: _isFavorited ? 'Favorited' : 'Favorite',
                        onTap: () async {
                          await _toggleFavorite();
                          setModalState(() {});
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.creamLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lightGrey, width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/artwork/${widget.artwork.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: widget.artwork.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Container(color: AppColors.creamDark),
              ),
              errorWidget: (context, url, error) => AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Container(
                  color: AppColors.creamDark,
                  child: const Icon(
                    Icons.broken_image,
                    color: AppColors.darkGrey,
                  ),
                ),
              ),
            ),

            // Bottom overlay gradient so text is readable
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                  ),
                ),
              ),
            ),

            // Top-right Likes Count / Badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? AppColors.coral : AppColors.creamLight,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_likesCount',
                      style: const TextStyle(
                        color: AppColors.creamLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-left Three-dot Actions button
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: _showQuickActionsBottomSheet,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: AppColors.creamLight,
                    size: 14,
                  ),
                ),
              ),
            ),

            // Author Avatar & Handle
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundImage:
                        widget.artwork.authorAvatarUrl != null &&
                            widget.artwork.authorAvatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(
                            widget.artwork.authorAvatarUrl!,
                          )
                        : null,
                    child:
                        widget.artwork.authorAvatarUrl == null ||
                            widget.artwork.authorAvatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 8,
                            color: AppColors.black,
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.artwork.authorUsername != null
                          ? (widget.artwork.userId == widget.currentUserId
                                ? '@${widget.artwork.authorUsername} (You)'
                                : '@${widget.artwork.authorUsername}')
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.creamLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isFavorited) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.bookmark, color: Colors.amber, size: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedCommentBottomSheet extends StatefulWidget {
  final String artworkId;
  final int initialCommentsCount;
  final Function(int) onCommentsCountUpdated;

  const FeedCommentBottomSheet({
    super.key,
    required this.artworkId,
    required this.initialCommentsCount,
    required this.onCommentsCountUpdated,
  });

  @override
  State<FeedCommentBottomSheet> createState() => _FeedCommentBottomSheetState();
}

class _FeedCommentBottomSheetState extends State<FeedCommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  int _commentsCount = 0;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.initialCommentsCount;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ArtworkRepository().fetchComments(
        widget.artworkId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsCount = comments.length;
          _isLoading = false;
        });
        widget.onCommentsCountUpdated(_commentsCount);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _currentUserId.isEmpty) return;

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
          _commentsCount = _comments.length;
          _commentController.clear();
        });
        widget.onCommentsCountUpdated(_commentsCount);

        // Scroll to bottom
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.creamBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Drag handle and Header
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  'Comments ($_commentsCount)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.lightGrey),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                : _comments.isEmpty
                ? const Center(
                    child: Text(
                      'No comments yet.',
                      style: TextStyle(color: AppColors.darkGrey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundImage:
                                  comment.authorAvatarUrl != null &&
                                      comment.authorAvatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      comment.authorAvatarUrl!,
                                    )
                                  : null,
                              child:
                                  comment.authorAvatarUrl == null ||
                                      comment.authorAvatarUrl!.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 15,
                                      color: AppColors.black,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.creamLight,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(14),
                                        bottomLeft: Radius.circular(14),
                                        bottomRight: Radius.circular(14),
                                      ),
                                      border: Border.all(
                                        color: AppColors.lightGrey,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.authorUsername != null
                                              ? '@${comment.authorUsername}'
                                              : 'user',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.coral,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          comment.content,
                                          style: const TextStyle(
                                            color: AppColors.black,
                                            fontSize: 13.5,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      '${comment.createdAt.hour}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.black.withOpacity(0.4),
                                      ),
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
          ),

          // Add Comment Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: AppColors.darkGrey,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSubmittingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.coral,
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            color: AppColors.black,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_upward,
                              color: AppColors.creamLight,
                              size: 16,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            onPressed: _postComment,
                          ),
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
