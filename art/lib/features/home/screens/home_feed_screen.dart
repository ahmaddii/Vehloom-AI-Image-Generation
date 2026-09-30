import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/story_model.dart';
import '../../../data/repositories/story_repository.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gal/gal.dart';
import 'explore_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/number_utils.dart';
import 'package:lottie/lottie.dart';
import '../../chat/widgets/share_to_chat_bottom_sheet.dart';

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
    'Community',
    'Explore',
    'Following',
    'Portrait',
    'Landscape',
  ];
  int _selectedCategoryIndex = 0;

  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  List<ProfileModel> _creators = [];
  ProfileModel? _myProfile;
  List<StoryModel> _activeStories = [];
  List<ArtworkModel> _masonryArtworks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  bool _hasMore = true;
  int _unreadNotificationsCount = 0;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _feedChannel;
  bool _hasNewPosts = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeData();
    _loadUnreadNotificationsCount();
    _subscribeToNotificationBadge();
    _subscribeToFeedUpdates();

    // Request notification permission if not already requested
    PushNotificationService().init().catchError((e) {
      debugPrint('Error initializing push notifications: $e');
    });
  }

  Future<void> _initializeData() async {
    await _loadCachedData();
    _loadData(showLoading: _masonryArtworks.isEmpty);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
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
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadData(showLoading: false, isLoadMore: true);
      }
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Feed Cache
      final artworksJson = prefs.getString('cached_home_feed');
      if (artworksJson != null) {
        final List decoded = jsonDecode(artworksJson);
        final artworks = decoded
            .map((e) => ArtworkModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _masonryArtworks = artworks;
            _isLoading = false; // Disable loader instantly!
          });
        }
      }

      // Load Stories Cache
      final storiesJson = prefs.getString('cached_home_stories');
      if (storiesJson != null) {
        final List decoded = jsonDecode(storiesJson);
        final stories = decoded
            .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _activeStories = stories;
          });
        }
      }

      // Load Creators Cache
      final creatorsJson = prefs.getString('cached_home_creators');
      if (creatorsJson != null) {
        final List decoded = jsonDecode(creatorsJson);
        final creators = decoded
            .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _creators = creators;
          });
        }
      }
    } catch (_) {}
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
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              if (mounted) {
                setState(() {
                  _hasNewPosts = true;
                });
              }
            } else {
              _loadData(showLoading: false);
            }
          },
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

  Future<void> _loadData({
    bool showLoading = true,
    bool isLoadMore = false,
  }) async {
    if (!mounted) return;

    if (!isLoadMore) {
      _currentOffset = 0;
      _hasMore = true;
    }

    if (_isLoadingMore || !_hasMore) return;

    if (showLoading && !isLoadMore) {
      setState(() {
        _isLoading = true;
        _hasNewPosts = false;
      });
    }

    if (isLoadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final currentUserId = AuthRepository().currentUser?.id;

      late List<ArtworkModel> newArtworks;
      ProfileModel? myProfile;
      List<StoryModel> activeStories = [];
      List<ProfileModel> followed = [];
      List<ProfileModel> followers = [];

      // Parallel execution for massive speed boost
      await Future.wait([
        ArtworkRepository()
            .fetchLatestArtworks(offset: _currentOffset, limit: 20)
            .then((v) => newArtworks = v),
        if (currentUserId != null && !isLoadMore)
          ProfileRepository()
              .getProfile(currentUserId)
              .then((v) => myProfile = v),
        if (currentUserId != null && !isLoadMore)
          StoryRepository().fetchActiveStories().then((v) => activeStories = v),
        if (currentUserId != null && !isLoadMore)
          SocialRepository()
              .fetchFollowing(currentUserId)
              .then((v) => followed = v),
        if (currentUserId != null && !isLoadMore)
          SocialRepository()
              .fetchFollowers(currentUserId)
              .then((v) => followers = v),
      ]);

      List<ProfileModel> creators = [];
      if (currentUserId != null && !isLoadMore) {
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

        creators.add(myProfile!);
        
        final allRelatedUsers = [...followed, ...followers];
        final uniqueCreators = <String, ProfileModel>{};
        for (var user in allRelatedUsers) {
          uniqueCreators[user.id] = user;
        }
        creators.addAll(uniqueCreators.values);
      }

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _masonryArtworks.addAll(newArtworks);
          } else {
            if (myProfile != null) _myProfile = myProfile;
            _masonryArtworks = newArtworks;
            _creators = creators;
            _activeStories = activeStories;

            // Save fresh data to local cache for instant next startup
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString(
                'cached_home_feed',
                jsonEncode(newArtworks.map((e) => e.toJson()).toList()),
              );
              prefs.setString(
                'cached_home_stories',
                jsonEncode(activeStories.map((e) => e.toJson()).toList()),
              );
              prefs.setString(
                'cached_home_creators',
                jsonEncode(creators.map((e) => e.toJson()).toList()),
              );
            });
          }

          if (newArtworks.length < 20) {
            _hasMore = false;
          } else {
            _currentOffset += 20;
          }
        });
      }
    } catch (e) {
      print('HomeFeedScreen _loadData error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  List<ArtworkModel> get _filteredArtworks {
    final currentUserId = AuthRepository().currentUser?.id;

    switch (_selectedCategoryIndex) {
      case 0: // Community
        return _masonryArtworks;
      case 1: // Explore
        return [];
      case 2: // Following
        if (currentUserId == null) return [];
        final followedIds = _creators
            .where((c) => c.id != currentUserId)
            .map((c) => c.id)
            .toSet();
        return _masonryArtworks
            .where((art) => followedIds.contains(art.userId))
            .toList();
      case 3: // Portrait
        return _masonryArtworks.where(_isPortraitArtwork).toList();
      case 4: // Landscape
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

  Widget _buildSkeletonGrid() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: 6,
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
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoriesSkeleton() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Shimmer.fromColors(
                baseColor: AppColors.creamDark,
                highlightColor: AppColors.creamLight,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Shimmer.fromColors(
                baseColor: AppColors.creamDark,
                highlightColor: AppColors.creamLight,
                child: Container(width: 40, height: 10, color: Colors.white),
              ),
            ],
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
                    Text.rich(
                      TextSpan(
                        text: 'Discover ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        children: [
                          TextSpan(
                            text: 'Art',
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
                              decoration: BoxDecoration(
                                color: AppColors.creamLight,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
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
                                  padding: EdgeInsets.symmetric(horizontal: 5),
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
                                    style: TextStyle(
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
                        // Inbox button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.creamLight,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.black,
                              size: 22,
                            ),
                            onPressed: () => context.push('/inbox'),
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
                child: _isLoading
                    ? _buildStoriesSkeleton()
                    : _creators.isEmpty
                    ? Center(
                        child: Text(
                          'No followed creators yet. Search to find new artists!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkGrey,
                          ),
                        ),
                      )
                    : ListenableBuilder(
                        listenable: PreferencesService(),
                        builder: (context, _) {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _creators.length,
                            itemBuilder: (context, index) {
                              final creator = _creators[index];
                              final isMe =
                                  creator.id ==
                                  AuthRepository().currentUser?.id;
                              final creatorStories = _activeStories
                                  .where((story) => story.userId == creator.id)
                                  .toList();
                              final hasStories = creatorStories.isNotEmpty;
                              final hasUnviewed =
                                  hasStories &&
                                  PreferencesService().hasUnviewedStories(
                                    creator.id,
                                    creatorStories,
                                  );

                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
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
                                        _showCreatorOptions(creator);
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
                                              gradient: hasUnviewed
                                                  ? const SweepGradient(
                                                      colors: [
                                                        AppColors.coral,
                                                        Color(0xFFFF007F),
                                                        Color(0xFFFF7F00),
                                                        AppColors.coral,
                                                      ],
                                                    )
                                                  : null,
                                              border:
                                                  (hasStories && !hasUnviewed)
                                                  ? Border.all(
                                                      color:
                                                          AppColors.lightGrey,
                                                      width: 2.5,
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
                                                        creator
                                                            .avatarUrl!
                                                            .isEmpty
                                                    ? Icon(
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
                                                onTap: () =>
                                                    _showMyStoryOptions(),
                                                behavior:
                                                    HitTestBehavior.opaque,
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
                                                  child: Icon(
                                                    Icons.add,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      SizedBox(
                                        width: 74,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
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
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            if (!isMe && creator.isVerified) ...[
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.verified,
                                                color: Colors.blueAccent,
                                                size: 14,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),

              SizedBox(height: 18),

              // Categories Section Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/feed-view-all'),
                      child: Text(
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

              SizedBox(height: 12),

              // Categories list horizontal
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = index == _selectedCategoryIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (index == 1) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ExploreScreen(),
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedCategoryIndex = index;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
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

              SizedBox(height: 16),

              // Masonry Art Grid
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _isLoading
                          ? _buildSkeletonGrid()
                          : _filteredArtworks.isEmpty
                          ? Center(
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
                              child: AnimationLimiter(
                                child: MasonryGridView.count(
                                  controller: _scrollController,
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  itemCount: _filteredArtworks.length,
                                  itemBuilder: (context, index) {
                                    final artwork = _filteredArtworks[index];
                                    final aspectRatio = _getAspectRatioForIndex(
                                      index,
                                    );
                                    return AnimationConfiguration.staggeredGrid(
                                      position: index,
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      columnCount: 2,
                                      child: SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(
                                          child: _DoubleTapLikeWrapper(
                                            onDoubleTap: () async {
                                              final currentUserId =
                                                  AuthRepository()
                                                      .currentUser
                                                      ?.id;
                                              if (currentUserId != null) {
                                                // Trigger like in background
                                                try {
                                                  await ArtworkRepository()
                                                      .toggleLike(
                                                        artwork.id,
                                                        currentUserId,
                                                      );
                                                  _loadData(showLoading: false);
                                                } catch (_) {}
                                              }
                                            },
                                            onTap: () async {
                                              await context.push(
                                                '/artwork/${artwork.id}',
                                              );
                                              if (mounted) {
                                                _loadData(showLoading: false);
                                              }
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              child: Stack(
                                                children: [
                                                  Hero(
                                                    tag:
                                                        'artwork-${artwork.id}',
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          ImageUtils.getThumbnailUrl(
                                                            artwork.imageUrl,
                                                            width: 400,
                                                            height:
                                                                (400 / aspectRatio)
                                                                    .round(),
                                                          ),
                                                      memCacheWidth: 400,
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => AspectRatio(
                                                            aspectRatio:
                                                                aspectRatio,
                                                            child: Container(
                                                              color: AppColors
                                                                  .creamDark,
                                                            ),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            url,
                                                            error,
                                                          ) => AspectRatio(
                                                            aspectRatio:
                                                                aspectRatio,
                                                            child: Container(
                                                              color: AppColors
                                                                  .creamDark,
                                                              child: Icon(
                                                                Icons
                                                                    .broken_image,
                                                                color: AppColors
                                                                    .darkGrey,
                                                              ),
                                                            ),
                                                          ),
                                                    ),
                                                  ),

                                                  // Likes Badge on top-right
                                                  Positioned(
                                                    top: 12,
                                                    right: 12,
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.black
                                                            .withOpacity(0.4),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.favorite,
                                                            color:
                                                                AppColors.coral,
                                                            size: 12,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            NumberUtils.format(
                                                              artwork
                                                                  .likesCount,
                                                            ),
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),

                                                  // Author avatar / handle on bottom-left if present
                                                  if (artwork.authorDisplayName != null || artwork.authorUsername != null)
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
                                                                ? Icon(
                                                                    Icons
                                                                        .person,
                                                                    size: 8,
                                                                    color: Colors
                                                                        .black,
                                                                  )
                                                                : null,
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            artwork.userId ==
                                                                    AuthRepository()
                                                                        .currentUser
                                                                        ?.id
                                                                ? '${artwork.authorDisplayName ?? '@${artwork.authorUsername}'} (You)'
                                                                : artwork.authorDisplayName ?? '@${artwork.authorUsername}',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              shadows: [
                                                                Shadow(
                                                                  blurRadius:
                                                                      4.0,
                                                                  color: Colors
                                                                      .black,
                                                                  offset:
                                                                      Offset(
                                                                        0,
                                                                        1,
                                                                      ),
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
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                    // Live Feed Updates Pill
                    if (_hasNewPosts)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              _loadData(showLoading: true);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.coral,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.coral.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'New Posts Available',
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
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/ai-art');
        },
        backgroundColor: AppColors.coral,
        tooltip: 'Generate AI Art',
        child: Lottie.asset(
          'assets/lottie/AI Assistant.json',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  void _showCreatorOptions(ProfileModel creator) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.creamBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
              SizedBox(height: 24),
              Text(
                creator.displayName ?? creator.username,
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ListTile(
                leading: Icon(Icons.person_outline, color: AppColors.black),
                title: Text(
                  'View Profile',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile/${creator.id}');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.coral,
                ),
                title: Text(
                  'Message',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final currentUserId = AuthRepository().currentUser?.id;
                  if (currentUserId == null) return;
                  final repo = ChatRepository();
                  final room = await repo.createOrGetChatRoom(
                    currentUserId,
                    creator.id,
                  );
                  if (context.mounted) {
                    context.push('/chat/${room.id}?otherUserId=${creator.id}');
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.send_outlined, color: AppColors.black),
                title: Text(
                  'Send Creator in Chat',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        ShareToChatBottomSheet(sharedProfileId: creator.id),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMyStoryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.creamBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text(
                'Add to Story',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Share a photo with your followers for 24 hours',
                style: TextStyle(
                  color: AppColors.darkGrey,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStoryOptionCard(
                      icon: Icons.camera_alt_rounded,
                      title: 'Camera',
                      color: AppColors.coral,
                      onTap: () {
                        Navigator.pop(context);
                        _uploadStory(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStoryOptionCard(
                      icon: Icons.photo_library_rounded,
                      title: 'Gallery',
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _uploadStory(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/profile');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'View My Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoryOptionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.lightGrey.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _uploadStory(ImageSource source) async {
    final currentUserId = AuthRepository().currentUser?.id;
    if (currentUserId == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
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
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
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

class _DoubleTapLikeWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;
  final VoidCallback onTap;

  const _DoubleTapLikeWrapper({
    required this.child,
    required this.onDoubleTap,
    required this.onTap,
  });

  @override
  State<_DoubleTapLikeWrapper> createState() => _DoubleTapLikeWrapperState();
}

class _DoubleTapLikeWrapperState extends State<_DoubleTapLikeWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    widget.onDoubleTap();
    setState(() {
      _isAnimating = true;
    });
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _controller.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isAnimating = false;
              });
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_isAnimating)
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                Icons.favorite,
                color: Colors.white,
                size: 80,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
