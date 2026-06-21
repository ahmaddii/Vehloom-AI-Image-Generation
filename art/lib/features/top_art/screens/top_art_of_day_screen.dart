import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/repositories/artwork_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTopArtworks();
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

  Future<void> _loadTopArtworks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final artworks = await ArtworkRepository().fetchLatestArtworks();
      // Sort by likesCount descending
      artworks.sort((a, b) => b.likesCount.compareTo(a.likesCount));
      
      if (mounted) {
        setState(() {
          _topArtworks = artworks;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
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
    final restRankings = hasArt ? _topArtworks.skip(1).take(10).toList() : <ArtworkModel>[];

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
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : !hasArt
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No artworks have been uploaded yet today. Be the first to upload!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.bold),
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
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                              border: Border.all(color: AppColors.lightGrey, width: 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
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
                                      placeholder: (context, url) => Container(color: AppColors.creamDark),
                                      errorWidget: (context, url, error) => Container(
                                        color: AppColors.creamDark,
                                        child: const Icon(Icons.broken_image, color: AppColors.darkGrey),
                                      ),
                                    ),
                                    
                                    // Yellow #1 Badge
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          '#1',
                                          style: TextStyle(
                                            color: AppColors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
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
                                        backgroundImage: topOne.authorAvatarUrl != null && topOne.authorAvatarUrl!.isNotEmpty
                                            ? CachedNetworkImageProvider(topOne.authorAvatarUrl!)
                                            : null,
                                        child: topOne.authorAvatarUrl == null || topOne.authorAvatarUrl!.isEmpty
                                            ? const Icon(Icons.person, color: AppColors.black)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                              topOne.authorUsername != null ? '@${topOne.authorUsername}' : 'user',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.black.withOpacity(0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.favorite, color: AppColors.coral, size: 20),
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
                                  border: Border.all(color: AppColors.lightGrey, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    // Rank Number
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        '#$rank',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.coral,
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
                                        placeholder: (context, url) => Container(color: AppColors.creamDark),
                                        errorWidget: (context, url, error) => Container(
                                          color: AppColors.creamDark,
                                          child: const Icon(Icons.broken_image, color: AppColors.darkGrey),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Title & Handle
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                            artwork.authorUsername != null ? '@${artwork.authorUsername}' : 'user',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.black.withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Likes count
                                    const Icon(Icons.favorite_border, color: AppColors.black, size: 16),
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
