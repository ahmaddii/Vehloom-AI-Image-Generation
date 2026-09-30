class CommentModel {
  final String id;
  final String userId;
  final String artworkId;
  final String content;
  final DateTime createdAt;
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final bool isVerified;

  CommentModel({
    required this.id,
    required this.userId,
    required this.artworkId,
    required this.content,
    required this.createdAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.isVerified = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CommentModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      artworkId: json['artwork_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorUsername: profile?['username'] as String? ?? json['author_username'] as String?,
      authorDisplayName: profile?['display_name'] as String? ?? json['author_display_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String? ?? json['author_avatar_url'] as String?,
      isVerified: profile?['is_verified'] as bool? ?? json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'artwork_id': artworkId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'author_username': authorUsername,
      'author_display_name': authorDisplayName,
      'author_avatar_url': authorAvatarUrl,
      'is_verified': isVerified,
    };
  }

  CommentModel copyWith({
    String? id,
    String? userId,
    String? artworkId,
    String? content,
    DateTime? createdAt,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    bool? isVerified,
  }) {
    return CommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      artworkId: artworkId ?? this.artworkId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
