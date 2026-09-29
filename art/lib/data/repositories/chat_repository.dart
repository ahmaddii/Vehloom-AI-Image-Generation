import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// WhatsApp allows unsend within ~1 hour.
  static const deleteForEveryoneWindow = Duration(hours: 1);

  Future<ChatRoomModel> createOrGetChatRoom(String myUserId, String otherUserId) async {
    final sortedIds = [myUserId, otherUserId]..sort();
    final roomId = '${sortedIds[0]}_${sortedIds[1]}';

    final response = await _supabase
        .from('chatRooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();

    if (response != null) {
      return ChatRoomModel.fromMap(response, response['id'] as String);
    } else {
      final newRoom = ChatRoomModel(
        id: roomId,
        participants: [myUserId, otherUserId],
        lastUpdated: DateTime.now(),
      );
      await _supabase.from('chatRooms').insert(newRoom.toMap());
      return newRoom;
    }
  }

  Stream<List<ChatRoomModel>> getInbox(String myUserId) {
    return _supabase
        .from('chatRooms')
        .stream(primaryKey: ['id'])
        .map((data) {
      final rooms = data
          .where((room) {
            final participants = room['participants'] as List<dynamic>?;
            return participants?.contains(myUserId) ?? false;
          })
          .map((room) => ChatRoomModel.fromMap(room, room['id'] as String))
          .toList();

      rooms.sort((a, b) {
        if (a.lastUpdated == null && b.lastUpdated == null) return 0;
        if (a.lastUpdated == null) return 1;
        if (b.lastUpdated == null) return -1;
        return b.lastUpdated!.compareTo(a.lastUpdated!);
      });
      return rooms;
    });
  }

  Stream<List<MessageModel>> getMessages(
    String roomId, {
    required String currentUserId,
    int limit = 30,
  }) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('roomId', roomId)
        .order('timestamp', ascending: false)
        .limit(limit)
        .map((data) => data
            .map((msg) => MessageModel.fromMap(msg, msg['id'] as String))
            .where((msg) => !msg.isHiddenFor(currentUserId))
            .toList());
  }

  Stream<int> getUnreadCount(String roomId, String myUserId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('roomId', roomId)
        .map((messages) => messages
            .where((msg) =>
                msg['senderId'] != myUserId &&
                msg['isRead'] == false &&
                !_isHiddenForUser(msg, myUserId))
            .length);
  }

  bool _isHiddenForUser(Map<String, dynamic> msg, String userId) {
    if (msg['deletedForEveryone'] == true) return false;
    final deletedFor = msg['deletedFor'];
    if (deletedFor is List && deletedFor.contains(userId)) return true;
    return false;
  }

  Future<void> sendMessage(
    String roomId,
    String senderId,
    String text, {
    String? id,
    String? replyToId,
    String? replyToContent,
    String? imageUrl,
    String? sharedArtworkId,
    String? sharedProfileId,
  }) async {
    final messageId = id ?? const Uuid().v4();
    final now = DateTime.now();
    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      content: text,
      timestamp: now,
      replyToId: replyToId,
      replyToContent: replyToContent,
      imageUrl: imageUrl,
      sharedArtworkId: sharedArtworkId,
      sharedProfileId: sharedProfileId,
    );

    final msgMap = message.toMap();
    msgMap['roomId'] = roomId;

    await _supabase.from('messages').insert(msgMap);

    await _supabase.from('chatRooms').update({
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageRead': false,
      'lastUpdated': now.toIso8601String(),
    }).eq('id', roomId);
  }

  Future<void> upsertDeviceToken(String userId, String token) async {
    final Map<String, dynamic> data = {
      'user_id': userId,
      'token': token,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('device_tokens').upsert(
      data,
      onConflict: 'user_id, token',
    );
  }

  Future<void> removeDeviceToken(String token) async {
    await _supabase.from('device_tokens').delete().eq('token', token);
  }

  Future<void> markRoomAsRead(String roomId, String currentUserId) async {
    await _supabase
        .from('messages')
        .update({'isRead': true})
        .eq('roomId', roomId)
        .neq('senderId', currentUserId)
        .eq('isRead', false);

    await _supabase
        .from('chatRooms')
        .update({'lastMessageRead': true})
        .eq('id', roomId)
        .neq('lastMessageSenderId', currentUserId);
  }

  /// Hide a message only for the current user (WhatsApp "Delete for me").
  Future<void> deleteMessageForMe(String messageId, String userId) async {
    final response = await _supabase
        .from('messages')
        .select('deletedFor')
        .eq('id', messageId)
        .single();

    final current = response['deletedFor'];
    final deletedFor = current is List ? List<String>.from(current) : <String>[];
    if (!deletedFor.contains(userId)) {
      deletedFor.add(userId);
    }

    await _supabase.from('messages').update({'deletedFor': deletedFor}).eq('id', messageId);
  }

  /// Unsend for all participants (WhatsApp "Delete for everyone").
  Future<void> deleteMessageForEveryone(
    String messageId,
    String roomId,
    String senderId,
  ) async {
    final now = DateTime.now();
    await _supabase.from('messages').update({
      'deletedForEveryone': true,
      'deletedAt': now.toIso8601String(),
      'content': '',
      'imageUrl': null,
      'sharedArtworkId': null,
      'sharedProfileId': null,
      'replyToContent': null,
      'reactions': {},
    }).eq('id', messageId);

    await _refreshRoomPreview(roomId);
  }

  /// Legacy hard delete — kept for backwards compatibility.
  Future<void> deleteMessage(String messageId, {String? roomId}) async {
    await _supabase.from('messages').delete().eq('id', messageId);
    if (roomId != null) {
      await _refreshRoomPreview(roomId);
    }
  }

  Future<void> _refreshRoomPreview(String roomId) async {
    final latest = await _supabase
        .from('messages')
        .select('content, senderId, deletedForEveryone, timestamp')
        .eq('roomId', roomId)
        .order('timestamp', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latest == null) {
      await _supabase.from('chatRooms').update({
        'lastMessage': null,
        'lastMessageSenderId': null,
        'lastUpdated': DateTime.now().toIso8601String(),
      }).eq('id', roomId);
      return;
    }

    final preview = latest['deletedForEveryone'] == true
        ? 'This message was deleted'
        : (latest['content'] as String? ?? '');

    await _supabase.from('chatRooms').update({
      'lastMessage': preview,
      'lastMessageSenderId': latest['senderId'],
      'lastUpdated': DateTime.now().toIso8601String(),
    }).eq('id', roomId);
  }

  bool canDeleteForEveryone(MessageModel message) {
    if (message.senderId != _supabase.auth.currentUser?.id) return false;
    final age = DateTime.now().difference(message.timestamp);
    return age <= deleteForEveryoneWindow;
  }

  Future<String> uploadImage(File file, [String? userId]) async {
    final uid = userId ?? _supabase.auth.currentUser?.id ?? 'guest';
    final cleanExt = file.path.split('.').last.split('?').first.toLowerCase();
    final ext = cleanExt.isEmpty ? 'jpg' : cleanExt;
    final fileName = '${const Uuid().v4()}.$ext';
    final path = '$uid/chat_images/$fileName';

    final bytes = await file.readAsBytes();
    await _supabase.storage.from('artworks').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: 'image/$ext',
      ),
    );
    return _supabase.storage.from('artworks').getPublicUrl(path);
  }

  /// One reaction per user (WhatsApp/Messenger style).
  Future<void> toggleReaction(
    String messageId,
    String currentUserId,
    String reaction,
  ) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('reactions')
          .eq('id', messageId)
          .maybeSingle();

      if (response == null) return;

      final currentReactionsData = response['reactions'];
      Map<String, dynamic> rawReactions = {};
      if (currentReactionsData != null && currentReactionsData is Map) {
        rawReactions = Map<String, dynamic>.from(currentReactionsData);
      }

      var hadThisReaction = false;
      for (final entry in rawReactions.entries) {
        if (entry.key == reaction &&
            entry.value is List &&
            List<String>.from(entry.value).contains(currentUserId)) {
          hadThisReaction = true;
          break;
        }
      }

      // Remove user from every reaction (one reaction per user).
      for (final key in rawReactions.keys.toList()) {
        final list = rawReactions[key];
        if (list is List) {
          final users = List<String>.from(list);
          users.remove(currentUserId);
          if (users.isEmpty) {
            rawReactions.remove(key);
          } else {
            rawReactions[key] = users;
          }
        }
      }

      if (!hadThisReaction) {
        final users = <String>[currentUserId];
        rawReactions[reaction] = users;
      }

      await _supabase
          .from('messages')
          .update({'reactions': rawReactions})
          .eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }
}
