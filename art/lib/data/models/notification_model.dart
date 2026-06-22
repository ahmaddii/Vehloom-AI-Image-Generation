class NotificationModel {
  final String id;
  final String recipientId;
  final String? actorId;
  final String type; // 'like', 'comment', 'follow'
  final String? artworkId;
  final String? commentId;
  final String? commentContent;
  final bool isRead;
  final DateTime createdAt;
  final String? actorUsername;
  final String? actorDisplayName;
  final String? actorAvatarUrl;
  final String? artworkTitle;
  final String? artworkImageUrl;

  NotificationModel({
    required this.id,
    required this.recipientId,
    this.actorId,
    required this.type,
    this.artworkId,
    this.commentId,
    this.commentContent,
    required this.isRead,
    required this.createdAt,
    this.actorUsername,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.artworkTitle,
    this.artworkImageUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final artwork = json['artworks'] as Map<String, dynamic>?;

    return NotificationModel(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      actorId: json['actor_id'] as String?,
      type: json['type'] as String,
      artworkId: json['artwork_id'] as String?,
      commentId: json['comment_id'] as String?,
      commentContent: json['comment_content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      actorUsername: actor?['username'] as String?,
      actorDisplayName: actor?['display_name'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
      artworkTitle: artwork?['title'] as String?,
      artworkImageUrl: artwork?['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type,
      'artwork_id': artworkId,
      'comment_id': commentId,
      'comment_content': commentContent,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'actor_username': actorUsername,
      'actor_display_name': actorDisplayName,
      'actor_avatar_url': actorAvatarUrl,
      'artwork_title': artworkTitle,
      'artwork_image_url': artworkImageUrl,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? recipientId,
    String? actorId,
    String? type,
    String? artworkId,
    String? commentId,
    String? commentContent,
    bool? isRead,
    DateTime? createdAt,
    String? actorUsername,
    String? actorDisplayName,
    String? actorAvatarUrl,
    String? artworkTitle,
    String? artworkImageUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      actorId: actorId ?? this.actorId,
      type: type ?? this.type,
      artworkId: artworkId ?? this.artworkId,
      commentId: commentId ?? this.commentId,
      commentContent: commentContent ?? this.commentContent,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actorUsername: actorUsername ?? this.actorUsername,
      actorDisplayName: actorDisplayName ?? this.actorDisplayName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      artworkTitle: artworkTitle ?? this.artworkTitle,
      artworkImageUrl: artworkImageUrl ?? this.artworkImageUrl,
    );
  }
}
