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

  Future<void> _startChat(String otherUserId) async {
    if (_currentUserId == null) return;

    // Show a loading indicator if desired, or just push immediately if optimistic
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
      if (mounted) {
        Navigator.pop(context); // pop loading dialog
        context.push('/chat/${room.id}?otherUserId=$otherUserId');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat')));
      }
    }
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
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Widget _buildFollowingHorizontalList() {
    return FutureBuilder<List<ProfileModel>>(
      future: _getFollowingAndMe(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Hide if no following or loading
        }

        final profiles = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Start a chat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.darkGrey,
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final avatarUrl = profile.avatarUrl;

                  return GestureDetector(
                    onTap: () => _startChat(profile.id),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                backgroundColor: AppColors.creamDark,
                                child: avatarUrl == null
                                    ? Icon(
                                        Icons.person,
                                        color: AppColors.lightGrey,
                                        size: 28,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: profile.isOnline ? Colors.green : AppColors.lightGrey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.creamBg,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.id == _currentUserId ? 'Your Note' : (profile.displayName ?? ''),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (!profile.isOnline && profile.id != _currentUserId && profile.lastSeen != null)
                            Text(
                              _formatExactTime(profile.lastSeen!),
                              style: TextStyle(fontSize: 10, color: AppColors.lightGrey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, thickness: 1, color: AppColors.creamLight),
          ],
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
          title: Text('Inbox', style: TextStyle(color: AppColors.black)),
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
          'Inbox',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
      ),
      body: Column(
        children: [
          // Horizontal List of Followed Persons
          _buildFollowingHorizontalList(),

          // Chat Rooms Stream
          Expanded(
            child: StreamBuilder<List<ChatRoomModel>>(
              stream: _chatRepo.getInbox(_currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }

                final rooms = snapshot.data ?? [];
                if (rooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  );
                }

                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final otherUserId = room.participants.firstWhere(
                      (id) => id != _currentUserId,
                    );

                    return FutureBuilder<ProfileModel?>(
                      future: _profileRepo.getProfile(otherUserId),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;
                        final displayName =
                            profile?.displayName ?? 'Unknown User';
                        final avatarUrl = profile?.avatarUrl;

                        final isUnread = PreferencesService().isRoomUnread(room.id, room.lastUpdated);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            backgroundColor: AppColors.creamDark,
                            child: avatarUrl == null
                                ? Icon(Icons.person, color: AppColors.lightGrey)
                                : null,
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold),
                          ),
                          subtitle: Text(
                            room.lastMessage ?? 'Started a chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: room.lastMessage == null
                                  ? AppColors.coral
                                  : (isUnread ? AppColors.black : AppColors.lightGrey),
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              fontStyle: room.lastMessage == null
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isUnread)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.lightGrey,
                                  size: 24,
                                ),
                                onPressed: () {
                                  PreferencesService().markRoomRead(room.id);
                                  context.push(
                                    '/chat/${room.id}?otherUserId=$otherUserId',
                                  ).then((_) {
                                    if (mounted) setState(() {});
                                  });
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            PreferencesService().markRoomRead(room.id);
                            context.push(
                              '/chat/${room.id}?otherUserId=$otherUserId',
                            ).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
