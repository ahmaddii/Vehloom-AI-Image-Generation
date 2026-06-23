import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/social_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();
  late Future<List<NotificationModel>> _notificationsFuture;
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
    _subscribeToRealtimeNotifications();
  }

  @override
  void dispose() {
    final channel = _notificationsChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToRealtimeNotifications() {
    final userId = _currentUserId;
    if (userId == null) return;

    _notificationsChannel = Supabase.instance.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (_) {
            if (!mounted) return;
            setState(() {
              _notificationsFuture = _loadNotifications();
            });
          },
        )
        .subscribe();
  }

  Future<List<NotificationModel>> _loadNotifications() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    return _repository.fetchNotifications(userId);
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
    await _notificationsFuture;
  }

  Future<void> _markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _repository.markAllAsRead(userId);
    await _refresh();
  }

  Future<void> _openNotification(NotificationModel notification) async {
    if (!notification.isRead) {
      await _repository.markAsRead(notification.id);
    }

    if (!mounted) return;
    if (notification.artworkId != null &&
        (notification.type == 'like' || notification.type == 'comment')) {
      context.push('/artwork/${notification.artworkId}');
    } else if (notification.actorId != null) {
      context.push('/profile/${notification.actorId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const _EmptyNotificationsState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              subtitle: 'Likes, comments, and follows will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final actorName = notification.actorDisplayName?.trim().isNotEmpty == true
        ? notification.actorDisplayName!
        : notification.actorUsername != null
            ? notification.actorUsername!
            : 'Someone';
    
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ActorAvatar(notification: notification),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: actorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: _messageSuffixForNotification(notification),
                        ),
                        TextSpan(
                          text: '  ${_formatTime(notification.createdAt)}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notification.type == 'comment' &&
                      notification.commentContent?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.commentContent!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _TrailingPreview(notification: notification),
          ],
        ),
      ),
    );
  }

  static String _messageSuffixForNotification(NotificationModel notification) {
    switch (notification.type) {
      case 'like':
        return ' liked your post.';
      case 'comment':
        return ' commented:';
      case 'follow':
        return ' started following you.';
      default:
        return ' sent you a notification.';
    }
  }

  static String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}



class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: notification.actorAvatarUrl != null &&
              notification.actorAvatarUrl!.isNotEmpty
          ? CachedNetworkImageProvider(notification.actorAvatarUrl!)
          : null,
      child: notification.actorAvatarUrl == null ||
              notification.actorAvatarUrl!.isEmpty
          ? Icon(
              Icons.person,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}

class _TrailingPreview extends StatelessWidget {
  const _TrailingPreview({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final imageUrl = notification.artworkImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        ),
      );
    }

    if (notification.type == 'follow' && notification.actorId != null) {
      return _NotificationFollowButton(actorId: notification.actorId!);
    }

    return const SizedBox();
  }
}

class _NotificationFollowButton extends StatefulWidget {
  const _NotificationFollowButton({required this.actorId});

  final String actorId;

  @override
  State<_NotificationFollowButton> createState() => _NotificationFollowButtonState();
}

class _NotificationFollowButtonState extends State<_NotificationFollowButton> {
  bool _isFollowing = false;
  bool _isLoading = true;
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _checkFollowingStatus();
  }

  Future<void> _checkFollowingStatus() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final isFollowing = await SocialRepository().isFollowing(_currentUserId!, widget.actorId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _isLoading) return;

    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
    });

    try {
      if (wasFollowing) {
        await SocialRepository().unfollowUser(_currentUserId!, widget.actorId);
      } else {
        await SocialRepository().followUser(_currentUserId!, widget.actorId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 70,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _isFollowing
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: _isFollowing ? theme.colorScheme.onSurface : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
