import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/widgets/custom_add_button.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/number_utils.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProfileModel? _profile;
  List<ArtworkModel> _artworks = [];
  List<ArtworkModel> _favoritedArtworks = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isLoading = true;

  final String _currentUserId = AuthRepository().currentUser?.id ?? '';
  late final String _targetUserId;
  late final bool _isMe;
  RealtimeChannel? _profileChannel;
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderScrolledOut = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final isScrolledOut = _scrollController.offset > 250;
      if (isScrolledOut != _isHeaderScrolledOut) {
        setState(() {
          _isHeaderScrolledOut = isScrolledOut;
        });
      }
    });

    _tabController = TabController(length: 2, vsync: this);

    _targetUserId = widget.userId ?? _currentUserId;
    _isMe = _targetUserId == _currentUserId;

    _loadProfileData();
    _subscribeToProfileUpdates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    final channel = _profileChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToProfileUpdates() {
    if (_targetUserId.isEmpty) return;

    _profileChannel = Supabase.instance.client
        .channel('profile-live:$_targetUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _targetUserId,
          ),
          callback: (_) => _loadProfileData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'artworks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _targetUserId,
          ),
          callback: (_) => _loadProfileData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'follows',
          callback: (_) => _loadProfileData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'favorites',
          callback: (_) => _loadProfileData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (_) => _loadProfileData(showLoading: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (_) => _loadProfileData(showLoading: false),
        )
        .subscribe();
  }

  Future<void> _loadProfileData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (_targetUserId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      ProfileModel? profile;
      List<ArtworkModel> artworks = [];
      List<ArtworkModel> favoritedArtworks = [];
      List<ProfileModel> followers = [];
      List<ProfileModel> following = [];
      bool isFollowing = false;

      // Parallel execution
      await Future.wait([
        ProfileRepository().getProfile(_targetUserId).then((v) => profile = v),
        ArtworkRepository()
            .fetchUserArtworks(_targetUserId)
            .then((v) => artworks = v),
        ArtworkRepository()
            .fetchUserFavorites(_targetUserId)
            .then((v) => favoritedArtworks = v),
        SocialRepository()
            .fetchFollowers(_targetUserId)
            .then((v) => followers = v),
        SocialRepository()
            .fetchFollowing(_targetUserId)
            .then((v) => following = v),
        if (!_isMe && _currentUserId.isNotEmpty)
          SocialRepository()
              .isFollowing(_currentUserId, _targetUserId)
              .then((v) => isFollowing = v),
      ]);

      if (mounted) {
        setState(() {
          _profile = profile;
          _artworks = artworks;
          _favoritedArtworks = favoritedArtworks;
          _followersCount = followers.length;
          _followingCount = following.length;
          _isFollowing = isFollowing;
        });
      }
    } catch (_) {}

    if (mounted && showLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId.isEmpty || _isMe) return;

    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
      _followersCount = wasFollowing
          ? _followersCount - 1
          : _followersCount + 1;
    });

    try {
      if (wasFollowing) {
        await SocialRepository().unfollowUser(_currentUserId, _targetUserId);
      } else {
        await SocialRepository().followUser(_currentUserId, _targetUserId);
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followersCount = wasFollowing
              ? _followersCount + 1
              : _followersCount - 1;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await AuthRepository().signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  Widget _buildStatColumn(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.coral
              : AppColors.creamLight.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showSocialList(bool isFollowers) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SocialListBottomSheet(
        title: isFollowers ? 'Followers' : 'Following',
        userId: _targetUserId,
        isFollowers: isFollowers,
      ),
    );
    _loadProfileData();
  }

  Widget _buildGrid(List<ArtworkModel> artworks) {
    if (artworks.isEmpty) {
      return Center(
        child: Text(
          'No posts yet.',
          style: TextStyle(color: AppColors.darkGrey),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75, // Tall cards like the screenshot
      ),
      itemCount: artworks.length,
      itemBuilder: (context, index) {
        final artwork = artworks[index];
        return GestureDetector(
          onTap: () => context.push('/artwork/${artwork.id}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: ImageUtils.getThumbnailUrl(
                    artwork.imageUrl,
                    width: 400,
                    height: (400 / 0.75).round(),
                  ),
                  memCacheWidth: 400,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppColors.darkGrey),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.darkGrey,
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white24,
                    ),
                  ),
                ),
                // Gradient for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Title
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    artwork.description != null &&
                            artwork.description!.isNotEmpty
                        ? artwork.description!
                        : 'Untitled',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isHeaderScrolledOut
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.creamBg,
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.coral),
              )
            : _profile == null
            ? Center(
                child: Text(
                  'Profile not found',
                  style: TextStyle(
                    color: AppColors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B15),
                          border: Border.all(color: Colors.white24, width: 1),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 16,
                          bottom: 32,
                          left: 24,
                          right: 24,
                        ),
                        child: Column(
                          children: [
                            // Top Nav
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/');
                                    }
                                  },
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_isMe)
                                  GestureDetector(
                                    onTap: () => context.push('/settings'),
                                    child: Icon(
                                      Icons.tune,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 24),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Profile Info Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Large squircle avatar
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    color: AppColors.darkGrey,
                                    image:
                                        _profile!.avatarUrl != null &&
                                            _profile!.avatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(
                                              _profile!.avatarUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      _profile!.avatarUrl == null ||
                                          _profile!.avatarUrl!.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _profile!.displayName ??
                                            _profile!.username,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${_profile!.username}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Action Buttons
                                      Row(
                                        children: [
                                          if (_isMe)
                                            Expanded(
                                              child: _buildActionButton(
                                                'Edit Profile',
                                                true,
                                                () async {
                                                  await context.push(
                                                    '/edit-profile',
                                                  );
                                                  _loadProfileData();
                                                },
                                              ),
                                            )
                                          else ...[
                                            Expanded(
                                              child: _buildActionButton(
                                                _isFollowing
                                                    ? 'Following'
                                                    : 'Follow',
                                                !_isFollowing,
                                                _toggleFollow,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildActionButton(
                                                'Sign Out',
                                                false,
                                                _signOut,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Stats Row inside top card
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(
                                  NumberUtils.format(_artworks.length),
                                  'Posts',
                                ),
                                _buildStatColumn(
                                  NumberUtils.format(_followersCount),
                                  'Followers',
                                  onTap: () => _showSocialList(true),
                                ),
                                _buildStatColumn(
                                  NumberUtils.format(_followingCount),
                                  'Following',
                                  onTap: () => _showSocialList(false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        tabBar: TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.black,
                          indicatorWeight: 2,
                          labelColor: AppColors.black,
                          unselectedLabelColor: AppColors.darkGrey,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_on_outlined)),
                            Tab(icon: Icon(Icons.bookmark_border)),
                          ],
                        ),
                        topPadding: MediaQuery.of(context).padding.top,
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGrid(_artworks),
                    _buildGrid(_favoritedArtworks),
                  ],
                ),
              ),

        // Bottom Navigation Bar
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 4),
      ),
    );
  }
}

class SocialListBottomSheet extends StatefulWidget {
  final String title;
  final String userId;
  final bool isFollowers;

  const SocialListBottomSheet({
    super.key,
    required this.title,
    required this.userId,
    required this.isFollowers,
  });

  @override
  State<SocialListBottomSheet> createState() => _SocialListBottomSheetState();
}

class _SocialListBottomSheetState extends State<SocialListBottomSheet> {
  List<ProfileModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final users = widget.isFollowers
          ? await SocialRepository().fetchFollowers(widget.userId)
          : await SocialRepository().fetchFollowing(widget.userId);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppColors.creamBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.lightGrey, thickness: 1),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                : _users.isEmpty
                ? Center(
                    child: Text(
                      widget.isFollowers
                          ? 'No followers yet.'
                          : 'Not following anyone yet.',
                      style: TextStyle(
                        color: AppColors.darkGrey,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.coral,
                              width: 1,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                user.avatarUrl != null &&
                                    user.avatarUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : null,
                            child:
                                user.avatarUrl == null ||
                                    user.avatarUrl!.isEmpty
                                ? Icon(
                                    Icons.person,
                                    color: AppColors.black,
                                  )
                                : null,
                          ),
                        ),
                        title: Text(
                          user.displayName ?? user.username,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: AppColors.darkGrey,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final currentUserId =
                              AuthRepository().currentUser?.id;
                          if (user.id == currentUserId) {
                            context.go('/profile');
                          } else {
                            context.push('/profile/${user.id}');
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.tabBar, required this.topPadding});

  final TabBar tabBar;
  final double topPadding;

  @override
  double get minExtent => tabBar.preferredSize.height + topPadding;
  @override
  double get maxExtent => tabBar.preferredSize.height + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.creamBg, // The background color behind tabs
      padding: EdgeInsets.only(top: topPadding),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding || oldDelegate.tabBar != tabBar;
  }
}
