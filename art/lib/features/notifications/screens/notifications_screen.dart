import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
        : '@${notification.actorUsername ?? 'Someone'}';
    final accentColor = _colorForType(theme, notification.type);
    final unread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: unread
            ? accentColor.withValues(alpha: isDark ? 0.16 : 0.10)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: unread
                    ? accentColor.withValues(alpha: 0.36)
                    : colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                        Row(
                          children: [
                            _TypePill(
                              type: notification.type,
                              color: accentColor,
                              icon: _iconForType(notification.type),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(notification.createdAt),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppColors.coral,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.coral.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        RichText(
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              height: 1.25,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: actorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: _messageSuffixForNotification(
                                  notification,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (notification.type == 'comment' &&
                            notification.commentContent?.trim().isNotEmpty ==
                                true) ...[
                          const SizedBox(height: 9),
                          _CommentPreview(
                            content: notification.commentContent!.trim(),
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
          ),
        ),
      ),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add_alt_1;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _colorForType(ThemeData theme, String type) {
    switch (type) {
      case 'like':
        return AppColors.coral;
      case 'comment':
        return const Color(0xFF2F80ED);
      case 'follow':
        return AppColors.success;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  static String _messageSuffixForNotification(NotificationModel notification) {
    final artworkTitle = notification.artworkTitle;
    switch (notification.type) {
      case 'like':
        return artworkTitle == null
            ? ' liked your artwork'
            : ' liked your artwork "$artworkTitle"';
      case 'comment':
        return artworkTitle == null
            ? ' commented on your artwork'
            : ' commented on "$artworkTitle"';
      case 'follow':
        return ' started following you';
      default:
        return ' sent you a notification';
    }
  }

  static String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _CommentPreview extends StatelessWidget {
  const _CommentPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.42 : 0.62,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        '"$content"',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.coral,
                  theme.colorScheme.primary,
                  const Color(0xFF2F80ED),
                ],
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.surface,
              backgroundImage:
                  notification.actorAvatarUrl != null &&
                      notification.actorAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(notification.actorAvatarUrl!)
                  : null,
              child:
                  notification.actorAvatarUrl == null ||
                      notification.actorAvatarUrl!.isEmpty
                  ? Icon(
                      Icons.person_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
          Positioned(
            right: -1,
            bottom: 1,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: theme.scaffoldBackgroundColor),
              ),
              child: Icon(
                _NotificationTile._iconForType(notification.type),
                size: 13,
                color: _NotificationTile._colorForType(
                  theme,
                  notification.type,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.type,
    required this.color,
    required this.icon,
  });

  final String type;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'like' => 'Like',
      'comment' => 'Comment',
      'follow' => 'Follow',
      _ => 'Activity',
    };

    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
      return Hero(
        tag: 'notification-artwork-${notification.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
