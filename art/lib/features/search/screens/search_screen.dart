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
import '../../../core/widgets/custom_add_button.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final List<String> _categories = ['All', 'Artists', 'Artwork', 'Tags'];
  int _selectedCategoryIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  List<ProfileModel> _creators = [];
  List<Map<String, dynamic>> _trendingCreatorsData = [];
  List<String> _trendingSearches = [];
  List<ArtworkModel> _trendingArtworks = [];
  List<ProfileModel> _searchResults = [];
  List<ArtworkModel> _artworkSearchResults = [];
  List<ArtworkModel> _tagSearchResults = [];
  final Map<String, bool> _followingMap = {};
  bool _isSearching = false;
  bool _isLoading = true;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';
  RealtimeChannel? _searchChannel;

  @override
  void initState() {
    super.initState();
    _loadCreators();
    _subscribeToSearchUpdates();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    final channel = _searchChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToSearchUpdates() {
    _searchChannel = Supabase.instance.client
        .channel('search-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) => _refreshLiveData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'artworks',
          callback: (_) => _refreshLiveData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (_) => _refreshLiveData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (_) => _refreshLiveData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'follows',
          callback: (_) => _refreshLiveData(),
        )
        .subscribe();
  }

  Future<void> _refreshLiveData() async {
    await _loadCreators(showLoading: false);
    if (_searchController.text.trim().isNotEmpty) {
      await _onSearchChanged();
    }
  }

  Future<void> _loadCreators({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final trendingData = await ProfileRepository().getTrendingCreators();
      final artworkRepository = ArtworkRepository();
      final trendingSearches = await artworkRepository.fetchTrendingTags();
      final trendingArtworks = await artworkRepository.fetchTrendingArtworks();
      // Remove self
      trendingData.removeWhere(
        (item) => (item['profile'] as ProfileModel).id == _currentUserId,
      );

      // Load following status for each creator
      for (final item in trendingData) {
        final creator = item['profile'] as ProfileModel;
        if (_currentUserId.isNotEmpty) {
          final isFollowing = await SocialRepository().isFollowing(
            _currentUserId,
            creator.id,
          );
          _followingMap[creator.id] = isFollowing;
        }
      }

      if (mounted) {
        setState(() {
          _trendingCreatorsData = trendingData;
          _creators = trendingData
              .map((item) => item['profile'] as ProfileModel)
              .toList();
          _trendingSearches = trendingSearches;
          _trendingArtworks = trendingArtworks;
        });
      }
    } catch (_) {}
    if (mounted && showLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _artworkSearchResults = [];
          _tagSearchResults = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    List<ProfileModel> creatorResults = [];
    try {
      creatorResults = await ProfileRepository().searchProfiles(query);
      creatorResults.removeWhere((c) => c.id == _currentUserId);
    } catch (e) {
      print('searchProfiles error: $e');
    }

    List<ArtworkModel> artworkResults = [];
    try {
      artworkResults = await ArtworkRepository().searchArtworks(query);
    } catch (e) {
      print('searchArtworks error: $e');
    }

    List<ArtworkModel> tagResults = [];
    try {
      tagResults = await ArtworkRepository().searchArtworksByTag(query);
    } catch (e) {
      print('searchArtworksByTag error: $e');
    }

    // Load following status for creators
    for (final creator in creatorResults) {
      if (_currentUserId.isNotEmpty && !_followingMap.containsKey(creator.id)) {
        try {
          final isFollowing = await SocialRepository().isFollowing(
            _currentUserId,
            creator.id,
          );
          _followingMap[creator.id] = isFollowing;
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = creatorResults;
        _artworkSearchResults = artworkResults;
        _tagSearchResults = tagResults;
      });
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    if (_currentUserId.isEmpty) return;
    final isFollowing = _followingMap[targetUserId] ?? false;

    setState(() {
      _followingMap[targetUserId] = !isFollowing;
    });

    try {
      if (isFollowing) {
        await SocialRepository().unfollowUser(_currentUserId, targetUserId);
      } else {
        await SocialRepository().followUser(_currentUserId, targetUserId);
      }
    } catch (_) {
      // Revert state on error
      if (mounted) {
        setState(() {
          _followingMap[targetUserId] = isFollowing;
        });
      }
    }
  }

  Widget _buildArtistsList(List<ProfileModel> profiles) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final creator = profiles[index];
        final isFollowing = _followingMap[creator.id] ?? false;

        // Try to find trending metrics
        final trendingItem = _trendingCreatorsData.firstWhere(
          (item) => (item['profile'] as ProfileModel).id == creator.id,
          orElse: () => <String, dynamic>{},
        );

        final likes = trendingItem['likes'] as int? ?? 0;
        final followers = trendingItem['followers'] as int? ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => context.push('/profile/${creator.id}'),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                // Avatar with border
                CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      creator.avatarUrl != null && creator.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(creator.avatarUrl!)
                      : null,
                  child: creator.avatarUrl == null || creator.avatarUrl!.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: AppColors.black,
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Name & Username & Metrics
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.displayName ?? creator.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${creator.username}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.black.withOpacity(0.5),
                        ),
                      ),
                      if (likes > 0 || followers > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.orange.shade700,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$likes likes • $followers followers',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Follow/Following button
                ElevatedButton(
                  onPressed: () => _toggleFollow(creator.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? AppColors.creamDark
                        : AppColors.black,
                    foregroundColor: isFollowing
                        ? AppColors.black
                        : AppColors.creamLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtworkGrid(List<ArtworkModel> artworks) {
    if (artworks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No artworks found',
            style: TextStyle(color: AppColors.darkGrey, fontSize: 14),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: artworks.length,
      itemBuilder: (context, index) {
        final artwork = artworks[index];
        return GestureDetector(
          onTap: () => context.push('/artwork/${artwork.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightGrey, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: artwork.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.creamDark),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artwork.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              artwork.authorUsername != null
                                  ? '@${artwork.authorUsername}'
                                  : 'user',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.black.withOpacity(0.5),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: AppColors.coral,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${artwork.likesCount}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingTags() {
    if (_trendingSearches.isEmpty) {
      return const Text(
        'No trending tags yet',
        style: TextStyle(color: AppColors.darkGrey, fontSize: 14),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _trendingSearches.map((tag) {
        return GestureDetector(
          onTap: () {
            _searchController.text = tag.replaceAll('#', '');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.lightGrey, width: 1),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildBrowseView() {
    switch (_selectedCategoryIndex) {
      case 0: // All
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Trending Searches'),
            const SizedBox(height: 12),
            _buildTrendingTags(),
            const SizedBox(height: 32),
            _buildSectionTitle('Trending Artists'),
            const SizedBox(height: 16),
            _buildArtistsList(_creators.take(5).toList()),
            const SizedBox(height: 24),
            _buildSectionTitle('Trending Artwork'),
            const SizedBox(height: 16),
            _buildArtworkGrid(_trendingArtworks.take(6).toList()),
          ],
        );
      case 1: // Artists
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Trending Artists'),
            const SizedBox(height: 16),
            _buildArtistsList(_creators),
          ],
        );
      case 2: // Artwork
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Trending Artwork'),
            const SizedBox(height: 16),
            _buildArtworkGrid(_trendingArtworks),
          ],
        );
      case 3: // Tags
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Trending Tags'),
            const SizedBox(height: 12),
            _buildTrendingTags(),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildSearchResultsView() {
    switch (_selectedCategoryIndex) {
      case 0: // All
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_searchResults.isNotEmpty) ...[
              const Text(
                'Artists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildArtistsList(_searchResults.take(3).toList()),
              const SizedBox(height: 24),
            ],
            if (_artworkSearchResults.isNotEmpty) ...[
              const Text(
                'Artworks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildArtworkGrid(_artworkSearchResults),
              const SizedBox(height: 24),
            ],
            if (_tagSearchResults.isNotEmpty) ...[
              const Text(
                'Matching Tags',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildArtworkGrid(_tagSearchResults),
            ],
            if (_searchResults.isEmpty &&
                _artworkSearchResults.isEmpty &&
                _tagSearchResults.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No results found',
                    style: TextStyle(color: AppColors.darkGrey, fontSize: 14),
                  ),
                ),
              ),
          ],
        );
      case 1: // Artists
        return _buildArtistsList(_searchResults);
      case 2: // Artwork
        return _buildArtworkGrid(_artworkSearchResults);
      case 3: // Tags
        return _buildArtworkGrid(_tagSearchResults);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Search Title
            const Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 20),
              child: Text(
                'Search',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Search input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.creamLight,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.lightGrey, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.darkGrey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search artists, artworks, or tags',
                          hintStyle: TextStyle(color: AppColors.darkGrey),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          filled: false,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.darkGrey,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

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

            // Scrollable Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isSearching) ...[
                            _buildSectionTitle('Search Results'),
                            const SizedBox(height: 16),
                            _buildSearchResultsView(),
                          ] else
                            _buildBrowseView(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }
}
