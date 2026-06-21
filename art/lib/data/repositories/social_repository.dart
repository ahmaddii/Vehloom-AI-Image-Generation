import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class SocialRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final response = await _client
          .from('followers')
          .select()
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _client.from('followers').insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
    } catch (_) {
      // Already following or invalid
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _client
          .from('followers')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } catch (_) {}
  }

  Future<List<ProfileModel>> fetchFollowers(String userId) async {
    try {
      // Select profiles of followers where following_id matches target userId
      final response = await _client
          .from('followers')
          .select('profiles:follower_id(*)')
          .eq('following_id', userId);

      return (response as List)
          .map((json) => ProfileModel.fromJson(json['profiles']))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProfileModel>> fetchFollowing(String userId) async {
    try {
      // Select profiles of users that target userId is following
      final response = await _client
          .from('followers')
          .select('profiles:following_id(*)')
          .eq('follower_id', userId);

      return (response as List)
          .map((json) => ProfileModel.fromJson(json['profiles']))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
