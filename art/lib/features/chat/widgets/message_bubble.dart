import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
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

  bool _isEmojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final clean = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return false;
    final emojiRegex = RegExp(
      r'^(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])+$',
    );
    return emojiRegex.hasMatch(clean);
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = msg.deletedForEveryone;
    final hasImage = msg.imageUrl != null;
    final isPureImage = hasImage &&
        (msg.content.isEmpty || msg.content == 'Sent an image') &&
        msg.sharedArtworkId == null &&
        msg.sharedProfileId == null;
    final isEmojiOnly = !isDeleted &&
        !hasImage &&
        msg.sharedArtworkId == null &&
        msg.sharedProfileId == null &&
        _isEmojiOnly(msg.content);

    final borderRadius = BorderRadius.circular(16).copyWith(
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
    );

    final hasReactions = !isDeleted && msg.reactions.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: hasReactions ? 10 : 2),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
        children: [
          // Main Chat Message Container
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              key: ValueKey(msg.id),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: isPureImage
                  ? EdgeInsets.zero
                  : isEmojiOnly
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: (isPureImage || isEmojiOnly)
                    ? Colors.transparent
                    : isMe
                        ? AppColors.coral
                        : AppColors.creamLight,
                borderRadius: borderRadius,
                border: isPureImage
                    ? Border.all(
                        color: isMe
                            ? AppColors.coral.withValues(alpha: 0.5)
                            : AppColors.lightGrey.withValues(alpha: 0.35),
                        width: 1.5,
                      )
                    : null,
                boxShadow: (isPureImage || isEmojiOnly)
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDeleted)
                    _DeletedPlaceholder(isMe: isMe)
                  else ...[
                    if (msg.replyToContent != null)
                      _ReplyPreview(msg: msg, isMe: isMe),
                    if (hasImage)
                      _ImageContent(
                        imageUrl: msg.imageUrl!,
                        borderRadius: borderRadius,
                        isPureImage: isPureImage,
                        isMe: isMe,
                      ),
                    if (msg.sharedArtworkId != null)
                      _ArtworkCard(artwork: cachedArtwork),
                    if (msg.sharedProfileId != null)
                      _ProfileCard(profile: cachedProfile),
                    if (msg.content.isNotEmpty && msg.content != 'Sent an image')
                      Text(
                        msg.content,
                        style: TextStyle(
                          color: isEmojiOnly
                              ? null
                              : isMe
                                  ? Colors.white
                                  : AppColors.black,
                          fontSize: isEmojiOnly ? 36 : 16,
                          height: isEmojiOnly ? 1.1 : 1.35,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Attached WhatsApp-style reaction badge floating on the bottom corner
          if (hasReactions)
            Positioned(
              bottom: -11,
              right: isMe ? 8 : null,
              left: isMe ? null : 8,
              child: _AttachedReactionPill(
                msg: msg,
                isMe: isMe,
                currentUserId: currentUserId,
                onReactionTap: onReactionTap,
              ),
            ),
        ],
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

void _openFullScreenImage(BuildContext context, String imageUrl) {
  final isLocal = imageUrl.startsWith('/') || imageUrl.startsWith('file://');
  final cleanPath = imageUrl.replaceFirst('file://', '');

  showDialog(
    context: context,
    useSafeArea: false,
    builder: (ctx) => Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: isLocal
                  ? Image.file(
                      File(cleanPath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => SizedBox(
                        width: 280,
                        height: 380,
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey[900]!,
                          highlightColor: Colors.grey[800]!,
                          child: Container(color: Colors.white10),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImageContent extends StatelessWidget {
  final String imageUrl;
  final BorderRadius? borderRadius;
  final bool isPureImage;
  final bool isMe;

  const _ImageContent({
    required this.imageUrl,
    this.borderRadius,
    this.isPureImage = false,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLocal = imageUrl.startsWith('/') || imageUrl.startsWith('file://');
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, imageUrl),
      child: Padding(
        padding: EdgeInsets.only(bottom: isPureImage ? 0 : 6),
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 340),
            child: isLocal
                ? Image.file(
                    File(imageUrl.replaceFirst('file://', '')),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    placeholder: (_, __) => SizedBox(
                      width: 220,
                      height: 180,
                      child: Shimmer.fromColors(
                        baseColor: isMe
                            ? AppColors.coral.withValues(alpha: 0.35)
                            : AppColors.creamDark,
                        highlightColor: isMe
                            ? AppColors.coral.withValues(alpha: 0.15)
                            : AppColors.creamLight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: effectiveRadius,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 180,
                      height: 180,
                      color: isMe
                          ? AppColors.coral.withValues(alpha: 0.2)
                          : AppColors.creamDark,
                      child: Icon(Icons.broken_image_outlined, color: AppColors.darkGrey),
                    ),
                  ),
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
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: AppColors.creamDark,
                  highlightColor: AppColors.creamLight,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  width: double.infinity,
                  color: AppColors.creamDark,
                  child: Icon(Icons.broken_image_outlined, color: AppColors.darkGrey),
                ),
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

class _AttachedReactionPill extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final String? currentUserId;
  final void Function(String emoji) onReactionTap;

  const _AttachedReactionPill({
    required this.msg,
    required this.isMe,
    required this.currentUserId,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.lightGrey.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: msg.reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final hasReacted =
              currentUserId != null && users.contains(currentUserId);

          return GestureDetector(
            onTap: () => onReactionTap(emoji),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: hasReacted
                  ? BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (users.length > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      users.length.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasReacted ? AppColors.coral : AppColors.black,
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
