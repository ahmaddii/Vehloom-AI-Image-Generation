import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/story_repository.dart';
import '../../../core/widgets/custom_add_button.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/number_utils.dart';

class FeedViewAllScreen extends StatefulWidget {
  const FeedViewAllScreen({super.key});

  @override
  State<FeedViewAllScreen> createState() => _FeedViewAllScreenState();
}

class _FeedViewAllScreenState extends State<FeedViewAllScreen> {
  List<ArtworkModel> _artworks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _showTopBanner = true;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';
  RealtimeChannel? _feedChannel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
    _subscribeToFeedUpdates();
  }

  @override
  void dispose() {
    final channel = _feedChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadFeed(showLoading: false, isLoadMore: true);
      }
    }
  }

  void _subscribeToFeedUpdates() {
    _feedChannel = Supabase.instance.client
        .channel('feed-view-all-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'artworks',
          callback: (_) => _loadFeed(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (_) => _loadFeed(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (_) => _loadFeed(showLoading: false),
        )
        .subscribe();
  }

  Future<void> _loadFeed({bool showLoading = true, bool isLoadMore = false}) async {
    if (!mounted) return;
    if (!isLoadMore) {
      _currentOffset = 0;
      _hasMore = true;
    }

    if (_isLoadingMore || !_hasMore) return;

    if (showLoading && !isLoadMore) {
      setState(() {
        _isLoading = true;
      });
    }

    if (isLoadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final newArtworks = await ArtworkRepository().fetchLatestArtworks(
        offset: _currentOffset,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _artworks.addAll(newArtworks);
          } else {
            _artworks = newArtworks;
          }

          if (newArtworks.length < 20) {
            _hasMore = false;
          } else {
            _currentOffset += 20;
          }
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  double _getAspectRatioForIndex(int index) {
    final ratios = [0.75, 1.0, 1.25, 0.9, 1.1];
    return ratios[index % ratios.length];
  }

  Widget _buildSkeletonGrid() {
    return MasonryGridView.count(
      padding: const EdgeInsets.only(
        left: 4,
        right: 4,
        top: 0,
        bottom: 12,
      ),
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: 8,
      itemBuilder: (context, index) {
        final ratios = [0.75, 1.0, 1.25, 0.9, 1.1];
        final aspectRatio = ratios[index % ratios.length];
        return Shimmer.fromColors(
          baseColor: AppColors.creamDark,
          highlightColor: AppColors.creamLight,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(
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
          icon: Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.black, size: 28),
            onPressed: () {
              context.push('/search');
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: AppColors.creamBg,
        child: Column(
          children: [
            // Top Banner Area (Carousel + Right Portrait Image)
            if (_showTopBanner)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: SizedBox(
                  height: 180, // Total height for the top section
                  child: ContinuousImageScroll(
                    onClose: () {
                      setState(() {
                        _showTopBanner = false;
                      });
                    },
                    imageUrls: const [
                      'assets/view_all_feed/v1.png',
                      'assets/view_all_feed/v2.png',
                      'assets/view_all_feed/v3.png',
                      'assets/view_all_feed/v4.png',
                      'assets/view_all_feed/v5.png',
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonGrid()
                  : _artworks.isEmpty
                  ? Center(
                      child: Text(
                        'No artworks found',
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
                      child: AnimationLimiter(
                        child: MasonryGridView.count(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(
                            left: 4,
                            right: 4,
                            top: 12,
                            bottom: 12,
                          ),
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          itemCount: _artworks.length,
                          itemBuilder: (context, index) {
                            final artwork = _artworks[index];
                            final aspectRatio = _getAspectRatioForIndex(index);
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 500),
                              columnCount: 2,
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: GridArtworkCard(
                                    artwork: artwork,
                                    currentUserId: _currentUserId,
                                    aspectRatio: aspectRatio,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}

class ContinuousImageScroll extends StatefulWidget {
  final List<String> imageUrls;
  final VoidCallback? onClose;

  const ContinuousImageScroll({
    super.key, 
    required this.imageUrls,
    this.onClose,
  });

  @override
  State<ContinuousImageScroll> createState() => _ContinuousImageScrollState();
}

class _ContinuousImageScrollState extends State<ContinuousImageScroll> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(); // Default viewportFraction is 1.0
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        setState(() {
          if (_currentPage < widget.imageUrls.length - 1) {
            _currentPage++;
          } else {
            _currentPage = 0;
          }
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          children: [
            // The Carousel Images
            PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return Image.asset(
                  widget.imageUrls[index],
                  fit: BoxFit.cover, // Fills the container perfectly
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.creamDark,
                    child: const Center(child: Icon(Icons.error_outline)),
                  ),
                );
              },
            ),
            // Location Badge
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tokyo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Optional Close Button
            if (widget.onClose != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // The Indicator Dots
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: _currentPage == index ? 12.0 : 8.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  );
                }),
              ),
            ),
          ],
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
  int _favoritesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.artwork.likesCount;
    _commentsCount = widget.artwork.commentsCount;
    _favoritesCount = widget.artwork.favoritesCount;
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
      _favoritesCount = wasFavorited ? _favoritesCount - 1 : _favoritesCount + 1;
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
          _favoritesCount = wasFavorited ? _favoritesCount + 1 : _favoritesCount - 1;
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
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Layer
                Positioned.fill(
                  top: 60, // The top 60px of the Stack is transparent for the image to stick out
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.creamBg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                  ),
                ),
                
                // Close Button
                Positioned(
                  top: 60 + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Icon(Icons.close, color: AppColors.black, size: 28),
                  ),
                ),
                
                // Content Layer
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Center Artwork (naturally sized, preserving aspect ratio)
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 320, // Generous height for portrait images
                          maxWidth: MediaQuery.of(context).size.width * 0.65, // Leaves room for close button
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: widget.artwork.imageUrl,
                              fadeInDuration: const Duration(milliseconds: 300),
                              placeholder: (context, url) => AspectRatio(
                                aspectRatio: widget.aspectRatio,
                                child: CachedNetworkImage(
                                  imageUrl: ImageUtils.getThumbnailUrl(
                                    widget.artwork.imageUrl,
                                    width: 400,
                                    height: (400 / widget.aspectRatio).round(),
                                  ),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: AppColors.creamDark,
                                    highlightColor: AppColors.creamLight,
                                    child: Container(color: Colors.white),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => AspectRatio(
                                aspectRatio: widget.aspectRatio,
                                child: Container(
                                  color: AppColors.creamDark,
                                  child: Icon(Icons.broken_image_outlined, color: AppColors.darkGrey, size: 40),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                  // Title and Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          widget.artwork.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                        if (widget.artwork.description != null &&
                            widget.artwork.description!.isNotEmpty) ...[
                          SizedBox(height: 6),
                          Text(
                            widget.artwork.description!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Actions List
                  _buildListActionItem(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    iconColor: _isLiked ? AppColors.coral : AppColors.black,
                    title: _isLiked ? 'Unlike' : 'Like',
                    trailingText: _likesCount > 0 ? NumberUtils.format(_likesCount) : null,
                    onTap: () async {
                      await _toggleLike();
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  _buildListActionItem(
                    icon: Icons.chat_bubble_outline,
                    iconColor: AppColors.black,
                    title: 'Comment',
                    trailingText: _commentsCount > 0 ? NumberUtils.format(_commentsCount) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _showCommentsBottomSheet();
                    },
                  ),
                  _buildListActionItem(
                    icon: _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                    iconColor: _isFavorited ? AppColors.coral : AppColors.black,
                    title: _isFavorited ? 'Remove from Favorites' : 'Add to Favorites',
                    trailingText: _favoritesCount > 0 ? NumberUtils.format(_favoritesCount) : null,
                    onTap: () async {
                      await _toggleFavorite();
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  _buildListActionItem(
                    icon: Icons.share_outlined,
                    iconColor: AppColors.black,
                    title: 'Share to Story',
                    onTap: () async {
                      Navigator.pop(builderContext);
                      final currentUserId = AuthRepository().currentUser?.id;
                      if (currentUserId == null) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Please log in first.')),
                        );
                        return;
                      }
                      _performStoryUpload(context, messenger, () async {
                        await StoryRepository().createStory(
                          userId: currentUserId,
                          artworkId: widget.artwork.id,
                          mediaUrl: widget.artwork.imageUrl,
                        );
                      });
                    },
                  ),
                  SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 24),
                ],
              ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildListActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: iconColor == AppColors.coral ? AppColors.coral : AppColors.black,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _performStoryUpload(
    BuildContext context,
    ScaffoldMessengerState messenger,
    Future<void> Function() uploadCallback,
  ) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    bool uploadFinished = false;
    Object? uploadError;

    // Start upload task in background
    final uploadFuture = uploadCallback().then((_) {
      uploadFinished = true;
    }).catchError((err) {
      uploadFinished = true;
      uploadError = err;
    });

    // Start a timer to animate progress smoothly
    final timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (uploadError != null) {
        t.cancel();
        return;
      }

      if (progressNotifier.value < 0.95) {
        progressNotifier.value += 0.03;
      } else if (uploadFinished) {
        progressNotifier.value = 1.0;
        t.cancel();
      }
    });

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(
                vertical: 28,
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.creamBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, progress, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 4,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.coral,
                              ),
                              backgroundColor: AppColors.lightGrey,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              color: AppColors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Sharing to Story...',
                        style: TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    // Wait for the upload task
    try {
      await uploadFuture;
    } catch (_) {}

    // Ensure animation reaches 100% if successful
    if (uploadError == null) {
      uploadFinished = true;
      while (progressNotifier.value < 1.0) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    timer.cancel();
    progressNotifier.dispose();

    if (context.mounted) {
      Navigator.pop(context); // Dismiss dialog
    }

    if (uploadError != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to share: $uploadError')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Shared to your Story!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/artwork/${widget.artwork.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: ImageUtils.getThumbnailUrl(widget.artwork.imageUrl, width: 400, height: (400 / widget.aspectRatio).round()),
                  memCacheWidth: 400,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: Container(color: AppColors.creamDark),
                  ),
                  errorWidget: (context, url, error) => AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: Container(
                      color: AppColors.creamDark,
                      child: Icon(
                        Icons.broken_image,
                        color: AppColors.darkGrey,
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
                          color: _isLiked ? AppColors.coral : Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$_likesCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom-left Author Info Overlay
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (widget.artwork.userId.isNotEmpty) {
                        context.push('/profile/${widget.artwork.userId}');
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white24,
                          backgroundImage:
                              widget.artwork.authorAvatarUrl != null &&
                                      widget.artwork.authorAvatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      widget.artwork.authorAvatarUrl!,
                                    )
                                  : null,
                          child: widget.artwork.authorAvatarUrl == null ||
                                  widget.artwork.authorAvatarUrl!.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppColors.creamBg,
                                )
                              : null,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.artwork.authorUsername != null
                                ? (widget.artwork.userId == widget.currentUserId
                                    ? '@${widget.artwork.authorUsername} (You)'
                                    : '@${widget.artwork.authorUsername}')
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Below Image: 3 dots and Favorite icon (Compact layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isFavorited)
                Icon(Icons.bookmark, color: AppColors.coral, size: 18),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showQuickActionsBottomSheet,
                child: Padding(
                  padding: EdgeInsets.only(top: 2.0, bottom: 0.0, left: 4.0, right: 2.0),
                  child: Icon(
                    Icons.more_horiz,
                    color: AppColors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
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
      decoration: BoxDecoration(
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
                SizedBox(width: 24),
                Text(
                  'Comments ($_commentsCount)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
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
          Divider(height: 1, thickness: 0.5, color: AppColors.lightGrey),

          // Comments List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                : _comments.isEmpty
                ? Center(
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
                                  ? Icon(
                                      Icons.person,
                                      size: 15,
                                      color: AppColors.black,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 10),
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.coral,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          comment.content,
                                          style: TextStyle(
                                            color: AppColors.black,
                                            fontSize: 13.5,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 2),
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
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  _isSubmittingComment
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.coral,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.black,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
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
