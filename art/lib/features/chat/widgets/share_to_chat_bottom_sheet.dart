import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/profile_repository.dart';

class ShareToChatBottomSheet extends StatefulWidget {
  final String? sharedArtworkId;
  final String? sharedProfileId;

  const ShareToChatBottomSheet({
    super.key,
    this.sharedArtworkId,
    this.sharedProfileId,
  }) : assert(
         sharedArtworkId != null || sharedProfileId != null,
         'Must provide either sharedArtworkId or sharedProfileId',
       );

  @override
  State<ShareToChatBottomSheet> createState() => _ShareToChatBottomSheetState();
}

class _ShareToChatBottomSheetState extends State<ShareToChatBottomSheet> {
  final _chatRepo = ChatRepository();
  final _profileRepo = ProfileRepository();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  List<ProfileModel> _users = [];
  bool _isLoading = true;
  final Set<String> _sharedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    try {
      // For sharing, let's load people the user is following
      final following = await _profileRepo.getFollowing(currentUserId);
      if (mounted) {
        setState(() {
          _users = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareToUser(ProfileModel user) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Optimistic UI update
    setState(() {
      _sharedUserIds.add(user.id);
    });

    try {
      final room = await _chatRepo.createOrGetChatRoom(currentUserId, user.id);

      await _chatRepo.sendMessage(
        room.id,
        currentUserId,
        widget.sharedArtworkId != null
            ? 'Shared an artwork'
            : 'Shared a profile',
        sharedArtworkId: widget.sharedArtworkId,
        sharedProfileId: widget.sharedProfileId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to ${user.displayName ?? user.username}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sharedUserIds.remove(user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share to ${user.displayName ?? user.username}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppColors.creamBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Send to',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.lightGrey, thickness: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  )
                : _users.isEmpty
                ? Center(
                    child: Text(
                      'Follow some users to easily share with them.',
                      style: TextStyle(color: AppColors.darkGrey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isShared = _sharedUserIds.contains(user.id);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              user.avatarUrl != null &&
                                  user.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          backgroundColor: AppColors.creamDark,
                          child:
                              user.avatarUrl == null || user.avatarUrl!.isEmpty
                              ? Icon(Icons.person, color: AppColors.lightGrey)
                              : null,
                        ),
                        title: Text(
                          user.displayName ?? user.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('@${user.username}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isShared
                                ? AppColors.creamLight
                                : AppColors.coral,
                            foregroundColor: isShared
                                ? AppColors.black
                                : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: isShared
                                  ? BorderSide(color: AppColors.lightGrey)
                                  : BorderSide.none,
                            ),
                          ),
                          onPressed: isShared ? null : () => _shareToUser(user),
                          child: Text(isShared ? 'Sent' : 'Send'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
