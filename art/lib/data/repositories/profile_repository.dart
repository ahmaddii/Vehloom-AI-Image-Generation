import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ProfileModel?> getProfile(String id) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<ProfileModel?> getProfileByUsername(String username) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .ilike('username', username)
          .maybeSingle();
      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<List<ProfileModel>> searchProfiles(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);
      
      return (response as List)
          .map((json) => ProfileModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProfileModel>> getCreators() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .limit(15);
      return (response as List)
          .map((json) => ProfileModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateProfile({
    required String id,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', id);
    }
  }

  Future<String> uploadAvatar(File file, String userId) async {
    final fileExtension = file.path.split('.').last;
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    
    // Upload image to 'avatars' bucket
    await _client.storage.from('avatars').upload(path, file);
    
    // Get public URL
    final imageUrl = _client.storage.from('avatars').getPublicUrl(path);
    return imageUrl;
  }
}
