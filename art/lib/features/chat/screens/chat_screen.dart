import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../core/services/preferences_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatRepo = ChatRepository();
  final _profileRepo = ProfileRepository();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _optimisticMessages = [];

  ProfileModel? _otherUserProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PreferencesService().markRoomRead(widget.roomId);
    });
  }

  Future<void> _loadProfile() async {
    final profile = await _profileRepo.getProfile(widget.otherUserId);
    if (mounted) {
      setState(() {
        _otherUserProfile = profile;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();

    final messageId = const Uuid().v4();
    final optimisticMsg = MessageModel(
      id: messageId,
      senderId: _currentUserId,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _optimisticMessages.insert(0, optimisticMsg);
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    try {
      await _chatRepo.sendMessage(
        widget.roomId,
        _currentUserId,
        text,
        id: messageId,
      );
      PreferencesService().markRoomRead(widget.roomId);
      if (mounted) {
        setState(() {
          final index = _optimisticMessages.indexWhere(
            (m) => m.id == messageId,
          );
          if (index != -1) {
            _optimisticMessages[index] = _optimisticMessages[index].copyWith(
              status: MessageStatus.sent,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _optimisticMessages.indexWhere(
            (m) => m.id == messageId,
          );
          if (index != -1) {
            _optimisticMessages[index] = _optimisticMessages[index].copyWith(
              status: MessageStatus.error,
            );
          }
        });
      }
    }
  }

  void _retryMessage(MessageModel message) {
    setState(() {
      final index = _optimisticMessages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _optimisticMessages[index] = _optimisticMessages[index].copyWith(
          status: MessageStatus.sending,
        );
      }
    });
    _retrySendMessageAsync(message);
  }

  Future<void> _retrySendMessageAsync(MessageModel message) async {
    try {
      await _chatRepo.sendMessage(
        widget.roomId,
        message.senderId,
        message.content,
        id: message.id,
      );
      if (mounted) {
        setState(() {
          final index = _optimisticMessages.indexWhere(
            (m) => m.id == message.id,
          );
          if (index != -1) {
            _optimisticMessages[index] = _optimisticMessages[index].copyWith(
              status: MessageStatus.sent,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _optimisticMessages.indexWhere(
            (m) => m.id == message.id,
          );
          if (index != -1) {
            _optimisticMessages[index] = _optimisticMessages[index].copyWith(
              status: MessageStatus.error,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    final roomId = widget.roomId;
    Future.microtask(() {
      PreferencesService().markRoomRead(roomId);
    });
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final displayName = _otherUserProfile?.displayName ?? 'Chat';
    final avatarUrl = _otherUserProfile?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
        titleSpacing: 0,
        title: Row(
          children: [
            if (_isLoadingProfile)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: AppColors.creamDark,
                child: avatarUrl == null
                    ? Icon(Icons.person, size: 18, color: AppColors.lightGrey)
                    : null,
              ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: AppColors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_otherUserProfile?.isOnline == true)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: AppColors.lightGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Offline',
                    style: TextStyle(color: AppColors.lightGrey, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatRepo.getMessages(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  );
                }

                final streamMessages = snapshot.data ?? [];

                final streamIds = streamMessages.map((m) => m.id).toSet();
                _optimisticMessages.removeWhere(
                  (m) => streamIds.contains(m.id),
                );

                final allMessages = [..._optimisticMessages, ...streamMessages];

                allMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Show newest at the bottom
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final msg = allMessages[index];
                    final isMe = msg.senderId == _currentUserId;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.coral : AppColors.creamLight,
                          borderRadius: BorderRadius.circular(24).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(4)
                                : const Radius.circular(24),
                            bottomLeft: isMe
                                ? const Radius.circular(24)
                                : const Radius.circular(4),
                          ),
                          // Flat design without shadow
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.content,
                              style: TextStyle(
                                color: isMe ? Colors.white : AppColors.black,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeago.format(
                                    msg.timestamp,
                                    locale: 'en_short',
                                  ),
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : AppColors.lightGrey,
                                    fontSize: 10,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  if (msg.status == MessageStatus.sending)
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    )
                                  else if (msg.status == MessageStatus.error)
                                    GestureDetector(
                                      onTap: () => _retryMessage(msg),
                                      child: const Icon(
                                        Icons.error,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Chat Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.creamBg,
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.creamLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.creamDark,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: TextStyle(
                                  color: AppColors.lightGrey,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: AppColors.coral,
                              size: 24,
                            ),
                            onPressed: _sendMessage,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
