import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final List<String> _categories = ['All', 'Artists', 'Artwork', 'Tags'];
  int _selectedCategoryIndex = 0;

  final List<String> _trendingSearches = [
    '#PortraitAI',
    '#NeonDreams',
    '#SurrealScapes',
    '#DigitalPainting',
    '#AbstractAI',
  ];

  final TextEditingController _searchController = TextEditingController();
  List<ProfileModel> _creators = [];
  List<ProfileModel> _searchResults = [];
  Map<String, bool> _followingMap = {};
  bool _isSearching = false;
  bool _isLoading = true;
  final String _currentUserId = AuthRepository().currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadCreators();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreators() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final creators = await ProfileRepository().getCreators();
      // Remove self from discover creators
      creators.removeWhere((c) => c.id == _currentUserId);
      
      // Load following status for each creator
      for (final creator in creators) {
        if (_currentUserId.isNotEmpty) {
          final isFollowing = await SocialRepository().isFollowing(_currentUserId, creator.id);
          _followingMap[creator.id] = isFollowing;
        }
      }

      if (mounted) {
        setState(() {
          _creators = creators;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      final results = await ProfileRepository().searchProfiles(query);
      // Remove self from results
      results.removeWhere((c) => c.id == _currentUserId);

      // Load following status for search results
      for (final creator in results) {
        if (_currentUserId.isNotEmpty && !_followingMap.containsKey(creator.id)) {
          final isFollowing = await SocialRepository().isFollowing(_currentUserId, creator.id);
          _followingMap[creator.id] = isFollowing;
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final displayCreators = _isSearching ? _searchResults : _creators;

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
                          hintText: 'Search artists or username',
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
                        icon: const Icon(Icons.clear, color: AppColors.darkGrey, size: 18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.black : AppColors.creamLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.black : AppColors.lightGrey,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? AppColors.creamLight : AppColors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isSearching) ...[
                            // Trending Searches Section
                            const Text(
                              'Trending Searches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
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
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Section Title
                          Text(
                            _isSearching ? 'Search Results' : 'Discover Creators',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Creators list
                          displayCreators.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Text(
                                      'No profiles found',
                                      style: TextStyle(color: AppColors.darkGrey, fontSize: 14),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: displayCreators.length,
                                  itemBuilder: (context, index) {
                                    final creator = displayCreators[index];
                                    final isFollowing = _followingMap[creator.id] ?? false;
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
                                              backgroundImage: creator.avatarUrl != null && creator.avatarUrl!.isNotEmpty
                                                  ? CachedNetworkImageProvider(creator.avatarUrl!)
                                                  : null,
                                              child: creator.avatarUrl == null || creator.avatarUrl!.isEmpty
                                                  ? const Icon(Icons.person, color: AppColors.black, size: 24)
                                                  : null,
                                            ),
                                            const SizedBox(width: 16),

                                            // Name & Username
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
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                                ),
                        ],
                      ),
                    ),
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
                icon: const Icon(Icons.search, color: AppColors.coral),
                onPressed: () {},
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
                icon: const Icon(Icons.emoji_events_outlined, color: AppColors.black),
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
