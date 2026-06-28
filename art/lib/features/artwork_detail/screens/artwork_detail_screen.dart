import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/utils/number_utils.dart';

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
  RealtimeChannel? _artworkChannel;

  @override
  void initState() {
    super.initState();
    _loadArtworkDetails();
    _subscribeToArtworkUpdates();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    final channel = _artworkChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToArtworkUpdates() {
    _artworkChannel = Supabase.instance.client
        .channel('artwork-detail:${widget.artworkId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'artworks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.artworkId,
          ),
          callback: (_) => _loadArtworkDetails(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'artwork_id',
            value: widget.artworkId,
          ),
          callback: (_) => _loadArtworkDetails(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'artwork_id',
            value: widget.artworkId,
          ),
          callback: (_) => _loadArtworkDetails(showLoading: false),
        )
        .subscribe();
  }

  Future<void> _loadArtworkDetails({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final artwork = await ArtworkRepository().getArtwork(widget.artworkId);
      if (artwork != null) {
        final comments = await ArtworkRepository().fetchComments(
          widget.artworkId,
        );
        bool liked = false;
        if (_currentUserId.isNotEmpty) {
          liked = await ArtworkRepository().isLiked(
            widget.artworkId,
            _currentUserId,
          );
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

    if (mounted && showLoading) {
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
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.black),
        title: Text(
          _artwork?.title ?? 'Artwork',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            )
          : _artwork == null
          ? Center(
              child: Text(
                'Artwork not found',
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Beautiful Hero Image Display with rounded bottom edges
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    imageUrl: _artwork!.imageUrl,
                                    title: _artwork!.title,
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag: 'artwork-${_artwork!.id}',
                              child: CachedNetworkImage(
                                imageUrl: _artwork!.imageUrl,
                                fit: BoxFit.fitWidth,
                                placeholder: (context, url) => Container(
                                  height: 300,
                                  color: AppColors.creamDark,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.coral,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 300,
                                  color: AppColors.creamDark,
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: AppColors.darkGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Creator details and Likes row (Spaced out beautifully)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 12,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.push(
                                  '/profile/${_artwork!.userId}',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.coral,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundImage:
                                        _artwork!.authorAvatarUrl != null &&
                                            _artwork!
                                                .authorAvatarUrl!
                                                .isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            _artwork!.authorAvatarUrl!,
                                          )
                                        : null,
                                    child:
                                        _artwork!.authorAvatarUrl == null ||
                                            _artwork!.authorAvatarUrl!.isEmpty
                                        ? Icon(
                                            Icons.person,
                                            color: AppColors.black,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _artwork!.title,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    GestureDetector(
                                      onTap: () => context.push(
                                        '/profile/${_artwork!.userId}',
                                      ),
                                      child: Text(
                                        _artwork!.authorUsername != null
                                            ? (_artwork!.userId ==
                                                      _currentUserId
                                                  ? '@${_artwork!.authorUsername} (You)'
                                                  : '@${_artwork!.authorUsername}')
                                            : 'Creator profile',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.coral,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Like Actions in pill shaped chip
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.creamLight,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.lightGrey,
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: _isLiked
                                            ? AppColors.coral
                                            : AppColors.black,
                                        size: 24,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: _toggleLike,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      NumberUtils.format(_likesCount),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Artwork Description and Tags box
                        if ((_artwork!.description != null &&
                                _artwork!.description!.isNotEmpty) ||
                            _artwork!.tags.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.creamLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.lightGrey,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_artwork!.description != null &&
                                    _artwork!.description!.isNotEmpty) ...[
                                  Text(
                                    _artwork!.description!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.black,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (_artwork!.tags.isNotEmpty)
                                    const SizedBox(height: 12),
                                ],
                                if (_artwork!.tags.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _artwork!.tags.map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.creamBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.lightGrey,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.coral,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),

                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Divider(
                            thickness: 1,
                            color: AppColors.lightGrey,
                          ),
                        ),

                        // Comments Section Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Comments',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  NumberUtils.format(_comments.length),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.creamLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Comments List rendered as bubble chats
                        _comments.isEmpty
                            ? Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 32,
                                ),
                                child: Center(
                                  child: Text(
                                    'No comments yet. Start the conversation!',
                                    style: TextStyle(
                                      color: AppColors.darkGrey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final comment = _comments[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => context.push(
                                            '/profile/${comment.userId}',
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(1.5),
                                            decoration: const BoxDecoration(
                                              color: AppColors.coral,
                                              shape: BoxShape.circle,
                                            ),
                                            child: CircleAvatar(
                                              radius: 15,
                                              backgroundImage:
                                                  comment.authorAvatarUrl !=
                                                          null &&
                                                      comment
                                                          .authorAvatarUrl!
                                                          .isNotEmpty
                                                  ? CachedNetworkImageProvider(
                                                      comment.authorAvatarUrl!,
                                                    )
                                                  : null,
                                              child:
                                                  comment.authorAvatarUrl ==
                                                          null ||
                                                      comment
                                                          .authorAvatarUrl!
                                                          .isEmpty
                                                  ? Icon(
                                                      Icons.person,
                                                      size: 15,
                                                      color: AppColors.black,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.creamLight,
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topRight:
                                                            Radius.circular(16),
                                                        bottomLeft:
                                                            Radius.circular(16),
                                                        bottomRight:
                                                            Radius.circular(16),
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
                                                    GestureDetector(
                                                      onTap: () => context.push(
                                                        '/profile/${comment.userId}',
                                                      ),
                                                      child: Text(
                                                        comment.authorUsername !=
                                                                null
                                                            ? (comment.userId ==
                                                                      _currentUserId
                                                                  ? '@${comment.authorUsername} (You)'
                                                                  : '@${comment.authorUsername}')
                                                            : 'user',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.coral,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      comment.content,
                                                      style: TextStyle(
                                                        color: AppColors.black,
                                                        fontSize: 14,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Text(
                                                  '${comment.createdAt.hour}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.black
                                                        .withOpacity(0.4),
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
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Flat Comment Bar at bottom
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.creamLight,
                    border: Border(
                      top: BorderSide(color: AppColors.lightGrey, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.creamBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.lightGrey,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: TextStyle(
                                color: AppColors.black,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(
                                  color: AppColors.darkGrey,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
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
                              : GestureDetector(
                                  onTap: _postComment,
                                  child: const Text(
                                    'Post',
                                    style: TextStyle(
                                      color: AppColors.coral,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                CircularProgressIndicator(color: AppColors.coral),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 50),
          ),
        ),
      ),
    );
  }
}
