import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/story_model.dart';
import '../../../data/repositories/story_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Global RouteObserver instance – register this in MaterialApp/GoRouter
final RouteObserver<ModalRoute<void>> homeRouteObserver =
    RouteObserver<ModalRoute<void>>();

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with RouteAware {
  final List<String> _categories = [
    'For You',
    'Following',
    'Portrait',
    'Landscape',
  ];
  int _selectedCategoryIndex = 0;

  ProfileModel? _myProfile;
  List<ProfileModel> _creators = [];
  List<StoryModel> _activeStories = [];
  List<ArtworkModel> _masonryArtworks = [];
  bool _isLoading = true;
  int _unreadNotificationsCount = 0;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _feedChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadNotificationsCount();
    _subscribeToNotificationBadge();
    _subscribeToFeedUpdates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(this.context);
    if (route != null) {
      homeRouteObserver.subscribe(this, route);
    }
  }

  /// Called by RouteAware when the user pops back to this screen.
  @override
  void didPopNext() {
    // Silently refresh stories & feed when returning from any pushed route
    _loadData(showLoading: false);
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    final channel = _notificationsChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    final feedChannel = _feedChannel;
    if (feedChannel != null) {
      Supabase.instance.client.removeChannel(feedChannel);
    }
    super.dispose();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final currentUserId = AuthRepository().currentUser?.id;
    if (currentUserId == null) return;

    final count = await NotificationRepository().fetchUnreadCount(
      currentUserId,
    );
    if (!mounted) return;
    setState(() {
      _unreadNotificationsCount = count;
    });
  }

  void _subscribeToNotificationBadge() {
    final currentUserId = AuthRepository().currentUser?.id;
    if (currentUserId == null) return;

    _notificationsChannel = Supabase.instance.client
        .channel('home-notification-badge:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: currentUserId,
          ),
          callback: (_) => _loadUnreadNotificationsCount(),
        )
        .subscribe();
  }

  void _subscribeToFeedUpdates() {
    _feedChannel = Supabase.instance.client
        .channel('home-feed-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'artworks',
          callback: (_) => _loadData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (_) => _loadData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (_) => _loadData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'follows',
          callback: (_) => _loadData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) => _loadData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stories',
          callback: (_) => _loadData(showLoading: false),
        )
        .subscribe();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final artworks = await ArtworkRepository().fetchLatestArtworks();
      final currentUserId = AuthRepository().currentUser?.id;
      List<ProfileModel> creators = [];
      ProfileModel? myProfile;
      List<StoryModel> activeStories = [];
      if (currentUserId != null) {
        // Fetch current user's profile
        myProfile = await ProfileRepository().getProfile(currentUserId);

        // Fetch active stories
        activeStories = await StoryRepository().fetchActiveStories();

        // Fallback to Auth metadata if profiles table record is missing/delayed
        if (myProfile == null) {
          final email = AuthRepository().currentUser?.email ?? '';
          final metaUsername =
              AuthRepository().currentUser?.userMetadata?['username']
                  as String? ??
              email.split('@').first;
          myProfile = ProfileModel(
            id: currentUserId,
            username: metaUsername,
            displayName:
                AuthRepository().currentUser?.userMetadata?['display_name']
                    as String? ??
                metaUsername,
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
          _activeStories = activeStories;
        });
      }
    } catch (e) {
      print('HomeFeedScreen _loadData error: $e');
    }
    if (mounted && showLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ArtworkModel> get _filteredArtworks {
    final currentUserId = AuthRepository().currentUser?.id;

    switch (_selectedCategoryIndex) {
      case 0: // For You
        return _masonryArtworks;
      case 1: // Following
        if (currentUserId == null) return [];
        final followedIds = _creators
            .where((c) => c.id != currentUserId)
            .map((c) => c.id)
            .toSet();
        return _masonryArtworks
            .where((art) => followedIds.contains(art.userId))
            .toList();
      case 2: // Portrait
        return _masonryArtworks.where(_isPortraitArtwork).toList();
      case 3: // Landscape
        return _masonryArtworks.where(_isLandscapeArtwork).toList();
      default:
        return _masonryArtworks;
    }
  }

  bool _hasTag(ArtworkModel artwork, String tag) {
    return artwork.tags.any((item) => item.trim().toLowerCase() == tag);
  }

  bool _isPortraitArtwork(ArtworkModel artwork) {
    final hasPortrait = _hasTag(artwork, 'portrait');
    final hasLandscape = _hasTag(artwork, 'landscape');
    return hasPortrait && !hasLandscape;
  }

  bool _isLandscapeArtwork(ArtworkModel artwork) {
    return _hasTag(artwork, 'landscape');
  }

  double _getAspectRatioForIndex(int index) {
    final ratios = [0.75, 1.0, 1.25, 0.9, 1.1];
    return ratios[index % ratios.length];
  }

  @override
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
                        // Notification Bell
                        Stack(
                          clipBehavior: Clip.none,
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
                                onPressed: () async {
                                  await context.push('/notifications');
                                  await _loadUnreadNotificationsCount();
                                },
                              ),
                            ),
                            if (_unreadNotificationsCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.coral,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.creamBg,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.coral.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _unreadNotificationsCount > 99
                                        ? '99+'
                                        : '$_unreadNotificationsCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
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
                height: 90,
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
                          final creatorStories = _activeStories
                              .where((story) => story.userId == creator.id)
                              .toList();
                          final hasStories = creatorStories.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                if (hasStories) {
                                  context.push(
                                    '/story/${creator.id}',
                                    extra: {'stories': _activeStories},
                                  );
                                } else {
                                  if (isMe) {
                                    _showMyStoryOptions();
                                  } else {
                                    context.push('/profile/${creator.id}');
                                  }
                                }
                              },
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: hasStories
                                              ? const SweepGradient(
                                                  colors: [
                                                    AppColors.coral,
                                                    Color(0xFFFF007F),
                                                    Color(0xFFFF7F00),
                                                    AppColors.coral,
                                                  ],
                                                )
                                              : null,
                                        ),
                                        padding: EdgeInsets.all(
                                          hasStories ? 3.5 : 0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: hasStories
                                                ? AppColors.creamBg
                                                : Colors.transparent,
                                          ),
                                          padding: EdgeInsets.all(
                                            hasStories ? 2.5 : 0,
                                          ),
                                          child: CircleAvatar(
                                            radius: 26,
                                            backgroundImage:
                                                creator.avatarUrl != null &&
                                                    creator
                                                        .avatarUrl!
                                                        .isNotEmpty
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
                                      ),
                                      if (isMe)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () => _showMyStoryOptions(),
                                            behavior: HitTestBehavior.opaque,
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: AppColors.coral,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.creamBg,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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

              const SizedBox(height: 18),

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
                                                artwork.userId ==
                                                        AuthRepository()
                                                            .currentUser
                                                            ?.id
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

  void _showMyStoryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.creamBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 24),
              const Text(
                'Your Story',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.coral,
                ),
                title: const Text(
                  'Post a Photo Story',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadStoryFromGallery();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.black,
                ),
                title: const Text(
                  'View Profile',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/profile');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadStoryFromGallery() async {
    final currentUserId = AuthRepository().currentUser?.id;
    if (currentUserId == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final progressNotifier = ValueNotifier<double>(0.0);
      bool uploadFinished = false;
      Object? uploadError;

      // Start upload task in background
      final uploadFuture =
          (() async {
                final mediaUrl = await StoryRepository().uploadStoryImage(
                  file,
                  currentUserId,
                );
                await StoryRepository().createStory(
                  userId: currentUserId,
                  mediaUrl: mediaUrl,
                );
              })()
              .then((_) {
                uploadFinished = true;
              })
              .catchError((err) {
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
                              style: const TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
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

      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
      }

      if (uploadError != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to post story: $uploadError')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Story posted successfully!')),
        );
        _loadData(); // Reload stories
      }
    }
  }
}
