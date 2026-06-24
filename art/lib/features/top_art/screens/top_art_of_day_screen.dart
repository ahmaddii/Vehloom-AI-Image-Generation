import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class TopArtOfDayScreen extends StatefulWidget {
  const TopArtOfDayScreen({super.key});

  @override
  State<TopArtOfDayScreen> createState() => _TopArtOfDayScreenState();
}

class _TopArtOfDayScreenState extends State<TopArtOfDayScreen> {
  late Timer _timer;
  Duration _timeLeft = const Duration(hours: 14, minutes: 22, seconds: 8);
  List<ArtworkModel> _topArtworks = [];
  bool _isLoading = true;
  bool _isTopOnePortrait = false;
  bool _showConfetti = true;
  RealtimeChannel? _topArtChannel;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTopArtworks();
    _subscribeToTopArtUpdates();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showConfetti = false;
        });
      }
    });
  }

  void _subscribeToTopArtUpdates() {
    _topArtChannel = Supabase.instance.client
        .channel('top-art-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'artworks',
          callback: (_) => _loadTopArtworks(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (_) => _loadTopArtworks(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (_) => _loadTopArtworks(showLoading: false),
        )
        .subscribe();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _timeLeft = _timeLeft - const Duration(seconds: 1);
          });
        }
      } else {
        _timer.cancel();
      }
    });
  }

  Future<void> _loadTopArtworks({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final artworks = await ArtworkRepository().fetchLatestArtworks();
      // Sort by likesCount descending
      artworks.sort((a, b) => b.likesCount.compareTo(a.likesCount));

      if (mounted) {
        setState(() {
          _topArtworks = artworks;
        });

        if (artworks.isNotEmpty) {
          final topOne = artworks.first;
          final imageProvider = CachedNetworkImageProvider(topOne.imageUrl);
          final stream = imageProvider.resolve(const ImageConfiguration());
          stream.addListener(
            ImageStreamListener((ImageInfo info, bool _) {
              if (mounted) {
                setState(() {
                  _isTopOnePortrait = info.image.height > info.image.width;
                });
              }
            }),
          );
        }
      }
    } catch (_) {}

    if (mounted && showLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    final channel = _topArtChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '${hours}h ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final hasArt = _topArtworks.isNotEmpty;
    final topOne = hasArt ? _topArtworks.first : null;
    final restRankings = hasArt
        ? _topArtworks.skip(1).toList()
        : <ArtworkModel>[];

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // Fallback to home if navigation stack is empty (e.g., opened via deep link or bottom nav)
              context.go('/');
            }
          },
        ),
        title: const Text(
          'Top Art of the Day',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.black),
            onPressed: _loadTopArtworks,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!hasArt && _isLoading)
            _buildSkeletonLoader()
          else if (!hasArt)
            _buildEmptyState()
          else
            ListView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 24,
              ),
              children: [
                // Timer Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12, // Reduced from 16 to make it slightly thinner
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0), // Light red
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.coral,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New picks in ',
                        style: TextStyle(
                          color: AppColors.black.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(_timeLeft),
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontSize: 15,
                          fontWeight: FontWeight.w900, // Extra bold
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Top Art Card
                if (topOne != null) _buildTopArtCard(topOne),
                const SizedBox(height: 24),
                // Runner Ups List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: restRankings.length,
                  itemBuilder: (context, index) =>
                      _buildRunnerUpTile(restRankings[index], index + 2),
                ),
              ],
            ),

          if (_isLoading && hasArt)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                ),
              ),
            ),

          if (_showConfetti &&
              hasArt &&
              topOne?.userId == AuthRepository().currentUser?.id)
            Center(
              child: IgnorePointer(
                child: Lottie.asset(
                  'assets/lottie/confetti.json',
                  repeat: false,
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        title: const Text(
          'Top Art of the Day',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'No rankings available yet today.\nCheck back later!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.darkGrey),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
      children: [
        // Skeleton Timer Pill
        Shimmer.fromColors(
          baseColor: AppColors.creamDark,
          highlightColor: AppColors.creamLight,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Skeleton Top Art Card
        Shimmer.fromColors(
          baseColor: AppColors.creamDark,
          highlightColor: AppColors.creamLight,
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Skeleton Runner Ups
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: AppColors.creamDark,
              highlightColor: AppColors.creamLight,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopArtCard(ArtworkModel topOne) {
    final isLandscape = !_isTopOnePortrait;

    return GestureDetector(
      onTap: () => context.push('/artwork/${topOne.id}'),
      child: Container(
        height: isLandscape ? null : 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isLandscape
            ? _buildLandscapeLayout(topOne)
            : _buildPortraitLayout(topOne),
      ),
    );
  }

  Widget _buildPortraitLayout(ArtworkModel topOne) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: _buildDetailsWidget(topOne, false)),
        Expanded(
          flex: 1,
          child: Hero(
            tag: 'top_art_${topOne.id}',
            child: _buildImageWidget(topOne, false),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(ArtworkModel topOne) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailsWidget(topOne, true),
        Hero(
          tag: 'top_art_${topOne.id}',
          child: SizedBox(height: 260, child: _buildImageWidget(topOne, true)),
        ),
      ],
    );
  }

  Widget _buildDetailsWidget(ArtworkModel topOne, bool isLandscape) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge and Likes
              // Badge and Likes
              Row(
                children: [
                  Image.asset(
                    'assets/icons/winner.png', // Changed to winner.png without tint
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '#1',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.favorite, color: AppColors.coral, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${topOne.likesCount}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                topOne.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24, // Increased from 18
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14, // Increased from 10
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage:
                        topOne.authorAvatarUrl != null &&
                            topOne.authorAvatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(topOne.authorAvatarUrl!)
                        : null,
                    child:
                        topOne.authorAvatarUrl == null ||
                            topOne.authorAvatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16, // Increased from 12
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topOne.authorUsername != null
                          ? '@${topOne.authorUsername}'
                          : 'user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14, // Increased from 12
                        color: AppColors.darkGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                topOne.description ?? 'Artwork showing a beautiful scene',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13, // Increased from 11
                  fontStyle: FontStyle.italic,
                  color: AppColors.darkGrey.withOpacity(0.8),
                ),
              ),
            ],
          ),
          if (isLandscape)
            Positioned(
              right: 0,
              top: 0,
              bottom: 40, // Pulls the center point up slightly
              child: Center(
                child: Transform.scale(
                  scale: 2.0, // Reduced from 2.5 to lower the size
                  child: Lottie.asset(
                    'assets/lottie/fire.json',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(); // Hide if error instead of grey box
                    },
                  ),
                ),
              ),
            ),
          if (!isLandscape)
            Positioned(
              bottom: 0,
              right: -15,
              child: Transform.scale(
                scale: 1.5,
                child: Lottie.asset(
                  'assets/lottie/fire.json',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(ArtworkModel topOne, bool isLandscape) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: isLandscape
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : const BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background for letterboxing
          CachedNetworkImage(
            imageUrl: topOne.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: AppColors.creamBg),
            errorWidget: (context, url, error) =>
                Container(color: AppColors.creamBg),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.white.withOpacity(0.3),
            ), // Light glass tint
          ),
          // Crisp uncropped image
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: topOne.imageUrl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunnerUpTile(ArtworkModel artwork, int rank) {
    final isTrending = rank == 2 || rank == 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/artwork/${artwork.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isTrending
                ? Border.all(
                    color: AppColors.coral.withOpacity(0.6),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: isTrending
                    ? AppColors.coral.withOpacity(0.05)
                    : AppColors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 40,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.black.withOpacity(
                      0.2,
                    ), // Light grey matching screenshot
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              // Thumbnail
              Hero(
                tag: 'top_art_${artwork.id}',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(artwork.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artwork.authorUsername != null
                          ? '@${artwork.authorUsername}'
                          : 'user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isTrending) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Trending',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.coral,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Transform.translate(
                              offset: const Offset(
                                0,
                                -2.5,
                              ), // Decrease the Y value to move it further UP
                              child: Transform.scale(
                                scale: 1.5,
                                child: Lottie.asset(
                                  'assets/lottie/fire.json',
                                  width: 10,
                                  height: 10,
                                  repeat: true,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Likes
              isTrending
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: AppColors.coral,
                          size: 16,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${artwork.likesCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.coral,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          color: AppColors.darkGrey,
                          size: 16,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${artwork.likesCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGrey,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
