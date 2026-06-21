class CommentModel {
  final String id;
  final String userId;
  final String artworkId;
  final String content;
  final DateTime createdAt;
  final String? authorUsername;
  final String? authorAvatarUrl;

  CommentModel({
    required this.id,
    required this.userId,
    required this.artworkId,
    required this.content,
    required this.createdAt,
    this.authorUsername,
    this.authorAvatarUrl,
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
      authorAvatarUrl: profile?['avatar_url'] as String? ?? json['author_avatar_url'] as String?,
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
      'author_avatar_url': authorAvatarUrl,
    };
  }

  CommentModel copyWith({
    String? id,
    String? userId,
    String? artworkId,
    String? content,
    DateTime? createdAt,
    String? authorUsername,
    String? authorAvatarUrl,
  }) {
    return CommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      artworkId: artworkId ?? this.artworkId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
