import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/models/chat_room_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/profile_repository.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _chatRepo = ChatRepository();
  final _profileRepo = ProfileRepository();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // BUG FIX: the old code called `_getFollowingAndMe()` (a network call)
  // directly inside `build()` via FutureBuilder(future: ...). Every setState
  // (e.g. after popping back from a chat) created a *brand new* Future,
  // which FutureBuilder treated as "new work", re-hitting the network and
  // flashing a loading state. Fetching once in initState and caching the
  // Future fixes both the flicker and the redundant calls.
  late Future<List<ProfileModel>> _followingFuture;

  // BUG FIX: profiles for each room were fetched with a per-tile
  // FutureBuilder that re-ran on every rebuild (N+1 query problem, and a
  // fresh network call every time you returned from a chat). We cache
  // resolved profiles and only fetch a given user once.
  final Map<String, ProfileModel?> _profileCache = {};
  final Map<String, Future<ProfileModel?>> _profileFetchesInFlight = {};

  @override
  void initState() {
    super.initState();
    _followingFuture = _getFollowingAndMe();
  }

  Future<void> _refresh() async {
    setState(() {
      _followingFuture = _getFollowingAndMe();
      _profileCache.clear();
      _profileFetchesInFlight.clear();
    });
  }

  Future<ProfileModel?> _cachedProfile(String userId) {
    if (_profileCache.containsKey(userId)) {
      return Future.value(_profileCache[userId]);
    }
    return _profileFetchesInFlight.putIfAbsent(userId, () async {
      final profile = await _profileRepo.getProfile(userId);
      _profileCache[userId] = profile;
      return profile;
    });
  }

  Future<void> _startChat(String otherUserId) async {
    if (_currentUserId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.coral),
      ),
    );

    try {
      final room = await _chatRepo.createOrGetChatRoom(
        _currentUserId,
        otherUserId,
      );
      if (!mounted) return;
      Navigator.pop(context); // pop loading dialog
      await context.push('/chat/${room.id}?otherUserId=$otherUserId');
      // BUG FIX: only refresh local read-state, don't refetch the whole
      // following list again.
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error starting chat')));
      }
    }
  }

  void _openChat(String roomId, String otherUserId) async {
    await context.push('/chat/$roomId?otherUserId=$otherUserId');
    if (mounted) setState(() {}); // refresh unread dots, no network refetch
  }

  Future<List<ProfileModel>> _getFollowingAndMe() async {
    if (_currentUserId == null) return [];
    final following = await _profileRepo.getFollowing(_currentUserId);
    final me = await _profileRepo.getProfile(_currentUserId);
    if (me != null) {
      return [me.copyWith(isOnline: true), ...following];
    }
    return following;
  }

  String _formatExactTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Widget _avatarWithDot(
    String? avatarUrl, {
    required bool showDot,
    required bool isOnline,
  }) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          backgroundColor: AppColors.creamDark,
          child: avatarUrl == null
              ? Icon(Icons.person, color: AppColors.lightGrey, size: 28)
              : null,
        ),
        if (showDot)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : AppColors.lightGrey,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.creamBg, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _horizontalPeopleList({
    required String title,
    required List<ProfileModel> profiles,
    bool showAddButton = false,
  }) {
    if (profiles.isEmpty && !showAddButton) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.darkGrey,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (showAddButton)
                GestureDetector(
                  // TODO: point this at your "find people" / new-chat search screen.
                  onTap: () => context.push('/discover'),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.creamLight,
                          child: Icon(
                            Icons.add,
                            color: AppColors.coral,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              for (final profile in profiles)
                GestureDetector(
                  onTap: () => _startChat(profile.id),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        _avatarWithDot(
                          profile.avatarUrl,
                          showDot: true,
                          isOnline: profile.isOnline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.id == _currentUserId
                              ? 'Your Note'
                              : (profile.displayName ?? ''),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (!profile.isOnline &&
                            profile.id != _currentUserId &&
                            profile.lastSeen != null)
                          Text(
                            _formatExactTime(profile.lastSeen!),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.lightGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSections() {
    return FutureBuilder<List<ProfileModel>>(
      future: _followingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final profiles = snapshot.data!;
        final activeNow = profiles
            .where((p) => p.isOnline && p.id != _currentUserId)
            .toList();

        return Column(
          children: [
            _horizontalPeopleList(
              title: 'Start a chat',
              profiles: profiles,
              showAddButton: false,
            ),
            if (activeNow.isNotEmpty)
              _horizontalPeopleList(title: 'Active Chat', profiles: activeNow),
            Divider(height: 1, thickness: 1, color: AppColors.creamLight),
          ],
        );
      },
    );
  }

  Widget _buildRoomTile(ChatRoomModel room) {
    final otherUserId = room.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<ProfileModel?>(
      future: _cachedProfile(otherUserId),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final displayName = profile?.displayName ?? 'Unknown User';
        final avatarUrl = profile?.avatarUrl;
        final amILastSender = room.lastMessageSenderId == _currentUserId;
        final isUnread = !amILastSender && !room.lastMessageRead;

        return ListTile(
          key: ValueKey(room.id),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            backgroundColor: AppColors.creamDark,
            child: avatarUrl == null
                ? Icon(Icons.person, color: AppColors.lightGrey)
                : null,
          ),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          subtitle: room.lastMessage == null
              ? Text(
                  'Start chat',
                  style: TextStyle(
                    color: AppColors.coral,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (amILastSender) ...[
                      Icon(
                        Icons.done_all,
                        size: 16,
                        color: room.lastMessageRead
                            ? Colors.blue
                            : AppColors.lightGrey,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        room.lastMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread
                              ? AppColors.black
                              : AppColors.lightGrey,
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
          // NOTE: the screenshot shows a numeric unread badge (e.g. "2",
          // "3"). That requires an actual unread-message *count* per room,
          // which the current PreferencesService/ChatRoomModel don't track
          // (only a boolean "has unread"). Shown here as a coral dot to
          // match the theme; swap in a real count once that data exists,
          // e.g. `room.unreadCount` from the repo.
          trailing: isUnread
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () => _openChat(room.id, otherUserId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.creamBg,
        appBar: AppBar(
          title: Text('Messages', style: TextStyle(color: AppColors.black)),
          backgroundColor: AppColors.creamBg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.black),
        ),
        body: const Center(child: Text('Please log in to view messages.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
      ),
      body: RefreshIndicator(
        color: AppColors.coral,
        onRefresh: _refresh,
        child: StreamBuilder<List<ChatRoomModel>>(
          stream: _chatRepo.getInbox(_currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox.shrink();
            }

            if (snapshot.hasError) {
              return ListView(
                // wrapped in a ListView so RefreshIndicator still works on error
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('Error loading messages.')),
                ],
              );
            }

            final rooms = snapshot.data ?? [];

            return ListView(
              children: [
                _buildTopSections(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Recent Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ),
                if (rooms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.lightGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with your favorite artists!',
                          style: TextStyle(color: AppColors.lightGrey),
                        ),
                      ],
                    ),
                  )
                else
                  ...rooms.map(_buildRoomTile),
              ],
            );
          },
        ),
      ),
    );
  }
}
