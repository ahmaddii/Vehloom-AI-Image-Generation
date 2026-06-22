import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _targetUserId = widget.userId ?? _currentUserId;
    _isMe = _targetUserId == _currentUserId;

    _loadProfileData();
    _subscribeToProfileUpdates();
  }

  @override
  void dispose() {
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

      final profile = await ProfileRepository().getProfile(_targetUserId);
      final artworks = await ArtworkRepository().fetchUserArtworks(
        _targetUserId,
      );
      final favoritedArtworks = await ArtworkRepository().fetchUserFavorites(
        _targetUserId,
      );

      final followers = await SocialRepository().fetchFollowers(_targetUserId);
      final following = await SocialRepository().fetchFollowing(_targetUserId);

      bool isFollowing = false;
      if (!_isMe && _currentUserId.isNotEmpty) {
        isFollowing = await SocialRepository().isFollowing(
          _currentUserId,
          _targetUserId,
        );
      }

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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.black.withOpacity(0.4),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        title: Text(
          _profile != null ? '@${_profile!.username}' : 'Profile',
          style: const TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_isMe) ...[
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.coral),
              tooltip: 'Sign Out',
              onPressed: _signOut,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.black),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            )
          : _profile == null
          ? const Center(
              child: Text(
                'Profile not found',
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Column(
              children: [
                // Profile Details Area
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      // Circular Avatar with Coral Border
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.coral, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundImage:
                              _profile!.avatarUrl != null &&
                                  _profile!.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(_profile!.avatarUrl!)
                              : null,
                          child:
                              _profile!.avatarUrl == null ||
                                  _profile!.avatarUrl!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 46,
                                  color: AppColors.black,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Display Name & Bio
                      Text(
                        _profile!.displayName ?? _profile!.username,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profile!.bio != null && _profile!.bio!.isNotEmpty
                            ? _profile!.bio!
                            : 'No bio yet ✦',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('${_artworks.length}', 'Posts'),
                          _buildStatColumn(
                            '$_followersCount',
                            'Followers',
                            onTap: () => _showSocialList(true),
                          ),
                          _buildStatColumn(
                            '$_followingCount',
                            'Following',
                            onTap: () => _showSocialList(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: _isMe
                            ? OutlinedButton(
                                onPressed: () async {
                                  await context.push('/edit-profile');
                                  _loadProfileData(); // Reload profile updates when returning
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.black,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  backgroundColor: AppColors.creamLight,
                                ),
                                child: const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: AppColors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: _isFollowing
                                      ? AppColors.creamDark
                                      : AppColors.black,
                                  foregroundColor: _isFollowing
                                      ? AppColors.black
                                      : AppColors.creamLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Tab bar (Grid / Saved)
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.black,
                  indicatorWeight: 2,
                  labelColor: AppColors.black,
                  unselectedLabelColor: AppColors.black.withOpacity(0.3),
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_outlined)),
                    Tab(icon: Icon(Icons.bookmark_border)),
                  ],
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Artworks Grid
                      _artworks.isEmpty
                          ? const Center(
                              child: Text(
                                'No artworks posted yet.',
                                style: TextStyle(color: AppColors.darkGrey),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(2),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                              itemCount: _artworks.length,
                              itemBuilder: (context, index) {
                                final artwork = _artworks[index];
                                return GestureDetector(
                                  onTap: () =>
                                      context.push('/artwork/${artwork.id}'),
                                  child: CachedNetworkImage(
                                    imageUrl: artwork.imageUrl,
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
                                );
                              },
                            ),

                      // Saved Tab (Actual Favorites Grid)
                      _favoritedArtworks.isEmpty
                          ? const Center(
                              child: Text(
                                'No saved artworks yet.',
                                style: TextStyle(color: AppColors.darkGrey),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(2),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                              itemCount: _favoritedArtworks.length,
                              itemBuilder: (context, index) {
                                final artwork = _favoritedArtworks[index];
                                return GestureDetector(
                                  onTap: () =>
                                      context.push('/artwork/${artwork.id}'),
                                  child: CachedNetworkImage(
                                    imageUrl: artwork.imageUrl,
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
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),

      // Bottom Navigation Bar
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
                icon: Icon(
                  Icons.home_outlined,
                  color: _isMe ? AppColors.black : AppColors.black,
                ),
                onPressed: () => context.go('/'),
              ),
              IconButton(
                icon: const Icon(Icons.search_outlined, color: AppColors.black),
                onPressed: () => context.push('/search'),
              ),

              // Center FAB Button
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
                icon: Icon(
                  Icons.person,
                  color: _isMe ? AppColors.coral : AppColors.black,
                ),
                onPressed: () {
                  if (!_isMe) {
                    context.go('/profile');
                  }
                },
              ),
            ],
          ),
        ),
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
      decoration: const BoxDecoration(
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.lightGrey, thickness: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                : _users.isEmpty
                ? Center(
                    child: Text(
                      widget.isFollowers
                          ? 'No followers yet.'
                          : 'Not following anyone yet.',
                      style: const TextStyle(
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
                                ? const Icon(
                                    Icons.person,
                                    color: AppColors.black,
                                  )
                                : null,
                          ),
                        ),
                        title: Text(
                          user.displayName ?? user.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: const TextStyle(
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
