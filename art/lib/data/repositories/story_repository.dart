import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/story_model.dart';

class StoryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadStoryImage(File file, String userId) async {
    final fileExtension = file.path.split('.').last;
    final path =
        '$userId/story_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    // Upload image to 'artworks' bucket to reuse existing public storage
    await _client.storage.from('artworks').upload(path, file);

    // Get public URL
    final imageUrl = _client.storage.from('artworks').getPublicUrl(path);
    return imageUrl;
  }

  Future<StoryModel> createStory({
    required String userId,
    String? artworkId,
    required String mediaUrl,
  }) async {
    final expiresAt = DateTime.now().add(const Duration(hours: 24));
    
    final response = await _client
        .from('stories')
        .insert({
          'user_id': userId,
          'artwork_id': artworkId,
          'media_url': mediaUrl,
          'created_at': DateTime.now().toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        })
        .select('*, profiles:user_id(*), artworks:artwork_id(*, profiles:user_id(*))')
        .single();

    return StoryModel.fromJson(response);
  }

  Future<List<StoryModel>> fetchActiveStories() async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final response = await _client
          .from('stories')
          .select('*, profiles:user_id(*), artworks:artwork_id(*, profiles:user_id(*))')
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => StoryModel.fromJson(json))
          .toList();
    } catch (e) {
      print('fetchActiveStories error: $e');
      return [];
    }
  }
}
