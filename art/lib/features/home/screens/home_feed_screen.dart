import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final List<String> _categories = [
    'For You',
    'Following',
    'Portrait',
    'Landscape',
  ];
  int _selectedCategoryIndex = 0;

  ProfileModel? _myProfile;
  List<ProfileModel> _creators = [];
  List<ArtworkModel> _masonryArtworks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final artworks = await ArtworkRepository().fetchLatestArtworks();
      final currentUserId = AuthRepository().currentUser?.id;
      List<ProfileModel> creators = [];
      ProfileModel? myProfile;
      if (currentUserId != null) {
        // Fetch current user's profile
        myProfile = await ProfileRepository().getProfile(currentUserId);
        
        // Fallback to Auth metadata if profiles table record is missing/delayed
        if (myProfile == null) {
          final email = AuthRepository().currentUser?.email ?? '';
          final metaUsername = AuthRepository().currentUser?.userMetadata?['username'] as String? ?? email.split('@').first;
          myProfile = ProfileModel(
            id: currentUserId,
            username: metaUsername,
            displayName: AuthRepository().currentUser?.userMetadata?['display_name'] as String? ?? metaUsername,
            avatarUrl: '',
            bio: 'Artist member',
            createdAt: DateTime.now(),
          );
        }

        creators.add(myProfile);

        // Fetch followed creators
        final followed = await SocialRepository().fetchFollowing(currentUserId);
        creators.addAll(followed);
      }
      if (mounted) {
        setState(() {
          _myProfile = myProfile;
          _masonryArtworks = artworks;
          _creators = creators;
        });
      }
    } catch (e) {
      print('HomeFeedScreen _loadData error: $e');
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ArtworkModel> get _filteredArtworks {
    final currentUserId = AuthRepository().currentUser?.id;
    if (currentUserId == null) return _masonryArtworks;

    switch (_selectedCategoryIndex) {
      case 0: // For You
        return _masonryArtworks;
      case 1: // Following
        final followedIds = _creators
            .where((c) => c.id != currentUserId)
            .map((c) => c.id)
            .toSet();
        return _masonryArtworks
            .where((art) => followedIds.contains(art.userId))
            .toList();
      case 2: // Portrait
        return _masonryArtworks
            .where(
              (art) =>
                  art.userId == currentUserId &&
                  (art.tags.contains('portrait') ||
                      (!art.tags.contains('landscape') &&
                          art.id.hashCode % 2 == 0)),
            )
            .toList();
      case 3: // Landscape
        return _masonryArtworks
            .where(
              (art) =>
                  art.userId == currentUserId &&
                  (art.tags.contains('landscape') ||
                      (!art.tags.contains('portrait') &&
                          art.id.hashCode % 2 != 0)),
            )
            .toList();
      default:
        return _masonryArtworks;
    }
  }

  double _getAspectRatioForIndex(int index) {
    final ratios = [0.75, 1.0, 1.25, 0.9, 1.1];
    return ratios[index % ratios.length];
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Discover AI Art (left) & Actions (right)
              Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 12,
                  bottom: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text.rich(
                      TextSpan(
                        text: 'Discover ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        children: [
                          TextSpan(
                            text: 'AI Art',
                            style: TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Notification Bell with Red Dot
                        Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: AppColors.creamLight,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.black,
                                  size: 24,
                                ),
                                onPressed: () => context.push('/notifications'),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.coral,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Search button
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.creamLight,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.search_outlined,
                              color: AppColors.black,
                              size: 24,
                            ),
                            onPressed: () => context.push('/search'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Horizontal active creators scroll
              SizedBox(
                height: 100,
                child: _creators.isEmpty
                    ? const Center(
                        child: Text(
                          'No followed creators yet. Search to find new artists!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkGrey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _creators.length,
                        itemBuilder: (context, index) {
                          final creator = _creators[index];
                          final isMe =
                              creator.id == AuthRepository().currentUser?.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () {
                                if (isMe) {
                                  context.go('/profile');
                                } else {
                                  context.push('/profile/${creator.id}');
                                }
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isMe
                                            ? AppColors.black
                                            : AppColors.coral,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundImage:
                                          creator.avatarUrl != null &&
                                              creator.avatarUrl!.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              creator.avatarUrl!,
                                            )
                                          : null,
                                      child:
                                          creator.avatarUrl == null ||
                                              creator.avatarUrl!.isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              color: AppColors.black,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isMe
                                        ? 'You'
                                        : (creator.displayName ??
                                              creator.username),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isMe
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: AppColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Categories Section Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/feed-view-all'),
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.coral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Categories list horizontal
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = index == _selectedCategoryIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.black
                                : AppColors.creamLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.black
                                  : AppColors.lightGrey,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.creamLight
                                  : AppColors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Masonry Art Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.coral,
                          ),
                        )
                      : _filteredArtworks.isEmpty
                      ? const Center(
                          child: Text(
                            'No artworks found',
                            style: TextStyle(
                              color: AppColors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.coral,
                          child: MasonryGridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            itemCount: _filteredArtworks.length,
                            itemBuilder: (context, index) {
                              final artwork = _filteredArtworks[index];
                              final aspectRatio = _getAspectRatioForIndex(
                                index,
                              );
                              return GestureDetector(
                                onTap: () =>
                                    context.push('/artwork/${artwork.id}'),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: artwork.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            AspectRatio(
                                              aspectRatio: aspectRatio,
                                              child: Container(
                                                color: AppColors.creamDark,
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            AspectRatio(
                                              aspectRatio: aspectRatio,
                                              child: Container(
                                                color: AppColors.creamDark,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: AppColors.darkGrey,
                                                ),
                                              ),
                                            ),
                                      ),

                                      // Likes Badge on top-right
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.black.withOpacity(
                                              0.4,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.favorite,
                                                color: AppColors.coral,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${artwork.likesCount}',
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

                                      // Author avatar / handle on bottom-left if present
                                      if (artwork.authorUsername != null)
                                        Positioned(
                                          bottom: 12,
                                          left: 12,
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 10,
                                                backgroundImage:
                                                    artwork.authorAvatarUrl !=
                                                            null &&
                                                        artwork
                                                            .authorAvatarUrl!
                                                            .isNotEmpty
                                                    ? CachedNetworkImageProvider(
                                                        artwork
                                                            .authorAvatarUrl!,
                                                      )
                                                    : null,
                                                child:
                                                    artwork.authorAvatarUrl ==
                                                            null ||
                                                        artwork
                                                            .authorAvatarUrl!
                                                            .isEmpty
                                                    ? const Icon(
                                                        Icons.person,
                                                        size: 8,
                                                        color: AppColors.black,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                artwork.userId == AuthRepository().currentUser?.id
                                                    ? '@${artwork.authorUsername} (You)'
                                                    : '@${artwork.authorUsername}',
                                                style: const TextStyle(
                                                  color: AppColors.creamLight,
                                                  fontSize: 11,
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
                                            ],
                                          ),
                                        ),
                                    ],
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
                onPressed: () {},
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
                icon: const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.black,
                ),
                onPressed: () => context.push('/top-art'),
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
