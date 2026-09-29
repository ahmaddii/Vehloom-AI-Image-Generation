import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/repositories/artwork_repository.dart';
import '../widgets/chat_emoji_picker.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_messages_skeleton.dart';

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
  final _artworkRepo = ArtworkRepository();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // NOTE: kept as a plain field (not rebuilt from the stream), but we no
  // longer mutate it from inside build(). See _mergeAndScheduleCleanup below.
  final List<MessageModel> _optimisticMessages = [];

  ProfileModel? _otherUserProfile;
  StreamSubscription<ProfileModel?>? _profileSub;

  // BUG FIX: previously nothing stopped a user from double-tapping send,
  // which could fire two network requests for the same text.
  bool _isSending = false;

  MessageModel? _replyingTo;

  int _messageLimit = 30;
  RealtimeChannel? _typingChannel;
  bool _isMeTyping = false;
  bool _otherUserIsTyping = false;
  Timer? _typingTimer;
  Timer? _otherUserTypingTimer;
  Timer? _readMarkTimer;
  bool _isLoadingMore = false;

  final Map<String, Map<String, List<String>>> _localReactions = {};
  final Map<String, ArtworkModel?> _artworkCache = {};
  final Map<String, ProfileModel?> _profileCache = {};
  final Set<String> _prefetchInFlight = {};

  void _onToggleReaction(MessageModel message, String emoji) {
    final userId = _currentUserId;
    if (userId == null) return;

    final messageId = message.id;
    Map<String, List<String>> currentReactions = {};

    if (_localReactions.containsKey(messageId)) {
      currentReactions = Map<String, List<String>>.from(
        _localReactions[messageId]!.map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        ),
      );
    } else if (message.reactions.isNotEmpty) {
      currentReactions = Map<String, List<String>>.from(
        message.reactions.map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        ),
      );
    }

    final hadThisReaction = currentReactions.containsKey(emoji) &&
        currentReactions[emoji]!.contains(userId);

    // One reaction per user: remove user from all reaction keys first
    for (final key in currentReactions.keys.toList()) {
      currentReactions[key]!.remove(userId);
      if (currentReactions[key]!.isEmpty) {
        currentReactions.remove(key);
      }
    }

    if (!hadThisReaction) {
      currentReactions.putIfAbsent(emoji, () => []).add(userId);
    }

    setState(() {
      _localReactions[messageId] = currentReactions;

      final optIdx = _optimisticMessages.indexWhere((m) => m.id == messageId);
      if (optIdx != -1) {
        _optimisticMessages[optIdx] = _optimisticMessages[optIdx].copyWith(
          reactions: currentReactions,
        );
      }
    });

    _chatRepo.toggleReaction(messageId, userId, emoji).then((_) {
      if (mounted) {
        setState(() {
          _localReactions.remove(messageId);
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _localReactions.remove(messageId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reaction failed: $e',
            ),
          ),
        );
      }
    });
  }

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

    _setupTypingChannel();

    _scrollController.addListener(() {
      if (_isLoadingMore) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _isLoadingMore = true;
        setState(() {
          _messageLimit += 30;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _isLoadingMore = false;
        });
      }
    });
  }

  void _setupTypingChannel() {
    _typingChannel = Supabase.instance.client.channel(
      'typing_${widget.roomId}',
    );
    _typingChannel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['userId'];
            final isTyping = payload['isTyping'] as bool? ?? false;

            if (userId != _currentUserId && mounted) {
              _otherUserTypingTimer?.cancel();
              setState(() {
                _otherUserIsTyping = isTyping;
              });

              if (isTyping) {
                _otherUserTypingTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted && _otherUserIsTyping) {
                    setState(() {
                      _otherUserIsTyping = false;
                    });
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  void _onMessageChanged(String text) {
    if (!_isMeTyping) {
      _isMeTyping = true;
      _typingChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {'userId': _currentUserId, 'isTyping': true},
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _isMeTyping = false;
      _typingChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {'userId': _currentUserId, 'isTyping': false},
      );
    });
  }

  void _loadProfile() {
    _profileSub = _profileRepo.getProfileStream(widget.otherUserId).listen((
      profile,
    ) {
      if (mounted) {
        setState(() {
          if (profile != null) {
            _otherUserProfile = profile;
          }
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _isSending) return;

    _isSending = true;
    _messageController.clear();

    final replyId = _replyingTo?.id;
    final replyContent = _replyingTo?.content;

    setState(() {
      _replyingTo = null;
    });

    final messageId = const Uuid().v4();
    final optimisticMsg = MessageModel(
      id: messageId,
      senderId: _currentUserId,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      replyToId: replyId,
      replyToContent: replyContent,
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
        replyToId: replyId,
        replyToContent: replyContent,
      );
      // PreferencesService().markRoomRead(widget.roomId); // Removed
      _updateOptimisticStatus(messageId, MessageStatus.sent);
    } catch (e) {
      _updateOptimisticStatus(messageId, MessageStatus.error);
    } finally {
      _isSending = false;
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_currentUserId == null || _isSending) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.coral.withValues(alpha: 0.1),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.coral),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.coral.withValues(alpha: 0.1),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.coral),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() {
      _isSending = true;
    });

    final messageId = const Uuid().v4();
    final optimisticMsg = MessageModel(
      id: messageId,
      senderId: _currentUserId,
      content: 'Sent an image',
      imageUrl: pickedFile.path,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _optimisticMessages.insert(0, optimisticMsg);
    });

    _scrollToBottom();

    try {
      final file = File(pickedFile.path);
      final imageUrl = await _chatRepo.uploadImage(file, _currentUserId);
      await _chatRepo.sendMessage(
        widget.roomId,
        _currentUserId,
        'Sent an image',
        id: messageId,
        imageUrl: imageUrl,
      );
      _updateOptimisticStatus(messageId, MessageStatus.sent);
    } catch (e) {
      _updateOptimisticStatus(messageId, MessageStatus.error);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
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
    if (message.imageUrl != null || message.content == 'Sent an image') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select and send the image again.'),
        ),
      );
      return;
    }

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
        replyToId: message.replyToId,
        replyToContent: message.replyToContent,
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
        _readMarkTimer?.cancel();
        _readMarkTimer = Timer(const Duration(milliseconds: 400), () {
          _chatRepo.markRoomAsRead(widget.roomId, userId);
        });
      }
    }

    return merged;
  }

  void _prefetchSharedContent(List<MessageModel> messages) {
    for (final msg in messages) {
      final artworkId = msg.sharedArtworkId;
      if (artworkId != null &&
          !_artworkCache.containsKey(artworkId) &&
          !_prefetchInFlight.contains('artwork:$artworkId')) {
        _prefetchInFlight.add('artwork:$artworkId');
        _artworkRepo
            .getArtwork(artworkId)
            .then((artwork) {
              if (mounted) {
                setState(() => _artworkCache[artworkId] = artwork);
              }
            })
            .whenComplete(() => _prefetchInFlight.remove('artwork:$artworkId'));
      }

      final profileId = msg.sharedProfileId;
      if (profileId != null &&
          !_profileCache.containsKey(profileId) &&
          !_prefetchInFlight.contains('profile:$profileId')) {
        _prefetchInFlight.add('profile:$profileId');
        _profileRepo
            .getProfile(profileId)
            .then((profile) {
              if (mounted) {
                setState(() => _profileCache[profileId] = profile);
              }
            })
            .whenComplete(() => _prefetchInFlight.remove('profile:$profileId'));
      }
    }
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

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;

    final time = _exactTime(date);
    if (diff == 0) return 'Last seen today at $time';
    if (diff == 1) return 'Last seen yesterday at $time';

    return 'Last seen ${_dateLabel(date)}';
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
    _typingTimer?.cancel();
    _otherUserTypingTimer?.cancel();
    _readMarkTimer?.cancel();
    _typingChannel?.unsubscribe();
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

    final rawName = _otherUserProfile?.displayName ?? _otherUserProfile?.username;
    final displayName = rawName != null ? '@$rawName' : 'Chat';
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
                  ? CachedNetworkImageProvider(avatarUrl)
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
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ] else ...[
                        const PulsingCircle(color: Colors.red),
                        Text(
                          _otherUserProfile?.lastSeen != null
                              ? _formatLastSeen(_otherUserProfile!.lastSeen!)
                              : 'Offline',
                          style: TextStyle(
                            color: AppColors.lightGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_otherUserIsTyping)
                    const Text(
                      'Typing...',
                      style: TextStyle(
                        color: AppColors.coral,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
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
              stream: _chatRepo.getMessages(
                widget.roomId,
                currentUserId: _currentUserId,
                limit: _messageLimit,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const ChatMessagesSkeleton();
                }

                final streamMessages = snapshot.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _prefetchSharedContent(streamMessages);
                });
                final allMessages = _mergeAndScheduleCleanup(streamMessages);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // newest message at the bottom
                  cacheExtent: 400,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: allMessages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == allMessages.length) {
                      return _buildProfileHeader();
                    }
                    final rawMsg = allMessages[index];
                    final msg = _localReactions.containsKey(rawMsg.id)
                        ? rawMsg.copyWith(reactions: _localReactions[rawMsg.id]!)
                        : rawMsg;
                    final isMe = msg.senderId == _currentUserId;

                    // Message list is reverse:true, so allMessages[index] is rendered
                    // bottom-to-top. To check if a date header is needed above this
                    // message (chronologically before), we compare against
                    // allMessages[index + 1]. Since the list is sorted desc and
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
                                MessageBubble(
                                  msg: msg,
                                  isMe: isMe,
                                  currentUserId: _currentUserId,
                                  cachedArtwork: msg.sharedArtworkId != null
                                      ? _artworkCache[msg.sharedArtworkId]
                                      : null,
                                  cachedProfile: msg.sharedProfileId != null
                                      ? _profileCache[msg.sharedProfileId]
                                      : null,
                                  onLongPress: () =>
                                      _showMessageActions(msg, isMe),
                                  onReactionTap: (emoji) =>
                                      _onToggleReaction(msg, emoji),
                                ),
                                const SizedBox(width: 6),
                                _buildTimeAndStatus(msg, isMe),
                              ]
                            : [
                                _buildTimeAndStatus(msg, isMe),
                                const SizedBox(width: 6),
                                MessageBubble(
                                  msg: msg,
                                  isMe: isMe,
                                  currentUserId: _currentUserId,
                                  cachedArtwork: msg.sharedArtworkId != null
                                      ? _artworkCache[msg.sharedArtworkId]
                                      : null,
                                  cachedProfile: msg.sharedProfileId != null
                                      ? _profileCache[msg.sharedProfileId]
                                      : null,
                                  onLongPress: () =>
                                      _showMessageActions(msg, isMe),
                                  onReactionTap: (emoji) =>
                                      _onToggleReaction(msg, emoji),
                                ),
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

          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.creamLight,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: AppColors.coral, width: 4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replying to message',
                            style: TextStyle(
                              color: AppColors.coral,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _replyingTo!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.darkGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.lightGrey),
                    onPressed: () {
                      setState(() {
                        _replyingTo = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Chat Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.creamBg,
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onMessageChanged,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: IconButton(
                            icon: const Icon(
                              Icons.image_outlined,
                              color: AppColors.coral,
                              size: 22,
                            ),
                            onPressed: _pickAndSendImage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.lightGrey),
                        filled: true,
                        fillColor: AppColors.creamLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
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
                    height: 44,
                    width: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
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

  Widget _buildProfileHeader() {
    if (_otherUserProfile == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _otherUserProfile!.avatarUrl != null
                ? CachedNetworkImageProvider(_otherUserProfile!.avatarUrl!)
                : null,
            backgroundColor: AppColors.creamDark,
            child: _otherUserProfile!.avatarUrl == null
                ? Icon(Icons.person, size: 50, color: AppColors.lightGrey)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            '@${_otherUserProfile!.displayName ?? _otherUserProfile!.username}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              (_otherUserProfile!.bio != null &&
                      _otherUserProfile!.bio!.trim().isNotEmpty)
                  ? _otherUserProfile!.bio!
                  : 'No bio available',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
                fontStyle: (_otherUserProfile!.bio != null &&
                        _otherUserProfile!.bio!.trim().isNotEmpty)
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              context.push('/profile/${_otherUserProfile!.id}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.creamDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              'View Profile',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final canDeleteForEveryone =
            !msg.deletedForEveryone &&
            isMe &&
            _chatRepo.canDeleteForEveryone(msg);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!msg.deletedForEveryone) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ChatReactionBar(
                    onReactionSelected: (emoji) {
                      Navigator.pop(context);
                      _onToggleReaction(msg, emoji);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.reply, color: AppColors.black),
                  title: Text(
                    'Reply',
                    style: TextStyle(color: AppColors.black),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyingTo = msg;
                    });
                  },
                ),
                if (msg.content.isNotEmpty && msg.content != 'Sent an image')
                  ListTile(
                    leading: Icon(Icons.copy, color: AppColors.black),
                    title: Text(
                      'Copy',
                      style: TextStyle(color: AppColors.black),
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.content));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied to clipboard'),
                        ),
                      );
                    },
                  ),
              ],
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete for me',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(msg.id);
                },
              ),
              if (canDeleteForEveryone)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete for everyone',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteForEveryone(msg);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteMessageForMe(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _chatRepo.deleteMessageForMe(id, userId);
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete message')),
        );
      }
    }
  }

  Future<void> _confirmDeleteForEveryone(MessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.creamBg,
        title: Text(
          'Delete for everyone?',
          style: TextStyle(color: AppColors.black),
        ),
        content: Text(
          'This message will be removed for all participants.',
          style: TextStyle(color: AppColors.darkGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.darkGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _chatRepo.deleteMessageForEveryone(msg.id, widget.roomId, userId);
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == msg.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete message for everyone'),
          ),
        );
      }
    }
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
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
