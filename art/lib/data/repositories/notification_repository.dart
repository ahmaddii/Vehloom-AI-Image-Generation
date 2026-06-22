import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select(
            '*, actor:actor_id(username, display_name, avatar_url), artworks:artwork_id(title, image_url)',
          )
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('fetchNotifications error: $e');
      return [];
    }
  }

  Future<int> fetchUnreadCount(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('fetchUnreadCount error: $e');
      return 0;
    }
  }

  Future<void> createFollowNotification({
    required String followerId,
    required String followingId,
  }) async {
    await _createNotification(
      recipientId: followingId,
      actorId: followerId,
      type: 'follow',
      replaceExisting: true,
    );
  }

  Future<void> createLikeNotification({
    required String artworkId,
    required String actorId,
  }) async {
    final recipientId = await _fetchArtworkOwnerId(artworkId);
    if (recipientId == null) return;

    await _createNotification(
      recipientId: recipientId,
      actorId: actorId,
      type: 'like',
      artworkId: artworkId,
      replaceExisting: true,
    );
  }

  Future<void> createCommentNotification({
    required String artworkId,
    required String actorId,
    required String commentId,
    required String commentContent,
  }) async {
    final recipientId = await _fetchArtworkOwnerId(artworkId);
    if (recipientId == null) return;

    await _createNotification(
      recipientId: recipientId,
      actorId: actorId,
      type: 'comment',
      artworkId: artworkId,
      commentId: commentId,
      commentContent: commentContent,
    );
  }

  Future<void> deleteFollowNotification({
    required String followerId,
    required String followingId,
  }) async {
    await _deleteNotification(
      recipientId: followingId,
      actorId: followerId,
      type: 'follow',
    );
  }

  Future<void> deleteLikeNotification({
    required String artworkId,
    required String actorId,
  }) async {
    final recipientId = await _fetchArtworkOwnerId(artworkId);
    if (recipientId == null) return;

    await _deleteNotification(
      recipientId: recipientId,
      actorId: actorId,
      type: 'like',
      artworkId: artworkId,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('markAllAsRead error: $e');
    }
  }

  Future<String?> _fetchArtworkOwnerId(String artworkId) async {
    try {
      final response = await _client
          .from('artworks')
          .select('user_id')
          .eq('id', artworkId)
          .maybeSingle();

      return response?['user_id'] as String?;
    } catch (e) {
      debugPrint('_fetchArtworkOwnerId error: $e');
      return null;
    }
  }

  Future<void> _createNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? artworkId,
    String? commentId,
    String? commentContent,
    bool replaceExisting = false,
  }) async {
    if (recipientId == actorId) return;

    try {
      if (replaceExisting) {
        await _deleteNotification(
          recipientId: recipientId,
          actorId: actorId,
          type: type,
          artworkId: artworkId,
        );
      }

      await _client.from('notifications').insert({
        'recipient_id': recipientId,
        'actor_id': actorId,
        'type': type,
        'artwork_id': artworkId,
        'comment_id': commentId,
        'comment_content': commentContent,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('_createNotification error: $e');
    }
  }

  Future<void> _deleteNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? artworkId,
  }) async {
    try {
      var query = _client
          .from('notifications')
          .delete()
          .eq('recipient_id', recipientId)
          .eq('actor_id', actorId)
          .eq('type', type);

      if (artworkId != null) {
        query = query.eq('artwork_id', artworkId);
      }

      await query;
    } catch (e) {
      debugPrint('_deleteNotification error: $e');
    }
  }
}
