import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/auth_repository.dart';

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
  RealtimeChannel? _topArtChannel;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTopArtworks();
    _subscribeToTopArtUpdates();
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
        title: const Text(
          'Top Art of the Day',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.black),
            onPressed: _loadTopArtworks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            )
          : !hasArt
          ? const Center(
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
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Countdown Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New picks in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          _formatDuration(_timeLeft),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.coral,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // #1 Ranked Art card
                  if (topOne != null)
                    GestureDetector(
                      onTap: () => context.push('/artwork/${topOne.id}'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.creamLight,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.lightGrey,
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _isTopOnePortrait
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left side details (Expanded)
                                  Expanded(
                                    flex: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.emoji_events,
                                                color: Colors.amber.shade700,
                                                size: 28,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                '1',
                                                style: TextStyle(
                                                  color: AppColors.black,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 28,
                                                ),
                                              ),
                                              const Spacer(),
                                              const Icon(
                                                Icons.favorite,
                                                color: AppColors.coral,
                                                size: 20,
                                              ),
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
                                          const SizedBox(height: 16),
                                          Text(
                                            topOne.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.black,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundImage:
                                                    topOne.authorAvatarUrl !=
                                                            null &&
                                                        topOne
                                                            .authorAvatarUrl!
                                                            .isNotEmpty
                                                    ? CachedNetworkImageProvider(
                                                        topOne.authorAvatarUrl!,
                                                      )
                                                    : null,
                                                child:
                                                    topOne.authorAvatarUrl ==
                                                            null ||
                                                        topOne
                                                            .authorAvatarUrl!
                                                            .isEmpty
                                                    ? const Icon(
                                                        Icons.person,
                                                        size: 10,
                                                        color: AppColors.black,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  topOne.authorUsername != null
                                                      ? (topOne.userId ==
                                                                AuthRepository()
                                                                    .currentUser
                                                                    ?.id
                                                            ? '@${topOne.authorUsername} (You)'
                                                            : '@${topOne.authorUsername}')
                                                      : 'user',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.black
                                                        .withOpacity(0.7),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (topOne.tags.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: topOne.tags
                                                  .map(
                                                    (tag) => Text(
                                                      '#$tag',
                                                      style: const TextStyle(
                                                        color: AppColors.coral,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                          if (topOne.description != null &&
                                              topOne.description!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              topOne.description!,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.black
                                                    .withOpacity(0.7),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Right side image (in full portrait view inside container)
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      height: 280,
                                      color: AppColors.creamDark,
                                      child: CachedNetworkImage(
                                        imageUrl: topOne.imageUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.coral,
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.broken_image,
                                              color: AppColors.darkGrey,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Stack(
                                    children: [
                                      // Large Artwork
                                      CachedNetworkImage(
                                        imageUrl: topOne.imageUrl,
                                        fit: BoxFit.cover,
                                        height: 240,
                                        width: double.infinity,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: AppColors.creamDark,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: AppColors.creamDark,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: AppColors.darkGrey,
                                              ),
                                            ),
                                      ),

                                      // Victory Badge (Trophy + 1)
                                      Positioned(
                                        top: 16,
                                        left: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade700,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.emoji_events,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '1',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Card Footer Details
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage:
                                              topOne.authorAvatarUrl != null &&
                                                  topOne
                                                      .authorAvatarUrl!
                                                      .isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  topOne.authorAvatarUrl!,
                                                )
                                              : null,
                                          child:
                                              topOne.authorAvatarUrl == null ||
                                                  topOne
                                                      .authorAvatarUrl!
                                                      .isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  color: AppColors.black,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                topOne.title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                topOne.authorUsername != null
                                                    ? (topOne.userId ==
                                                              AuthRepository()
                                                                  .currentUser
                                                                  ?.id
                                                          ? '@${topOne.authorUsername} (You)'
                                                          : '@${topOne.authorUsername}')
                                                    : 'user',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.black
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.favorite,
                                          color: AppColors.coral,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${topOne.likesCount}',
                                          style: const TextStyle(
                                            fontSize: 14,
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

                  const SizedBox(height: 24),

                  // Rankings List (#2 to #10)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: restRankings.length,
                    itemBuilder: (context, index) {
                      final artwork = restRankings[index];
                      final rank = index + 2;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => context.push('/artwork/${artwork.id}'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.creamLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.lightGrey,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Rank Number (Only show top 5 ranks, bullet for rest)
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    rank <= 5 ? '#$rank' : '•',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: rank <= 5
                                          ? AppColors.coral
                                          : AppColors.darkGrey,
                                    ),
                                  ),
                                ),

                                // Thumbnail Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: artwork.imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.creamDark),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.creamDark,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.darkGrey,
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Title & Handle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        artwork.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        artwork.authorUsername != null
                                            ? '@${artwork.authorUsername}'
                                            : 'user',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.black.withOpacity(
                                            0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Likes count
                                const Icon(
                                  Icons.favorite_border,
                                  color: AppColors.black,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${artwork.likesCount}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.black.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
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
                icon: const Icon(Icons.home_outlined, color: AppColors.black),
                onPressed: () => context.go('/'),
              ),
              IconButton(
                icon: const Icon(Icons.search_outlined, color: AppColors.black),
                onPressed: () => context.push('/search'),
              ),
              GestureDetector(
                onTap: () => context.push('/upload'),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.black,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add,
                    color: AppColors.creamLight,
                    size: 24,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.emoji_events, color: AppColors.coral),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.person_outline, color: AppColors.black),
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
