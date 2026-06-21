import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class SocialRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final response = await _client
          .from('follows')
          .select()
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('isFollowing error: $e');
      return false;
    }
  }

  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _client.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
    } catch (e) {
      print('followUser error: $e');
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } catch (e) {
      print('unfollowUser error: $e');
    }
  }

  Future<List<ProfileModel>> fetchFollowers(String userId) async {
    try {
      // Query the 'follows' table and join with 'profiles' on 'follower_id'
      final response = await _client
          .from('follows')
          .select('profiles!follower_id(*)')
          .eq('following_id', userId);

      return (response as List)
          .map((json) {
            final profileJson = json['profiles'];
            return ProfileModel.fromJson(profileJson);
          })
          .toList();
    } catch (e) {
      print('fetchFollowers error: $e');
      return [];
    }
  }

  Future<List<ProfileModel>> fetchFollowing(String userId) async {
    try {
      // Query the 'follows' table and join with 'profiles' on 'following_id'
      final response = await _client
          .from('follows')
          .select('profiles!following_id(*)')
          .eq('follower_id', userId);

      return (response as List)
          .map((json) {
            final profileJson = json['profiles'];
            return ProfileModel.fromJson(profileJson);
          })
          .toList();
    } catch (e) {
      print('fetchFollowing error: $e');
      return [];
    }
  }
}
