import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artwork_model.dart';
import '../models/comment_model.dart';
import 'notification_repository.dart';

class ArtworkRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  Future<List<ArtworkModel>> fetchLatestArtworks({
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count)',
          )
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ArtworkModel>> fetchUserArtworks(
    String userId, {
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ArtworkModel?> getArtwork(String id) async {
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count)',
          )
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ArtworkModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadArtworkImage(File file, String userId) async {
    final fileExtension = file.path.split('.').last;
    final path =
        '$userId/art_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    // Upload image to 'artworks' bucket
    await _client.storage.from('artworks').upload(path, file);

    // Get public URL
    final imageUrl = _client.storage.from('artworks').getPublicUrl(path);
    return imageUrl;
  }

  Future<ArtworkModel> createArtwork({
    required String userId,
    required String title,
    String? description,
    required String imageUrl,
    List<String> tags = const [],
  }) async {
    final response = await _client
        .from('artworks')
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'tags': tags,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, profiles:user_id(username, display_name, avatar_url)')
        .single();

    return ArtworkModel.fromJson(response);
  }

  Future<bool> isLiked(String artworkId, String userId) async {
    try {
      final response = await _client
          .from('likes')
          .select()
          .eq('artwork_id', artworkId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleLike(String artworkId, String userId) async {
    final alreadyLiked = await isLiked(artworkId, userId);
    if (alreadyLiked) {
      await _client
          .from('likes')
          .delete()
          .eq('artwork_id', artworkId)
          .eq('user_id', userId);
      await _notificationRepository.deleteLikeNotification(
        artworkId: artworkId,
        actorId: userId,
      );
    } else {
      await _client.from('likes').insert({
        'artwork_id': artworkId,
        'user_id': userId,
      });
      await _notificationRepository.createLikeNotification(
        artworkId: artworkId,
        actorId: userId,
      );
    }
  }

  Future<List<CommentModel>> fetchComments(String artworkId) async {
    try {
      final response = await _client
          .from('comments')
          .select('*, profiles:user_id(username, display_name, avatar_url)')
          .eq('artwork_id', artworkId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => CommentModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<CommentModel> addComment({
    required String artworkId,
    required String userId,
    required String content,
  }) async {
    final response = await _client
        .from('comments')
        .insert({
          'artwork_id': artworkId,
          'user_id': userId,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, profiles:user_id(username, display_name, avatar_url)')
        .single();

    await _notificationRepository.createCommentNotification(
      artworkId: artworkId,
      actorId: userId,
      commentId: response['id'] as String,
      commentContent: content,
    );

    return CommentModel.fromJson(response);
  }

  Future<bool> isFavorited(String artworkId, String userId) async {
    try {
      final response = await _client
          .from('favorites')
          .select()
          .eq('artwork_id', artworkId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleFavorite(String artworkId, String userId) async {
    final alreadyFavorited = await isFavorited(artworkId, userId);
    if (alreadyFavorited) {
      await _client
          .from('favorites')
          .delete()
          .eq('artwork_id', artworkId)
          .eq('user_id', userId);
    } else {
      await _client.from('favorites').insert({
        'artwork_id': artworkId,
        'user_id': userId,
      });
    }
  }

  Future<List<ArtworkModel>> fetchUserFavorites(String userId) async {
    try {
      final response = await _client
          .from('favorites')
          .select(
            'artworks(*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final artworkJson = json['artworks'];
        return ArtworkModel.fromJson(artworkJson);
      }).toList();
    } catch (e) {
      print('fetchUserFavorites error: $e');
      return [];
    }
  }

  Future<List<ArtworkModel>> searchArtworks(String query) async {
    final cleanQuery = query.trim().replaceAll('#', '');
    if (cleanQuery.isEmpty) return [];
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count)',
          )
          .or('title.ilike.%$cleanQuery%,description.ilike.%$cleanQuery%')
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ArtworkModel>> searchArtworksByTag(String tag) async {
    final cleanTag = tag.trim().replaceAll('#', '').toLowerCase();
    if (cleanTag.isEmpty) return [];
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count)',
          )
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .where(
            (artwork) => artwork.tags.any(
              (item) => item.trim().toLowerCase().contains(cleanTag),
            ),
          )
          .take(20)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ArtworkModel>> fetchTrendingArtworks({int limit = 20}) async {
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count), favorites:favorites(count)',
          )
          .order('created_at', ascending: false)
          .limit(100);

      final artworks =
          (response as List).map((json) => ArtworkModel.fromJson(json)).toList()
            ..sort((a, b) {
              final aScore = (a.likesCount * 3) + a.commentsCount;
              final bScore = (b.likesCount * 3) + b.commentsCount;
              if (aScore == bScore) {
                return b.createdAt.compareTo(a.createdAt);
              }
              return bScore.compareTo(aScore);
            });

      return artworks.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchTrendingTags({int limit = 8}) async {
    try {
      final response = await _client
          .from('artworks')
          .select('tags, created_at, likes:likes(count)')
          .order('created_at', ascending: false)
          .limit(100);

      final Map<String, _TagTrend> tagTrends = {};
      for (final json in response as List) {
        final tags = List<String>.from(json['tags'] ?? []);
        final createdAt = DateTime.tryParse(
          json['created_at'] as String? ?? '',
        );
        int likes = 0;
        final likesData = json['likes'];
        if (likesData is List &&
            likesData.isNotEmpty &&
            likesData.first is Map &&
            likesData.first['count'] != null) {
          likes = likesData.first['count'] as int;
        }

        for (final tag in tags) {
          final cleanTag = tag.trim();
          if (cleanTag.isEmpty) continue;
          final key = cleanTag.toLowerCase();
          final trend = tagTrends.putIfAbsent(
            key,
            () => _TagTrend(label: cleanTag),
          );
          trend.count += 1;
          trend.likes += likes;
          if (createdAt != null &&
              (trend.latest == null || createdAt.isAfter(trend.latest!))) {
            trend.latest = createdAt;
          }
        }
      }

      final trends = tagTrends.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return trends.take(limit).map((trend) => '#${trend.label}').toList();
    } catch (_) {
      return [];
    }
  }
}

class _TagTrend {
  _TagTrend({required this.label});

  final String label;
  int count = 0;
  int likes = 0;
  DateTime? latest;

  int get score {
    final recencyBoost = latest == null
        ? 0
        : DateTime.now().difference(latest!).inDays <= 7
        ? 3
        : 0;
    return (count * 10) + likes + recencyBoost;
  }
}
