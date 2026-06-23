import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/widgets/custom_add_button.dart';
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
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          if (!hasArt && _isLoading)
            Container(
              color: AppColors.creamBg,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.coral),
              ),
            )
          else if (!hasArt)
            _buildEmptyState()
          else
            CustomScrollView(
              slivers: [
                if (topOne != null) _buildSliverHero(topOne),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.creamBg,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                          child: Text(
                            'Runner Ups',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: AppColors.black.withOpacity(0.8),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: restRankings.length,
                            itemBuilder: (context, index) => _buildRunnerUpTile(
                              restRankings[index],
                              index + 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(color: AppColors.creamBg),
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
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No artworks have been uploaded yet today. Be the first to upload!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHero(ArtworkModel topOne) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.65,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.black,
      leading: Navigator.of(context).canPop()
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.creamLight,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            )
          : null,
      title: const Text(
        'Art of the Day',
        style: TextStyle(
          color: AppColors.creamLight,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh,
                color: AppColors.creamLight,
                size: 20,
              ),
              onPressed: _loadTopArtworks,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: GestureDetector(
          onTap: () => context.push('/artwork/${topOne.id}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Blurred Background Image
              CachedNetworkImage(
                imageUrl: topOne.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.black),
                errorWidget: (context, url, error) =>
                    Container(color: AppColors.black),
              ),
              // 2. Heavy Blur Filter
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
              // 3. Crisp, Uncropped Artwork
              CachedNetworkImage(
                imageUrl: topOne.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
              // Gradient Overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
              // Content overlaid on the image
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge and Timer Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            '#1 WINNER',
                            style: TextStyle(
                              color: AppColors.creamLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Resets in ${_formatDuration(_timeLeft)}',
                            style: const TextStyle(
                              color: AppColors.creamLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      topOne.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.creamLight,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage:
                              topOne.authorAvatarUrl != null &&
                                  topOne.authorAvatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  topOne.authorAvatarUrl!,
                                )
                              : null,
                          child:
                              topOne.authorAvatarUrl == null ||
                                  topOne.authorAvatarUrl!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.creamLight,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            topOne.authorUsername != null
                                ? '@${topOne.authorUsername}'
                                : 'user',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.creamLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.favorite,
                          color: AppColors.coral,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${topOne.likesCount}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.creamLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunnerUpTile(ArtworkModel artwork, int rank) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('/artwork/${artwork.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.creamLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.04),
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
                    fontSize: rank <= 3 ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: rank <= 3 ? AppColors.coral : AppColors.darkGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              // Thumbnail
              Hero(
                tag: 'top_art_${artwork.id}',
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
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
                        fontSize: 16,
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
                        fontSize: 13,
                        color: AppColors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Likes
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.creamBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: AppColors.coral,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${artwork.likesCount}',
                      style: const TextStyle(
                        fontSize: 13,
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
      ),
    );
  }


}
