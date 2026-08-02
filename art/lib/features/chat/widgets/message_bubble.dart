import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/artwork_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/profile_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final String? currentUserId;
  final ArtworkModel? cachedArtwork;
  final ProfileModel? cachedProfile;
  final VoidCallback onLongPress;
  final void Function(String emoji) onReactionTap;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.currentUserId,
    required this.onLongPress,
    required this.onReactionTap,
    this.cachedArtwork,
    this.cachedProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = msg.deletedForEveryone;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        key: ValueKey(msg.id),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.coral : AppColors.creamLight,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDeleted)
              _DeletedPlaceholder(isMe: isMe)
            else ...[
              if (msg.replyToContent != null) _ReplyPreview(msg: msg, isMe: isMe),
              if (msg.imageUrl != null) _ImageContent(imageUrl: msg.imageUrl!),
              if (msg.sharedArtworkId != null)
                _ArtworkCard(artwork: cachedArtwork),
              if (msg.sharedProfileId != null)
                _ProfileCard(profile: cachedProfile),
              if (msg.content.isNotEmpty && msg.content != 'Sent an image')
                Text(
                  msg.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.black,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
            ],
            if (!isDeleted && msg.reactions.isNotEmpty)
              _ReactionChips(
                msg: msg,
                isMe: isMe,
                currentUserId: currentUserId,
                onReactionTap: onReactionTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _DeletedPlaceholder extends StatelessWidget {
  final bool isMe;

  const _DeletedPlaceholder({required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.block,
          size: 16,
          color: isMe ? Colors.white70 : AppColors.lightGrey,
        ),
        const SizedBox(width: 6),
        Text(
          'This message was deleted',
          style: TextStyle(
            color: isMe ? Colors.white70 : AppColors.lightGrey,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;

  const _ReplyPreview({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : AppColors.coral,
            width: 3,
          ),
        ),
      ),
      child: Text(
        msg.replyToContent!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe ? Colors.white70 : AppColors.darkGrey,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final String imageUrl;

  const _ImageContent({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 480,
            placeholder: (_, __) => const SizedBox(
              width: 180,
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  final ArtworkModel? artwork;

  const _ArtworkCard({this.artwork});

  @override
  Widget build(BuildContext context) {
    if (artwork == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          'Artwork unavailable',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: AppColors.lightGrey,
            fontSize: 13,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/artwork/${artwork!.id}', extra: artwork),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedNetworkImage(
                imageUrl: artwork!.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 400,
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  artwork!.title,
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileModel? profile;

  const _ProfileCard({this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          'Profile unavailable',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: AppColors.lightGrey,
            fontSize: 13,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/profile/${profile!.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: profile!.avatarUrl != null
                      ? CachedNetworkImageProvider(profile!.avatarUrl!)
                      : null,
                  backgroundColor: AppColors.creamLight,
                  child: profile!.avatarUrl == null
                      ? Icon(Icons.person, color: AppColors.lightGrey)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile!.displayName ?? profile!.username,
                        style: TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${profile!.username}',
                        style: TextStyle(color: AppColors.darkGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final String? currentUserId;
  final void Function(String emoji) onReactionTap;

  const _ReactionChips({
    required this.msg,
    required this.isMe,
    required this.currentUserId,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: msg.reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final hasReacted =
              currentUserId != null && users.contains(currentUserId);

          return GestureDetector(
            onTap: () => onReactionTap(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasReacted
                    ? (isMe ? Colors.white : AppColors.coral.withValues(alpha: 0.15))
                    : (isMe
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(14),
                border: hasReacted
                    ? Border.all(color: isMe ? Colors.white : AppColors.coral, width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      users.length.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : AppColors.darkGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
