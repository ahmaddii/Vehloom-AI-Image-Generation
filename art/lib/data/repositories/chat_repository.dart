import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ChatRoomModel> createOrGetChatRoom(String myUserId, String otherUserId) async {
    // Generate a consistent ID based on user IDs
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
      
      // Sort by lastUpdated descending locally
      rooms.sort((a, b) {
        if (a.lastUpdated == null && b.lastUpdated == null) return 0;
        if (a.lastUpdated == null) return 1;
        if (b.lastUpdated == null) return -1;
        return b.lastUpdated!.compareTo(a.lastUpdated!);
      });
      return rooms;
    });
  }

  Stream<List<MessageModel>> getMessages(String roomId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('roomId', roomId)
        .order('timestamp', ascending: false)
        .map((data) => data
            .map((msg) => MessageModel.fromMap(msg, msg['id'] as String))
            .toList());
  }

  Future<void> sendMessage(String roomId, String senderId, String text, {String? id}) async {
    final messageId = id ?? const Uuid().v4();
    final now = DateTime.now();
    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      content: text,
      timestamp: now,
    );
    
    // Add message
    final msgMap = message.toMap();
    msgMap['roomId'] = roomId; // Ensure roomId is attached to the message row
    
    await _supabase.from('messages').insert(msgMap);

    // Update room
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
    // 1. Mark unread messages sent to me in this room as read
    await _supabase
        .from('messages')
        .update({'isRead': true})
        .eq('roomId', roomId)
        .neq('senderId', currentUserId)
        .eq('isRead', false);

    // 2. Mark the room's last message as read if it was sent by the other person
    await _supabase
        .from('chatRooms')
        .update({'lastMessageRead': true})
        .eq('id', roomId)
        .neq('lastMessageSenderId', currentUserId);
  }
}
