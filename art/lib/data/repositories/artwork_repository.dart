import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artwork_model.dart';
import '../models/comment_model.dart';

class ArtworkRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ArtworkModel>> fetchLatestArtworks() async {
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count)',
          )
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ArtworkModel>> fetchUserArtworks(String userId) async {
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

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
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count)',
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
    } else {
      await _client.from('likes').insert({
        'artwork_id': artworkId,
        'user_id': userId,
      });
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
            'artworks(*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count))',
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
    if (query.trim().isEmpty) return [];
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count)',
          )
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .limit(20);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ArtworkModel>> searchArtworksByTag(String tag) async {
    if (tag.trim().isEmpty) return [];
    try {
      final response = await _client
          .from('artworks')
          .select(
            '*, profiles:user_id(username, display_name, avatar_url), likes:likes(count), comments:comments(count)',
          )
          .overlaps('tags', [tag])
          .limit(20);

      return (response as List)
          .map((json) => ArtworkModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
