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

  Stream<ProfileModel?> getProfileStream(String id) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((maps) {
          if (maps.isEmpty) return null;
          return ProfileModel.fromJson(maps.first);
        });
  }

  Future<void> updatePresence(String userId, bool isOnline) async {
    try {
      await _client.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
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
    final cleanQuery = query.trim().replaceAll('#', '');
    if (cleanQuery.isEmpty) return [];
    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$cleanQuery%,display_name.ilike.%$cleanQuery%')
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
      final response = await _client.from('profiles').select().limit(15);
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
    final path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    // Upload image to 'avatars' bucket
    await _client.storage.from('avatars').upload(path, file);

    // Get public URL
    final imageUrl = _client.storage.from('avatars').getPublicUrl(path);
    return imageUrl;
  }

  Future<List<Map<String, dynamic>>> getTrendingCreators() async {
    try {
      // 1. Fetch profiles
      final profilesResponse = await _client
          .from('profiles')
          .select()
          .limit(50);
      final List<ProfileModel> profiles = (profilesResponse as List)
          .map((json) => ProfileModel.fromJson(json))
          .toList();

      // 2. Fetch all artworks to compute likes
      final artworksResponse = await _client
          .from('artworks')
          .select('user_id, likes:likes(count)');

      // Calculate total likes per user
      final Map<String, int> userLikes = {};
      for (final art in artworksResponse) {
        final userId = art['user_id'] as String;
        int likes = 0;
        if (art['likes'] is List) {
          final list = art['likes'] as List;
          if (list.isNotEmpty &&
              list.first is Map &&
              list.first['count'] != null) {
            likes = list.first['count'] as int;
          } else {
            likes = list.length;
          }
        }
        userLikes[userId] = (userLikes[userId] ?? 0) + likes;
      }

      // 3. Fetch all follows to compute followers
      final followsResponse = await _client
          .from('follows')
          .select('following_id');
      final Map<String, int> userFollowers = {};
      for (final follow in followsResponse) {
        final followingId = follow['following_id'] as String;
        userFollowers[followingId] = (userFollowers[followingId] ?? 0) + 1;
      }

      // 4. Compute score for each profile
      final List<Map<String, dynamic>> trending = [];
      for (final profile in profiles) {
        final likes = userLikes[profile.id] ?? 0;
        final followers = userFollowers[profile.id] ?? 0;
        final score =
            likes + (followers * 5); // weight followers slightly higher
        trending.add({
          'profile': profile,
          'likes': likes,
          'followers': followers,
          'score': score,
        });
      }

      // Sort by score descending
      trending.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      return trending;
    } catch (e) {
      print('getTrendingCreators error: $e');
      return [];
    }
  }

  Future<void> blockUser(String blockerId, String blockedId) async {
    try {
      await _client.from('blocks').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      // Also remove follows if any exist between them
      await _client.from('follows').delete().eq('follower_id', blockerId).eq('following_id', blockedId);
      await _client.from('follows').delete().eq('follower_id', blockedId).eq('following_id', blockerId);
    } catch (_) {}
  }

  Future<void> unblockUser(String blockerId, String blockedId) async {
    try {
      await _client.from('blocks').delete().eq('blocker_id', blockerId).eq('blocked_id', blockedId);
    } catch (_) {}
  }

  Future<bool> isBlocked(String currentUserId, String targetUserId) async {
    if (currentUserId.isEmpty || targetUserId.isEmpty) return false;
    try {
      final res = await _client
          .from('blocks')
          .select()
          .or('and(blocker_id.eq.$currentUserId,blocked_id.eq.$targetUserId),and(blocker_id.eq.$targetUserId,blocked_id.eq.$currentUserId)')
          .limit(1);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getBlockedUserIds(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final blocked = await _client.from('blocks').select('blocked_id').eq('blocker_id', userId);
      final blockers = await _client.from('blocks').select('blocker_id').eq('blocked_id', userId);
      
      final Set<String> blockedIds = {};
      for (var b in blocked) blockedIds.add(b['blocked_id'] as String);
      for (var b in blockers) blockedIds.add(b['blocker_id'] as String);
      
      return blockedIds.toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProfileModel>> fetchBlockedProfiles(String currentUserId) async {
    try {
      final res = await _client.from('blocks').select('blocked_id').eq('blocker_id', currentUserId);
      if (res.isEmpty) return [];
      
      final ids = (res as List).map((e) => e['blocked_id'] as String).toList();
      final profilesRes = await _client.from('profiles').select().inFilter('id', ids);
      
      return (profilesRes as List).map((p) => ProfileModel.fromJson(p)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProfileModel>> getFollowing(String userId) async {
    try {
      final res = await _client.from('follows').select('following_id').eq('follower_id', userId);
      if (res.isEmpty) return [];
      
      final ids = (res as List).map((e) => e['following_id'] as String).toList();
      final profilesRes = await _client.from('profiles').select().inFilter('id', ids);
      
      return (profilesRes as List).map((p) => ProfileModel.fromJson(p)).toList();
    } catch (_) {
      return [];
    }
  }
}
