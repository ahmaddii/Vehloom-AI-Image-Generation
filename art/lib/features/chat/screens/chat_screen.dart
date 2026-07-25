import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../core/services/notification_service.dart';
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

  // NOTE: kept as a plain field (not rebuilt from the stream), but we no
  // longer mutate it from inside build(). See _mergeAndScheduleCleanup below.
  final List<MessageModel> _optimisticMessages = [];

  ProfileModel? _otherUserProfile;
  bool _isLoadingProfile = true;
  StreamSubscription<ProfileModel?>? _profileSub;

  // BUG FIX: previously nothing stopped a user from double-tapping send,
  // which could fire two network requests for the same text.
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = _currentUserId;
      if (userId != null) {
        _chatRepo.markRoomAsRead(widget.roomId, userId);
      }
    });

    NotificationService().currentActiveRoomId = widget.roomId;
  }

  void _loadProfile() {
    _profileSub = _profileRepo.getProfileStream(widget.otherUserId).listen((profile) {
      if (mounted) {
        setState(() {
          if (profile != null) {
            _otherUserProfile = profile;
          }
          _isLoadingProfile = false;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _isSending) return;

    _isSending = true;
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

    _scrollToBottom();

    try {
      await _chatRepo.sendMessage(
        widget.roomId,
        _currentUserId,
        text,
        id: messageId,
      );
      // PreferencesService().markRoomRead(widget.roomId); // Removed
      _updateOptimisticStatus(messageId, MessageStatus.sent);
    } catch (e) {
      _updateOptimisticStatus(messageId, MessageStatus.error);
    } finally {
      _isSending = false;
    }
  }

  void _updateOptimisticStatus(String id, MessageStatus status) {
    if (!mounted) return;
    setState(() {
      final index = _optimisticMessages.indexWhere((m) => m.id == id);
      if (index != -1) {
        _optimisticMessages[index] = _optimisticMessages[index].copyWith(
          status: status,
        );
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
      _updateOptimisticStatus(message.id, MessageStatus.sent);
    } catch (e) {
      _updateOptimisticStatus(message.id, MessageStatus.error);
    }
  }

  // BUG FIX: the old code removed items from `_optimisticMessages` directly
  // inside the StreamBuilder's `builder` callback. Mutating state during
  // build is unsafe (build should be a pure function of state) and could
  // cause messages to flicker or be skipped on the current frame. Instead we
  // compute a *filtered* list for rendering (no mutation) and, only if
  // something actually needs to be removed, schedule the real mutation for
  // after the frame is done.
  List<MessageModel> _mergeAndScheduleCleanup(
    List<MessageModel> streamMessages,
  ) {
    final streamIds = streamMessages.map((m) => m.id).toSet();
    final stillPending = _optimisticMessages
        .where((m) => !streamIds.contains(m.id))
        .toList();

    if (stillPending.length != _optimisticMessages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _optimisticMessages.removeWhere((m) => streamIds.contains(m.id));
        });
      });
    }

    final merged = [...stillPending, ...streamMessages];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Mark as read if we see unread messages from the other person
    final userId = _currentUserId;
    if (userId != null) {
      final hasUnreadFromOther = streamMessages.any(
        (m) => !m.isRead && m.senderId != userId,
      );
      if (hasUnreadFromOther) {
        _chatRepo.markRoomAsRead(widget.roomId, userId);
      }
    }

    return merged;
  }

  String _exactTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    // IMPORTANT: do NOT call PreferencesService().markRoomRead(...) directly
    // here. It calls notifyListeners() internally, and if anything in the
    // app (e.g. an unread-count badge) is listening via ListenableBuilder,
    // triggering that synchronously during dispose() throws:
    // "setState() or markNeedsBuild() called when widget tree was locked."
    // Deferring with a microtask lets it run after this frame's
    // build/dispose pass has fully unlocked.
    // Removed old PreferencesService read marking
    _profileSub?.cancel();
    NotificationService().currentActiveRoomId = null;
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
        toolbarHeight: 72,
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              backgroundColor: AppColors.creamDark,
              child: avatarUrl == null
                  ? Icon(Icons.person, size: 24, color: AppColors.lightGrey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_otherUserProfile?.isOnline == true) ...[
                        const PulsingCircle(color: Colors.green),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        const PulsingCircle(color: Colors.red),
                        Text(
                          'Offline',
                          style: TextStyle(
                            color: AppColors.lightGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: AppColors.black),
            onPressed: () {
              // TODO: implement more options
            },
          ),
        ],
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
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final streamMessages = snapshot.data ?? [];
                final allMessages = _mergeAndScheduleCleanup(streamMessages);

                if (allMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi 👋',
                      style: TextStyle(
                        color: AppColors.lightGrey,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // newest message at the bottom
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final msg = allMessages[index];
                    final isMe = msg.senderId == _currentUserId;

                    // Show a date divider above the oldest message of each
                    // day. Because the list is sorted newest -> oldest and
                    // rendered with reverse:true, "index + 1" is the
                    // chronologically-previous message.
                    final isFirstOfDay =
                        index == allMessages.length - 1 ||
                        !_isSameDay(
                          msg.timestamp,
                          allMessages[index + 1].timestamp,
                        );

                    final bubble = Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: isMe
                            ? [
                                _buildBubble(msg, isMe),
                                const SizedBox(width: 6),
                                _buildTimeAndStatus(msg, isMe),
                              ]
                            : [
                                _buildTimeAndStatus(msg, isMe),
                                const SizedBox(width: 6),
                                _buildBubble(msg, isMe),
                              ],
                      ),
                    );

                    if (!isFirstOfDay) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: bubble,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                _dateLabel(msg.timestamp),
                                style: TextStyle(
                                  color: AppColors.lightGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          bubble,
                        ],
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
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.lightGrey),
                        filled: true,
                        fillColor: AppColors.creamLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
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

  Widget _buildBubble(MessageModel msg, bool isMe) {
    return Container(
      key: ValueKey(msg.id),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.coral : AppColors.creamLight,
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: isMe
              ? const Radius.circular(4)
              : const Radius.circular(20),
          bottomLeft: isMe
              ? const Radius.circular(20)
              : const Radius.circular(4),
        ),
      ),
      child: Text(
        msg.content,
        style: TextStyle(
          color: isMe ? Colors.white : AppColors.black,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTimeAndStatus(MessageModel msg, bool isMe) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          _exactTime(msg.timestamp),
          style: TextStyle(color: AppColors.lightGrey, fontSize: 10),
        ),
        if (isMe) ...[
          const SizedBox(height: 2),
          if (msg.status == MessageStatus.sending)
            Icon(Icons.access_time, size: 12, color: AppColors.lightGrey)
          else if (msg.status == MessageStatus.error)
            GestureDetector(
              onTap: () => _retryMessage(msg),
              child: const Icon(Icons.error, size: 14, color: Colors.redAccent),
            )
          else
            Icon(
              Icons.done_all,
              size: 14,
              color: msg.isRead ? Colors.blue : AppColors.lightGrey,
            ),
        ],
      ],
    );
  }
}

class PulsingCircle extends StatefulWidget {
  final Color color;
  const PulsingCircle({super.key, required this.color});

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
