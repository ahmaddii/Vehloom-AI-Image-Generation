import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/story_model.dart';
import '../../../core/services/preferences_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final String initialUserId;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialUserId,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late Map<String, List<StoryModel>> _groupedStories;
  late List<String> _userIds;

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;

  Timer? _timer;
  Timer? _clockTimer; // ticks every 30s to refresh the timeago label
  double _percent = 0.0;
  bool _isPaused = false;
  late PageController _pageController;
  bool _goingBack = false;

  @override
  void initState() {
    super.initState();
    _groupStories();

    _currentUserIndex = _userIds.indexOf(widget.initialUserId);
    if (_currentUserIndex == -1) _currentUserIndex = 0;

    _pageController = PageController(initialPage: _currentUserIndex);

    _startStory();
    // Refresh the timestamp label every 30 seconds
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _groupStories() {
    _groupedStories = {};
    for (var story in widget.stories) {
      final uid = story.userId;
      if (!_groupedStories.containsKey(uid)) {
        _groupedStories[uid] = [];
      }
      _groupedStories[uid]!.add(story);
    }
    _userIds = _groupedStories.keys.toList();
  }

  List<StoryModel> get _currentStories =>
      _groupedStories[_userIds[_currentUserIndex]] ?? [];
  StoryModel get _currentStory => _currentStories[_currentStoryIndex];

  void _startStory() {
    _percent = 0.0;
    _isPaused = false;
    // Mark story as viewed as soon as it starts displaying, safely after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PreferencesService().markStoryViewed(_currentStory.userId, _currentStory.createdAt);
    });
    _resumeStory();
  }

  void _pauseStory() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeStory() {
    _timer?.cancel();
    setState(() {
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        if (_percent < 1.0) {
          _percent += 0.01;
        } else {
          _timer?.cancel();
          _nextStory();
        }
      });
    });
  }

  void _nextStory() {
    if (_currentStoryIndex < _currentStories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startStory();
    } else {
      if (_currentUserIndex < _userIds.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startStory();
    } else {
      if (_currentUserIndex > 0) {
        _goingBack = true;
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _startStory();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userIds.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        reverse: true, // Flips the swipe direction as requested
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentUserIndex = index;
            if (_goingBack) {
              _currentStoryIndex = _groupedStories[_userIds[index]]!.length - 1;
              _goingBack = false;
            } else {
              _currentStoryIndex = 0;
            }
          });
          _startStory();
        },
        itemCount: _userIds.length,
        itemBuilder: (context, pageIndex) {
          final isCurrentPage = pageIndex == _currentUserIndex;
          final userStories = _groupedStories[_userIds[pageIndex]]!;
          final storyIndex = isCurrentPage ? _currentStoryIndex : 0;
          final story = userStories[storyIndex];
          final user = story.profile;

          return GestureDetector(
            onTapDown: (details) {
              if (isCurrentPage) _pauseStory();
            },
            onTapUp: (details) {
              if (!isCurrentPage) return;
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 3) {
                _previousStory();
              } else {
                _nextStory();
              }
            },
            onLongPressEnd: (details) {
              if (isCurrentPage) _resumeStory();
            },
            onLongPressUp: () {
              if (isCurrentPage) _resumeStory();
            },
            onLongPressCancel: () {
              if (isCurrentPage) _resumeStory();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gallery photo story: blurred bg + full centered image (no crop)
                if (story.artworkId == null) ...[
                  // Blurred stretched background
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: story.mediaUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(color: Colors.black.withOpacity(0.35)),
                    ),
                  ),
                  // Actual image centered and fully visible
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: story.mediaUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.coral,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                ] else ...[
                  // Shared artwork story: blurred bg + rounded card
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: story.mediaUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: story.mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.coral,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.error, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (!_isPaused)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: List.generate(userStories.length, (
                              index,
                            ) {
                              double val = 0.0;
                              if (index < storyIndex) {
                                val = 1.0;
                              } else if (index == storyIndex) {
                                val = isCurrentPage ? _percent : 0.0;
                              }
                              return Expanded(
                                child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(76),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: val,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage:
                                    user?.avatarUrl != null &&
                                        user!.avatarUrl!.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        user.avatarUrl!,
                                      )
                                    : null,
                                child:
                                    user?.avatarUrl == null ||
                                        user!.avatarUrl!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ??
                                        user?.username ??
                                        'Anonymous',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    timeago.format(
                                      story.createdAt,
                                      allowFromNow: false,
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(153),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                if (story.artworkId != null && !_isPaused)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          _timer?.cancel();
                          context.push('/artwork/${story.artworkId}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(153),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withAlpha(76),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.palette_outlined,
                                color: AppColors.coral,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                story.artwork?.title != null
                                    ? 'View artwork: ${story.artwork!.title}'
                                    : 'View Artwork',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
