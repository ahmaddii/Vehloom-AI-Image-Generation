import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  // FIX: keeps this screen's state (scroll position, loaded images) alive
  // even if it's inside a PageView/TabBarView/IndexedStack ancestor that
  // would otherwise rebuild it — this is the #1 cause of "scrolls down then
  // snaps back to top and reloads."
  @override
  bool get wantKeepAlive => true;

  final List<dynamic> _images = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  static const String _baseUrl = 'https://civitai.com/api/v1/images';

  String _currentSort = 'Most Reactions';
  String _currentPeriod = 'Day';

  void _randomizeFeed() {
    final sorts = ['Most Reactions', 'Most Comments', 'Newest'];
    final periods = ['Day', 'Week', 'Month', 'AllTime'];
    final random = Random();

    _currentSort = sorts[random.nextInt(sorts.length)];
    if (_currentSort != 'Newest') {
      _currentPeriod = periods[random.nextInt(periods.length)];
    }
  }

  @override
  void initState() {
    super.initState();
    _randomizeFeed();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadCachedImages();
    _fetchImages(isFirstLoad: true);
  }

  Future<void> _loadCachedImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_explore_images');
      if (cachedStr != null) {
        final List decoded = json.decode(cachedStr);
        if (mounted) {
          setState(() {
            _images.addAll(decoded);
            _isLoading = false;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // FIX: controller was never disposed before — leaked listeners across
    // navigation/hot-reload were a likely cause of the janky/broken scroll.
    _scrollController.dispose();
    super.dispose();
  }

  Uri _buildUri() {
    final params = <String, String>{
      'limit': '20',
      'sort': _currentSort,
      'nsfw': 'None', // keep it safe-for-work by default
    };
    if (_currentSort != 'Newest') {
      params['period'] = _currentPeriod;
    }
    if (_nextCursor != null) params['cursor'] = _nextCursor!;
    return Uri.parse(_baseUrl).replace(queryParameters: params);
  }

  Future<void> _fetchImages({bool isFirstLoad = false}) async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      if (isFirstLoad && _images.isEmpty) _isLoading = true;
      if (!isFirstLoad) _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(_buildUri())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = (data['items'] as List<dynamic>? ?? [])
            // Civitai's /images endpoint mixes in videos with no explicit
            // type flag in some cases — filter defensively so a video URL
            // doesn't get rendered as a broken image.
            .where(
              (item) =>
                  item['url'] != null &&
                  item['width'] != null &&
                  item['height'] != null,
            )
            .toList();

        final nextCursor = data['metadata']?['nextCursor'] as String?;

        setState(() {
          if (isFirstLoad) {
            _images.clear();
          }
          _images.addAll(items);
          _nextCursor = nextCursor;
          _hasMore = nextCursor != null && items.isNotEmpty;
          _isLoading = false;
          _isLoadingMore = false;
        });

        if (isFirstLoad && items.isNotEmpty) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('cached_explore_images', json.encode(items));
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Server error (${response.statusCode}). Pull to retry.';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Couldn\'t load art. Check your connection and retry.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _randomizeFeed();
    setState(() {
      _images.clear();
      _nextCursor = null;
      _hasMore = true;
    });
    await _fetchImages(isFirstLoad: true);
  }

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin — must be called every build.
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        title: const Text(
          'Inspiration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? _buildSkeletonGrid()
          : _errorMessage != null && _images.isEmpty
          ? _buildErrorState()
          : RefreshIndicator(
              color: AppColors.coral,
              onRefresh: _refresh,
              // FIX: NotificationListener is far more reliable than a raw
              // ScrollController.position listener for infinite scroll —
              // it doesn't fire dozens of times per frame during a fling,
              // which was likely the main cause of the scroll jank.
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 300 &&
                      !_isLoadingMore &&
                      _hasMore) {
                    _fetchImages();
                  }
                  return false;
                },
                child: MasonryGridView.count(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  itemCount: _images.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _images.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.coral,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    final img = _images[index];
                    final width = (img['width'] as num).toDouble();
                    final height = (img['height'] as num).toDouble();
                    final imageUrl = img['url'] as String;
                    final username = img['username'] as String? ?? 'unknown';

                    return GestureDetector(
                      // FIX: unique key per item so Flutter doesn't
                      // recycle/misalign masonry tiles as new pages load
                      // in — this was another likely source of visual
                      // "jump" during scroll.
                      key: ValueKey(img['id']),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenApiImageViewer(
                            imageUrl: imageUrl,
                            author: username,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          // FIX: locking the tile to its real aspect ratio
                          // up front (instead of only during the shimmer
                          // placeholder) stops layout height from
                          // recalculating after the image loads, which
                          // was causing the grid to jump under your thumb.
                          aspectRatio: width / height,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Shimmer.fromColors(
                                      baseColor: AppColors.creamDark,
                                      highlightColor: AppColors.creamLight,
                                      child: Container(color: Colors.white),
                                    ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Downloading...'),
                                        ),
                                      );
                                      final response = await http.get(
                                        Uri.parse(imageUrl),
                                      );
                                      final directory =
                                          await getTemporaryDirectory();
                                      final file = File(
                                        '${directory.path}/explore_img_${img['id']}.jpg',
                                      );
                                      await file.writeAsBytes(
                                        response.bodyBytes,
                                      );
                                      await Gal.putImage(file.path);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Saved to Gallery!'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to download'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.download,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/ai-art');
        },
        backgroundColor: AppColors.coral,
        child: Lottie.asset(
          'assets/lottie/AI Assistant.json',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
        tooltip: 'Generate AI Art',
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: 6,
        itemBuilder: (context, index) {
          final height = index % 2 == 0 ? 200.0 : 300.0;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Shimmer.fromColors(
              baseColor: AppColors.creamDark,
              highlightColor: AppColors.creamLight,
              child: Container(height: height, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenApiImageViewer extends StatefulWidget {
  final String imageUrl;
  final String author;
  const FullScreenApiImageViewer({
    super.key,
    required this.imageUrl,
    required this.author,
  });

  @override
  State<FullScreenApiImageViewer> createState() =>
      _FullScreenApiImageViewerState();
}

class _FullScreenApiImageViewerState extends State<FullScreenApiImageViewer> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final response = await http.get(Uri.parse(widget.imageUrl));
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/art_inspiration_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);

      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to Gallery!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: AppColors.coral),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'By ${widget.author}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
                FloatingActionButton.extended(
                  onPressed: _isDownloading ? null : _downloadImage,
                  backgroundColor: AppColors.coral,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    'Download',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
