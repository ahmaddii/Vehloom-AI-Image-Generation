class ArtworkModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String imageUrl;
  final List<String> tags;
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final DateTime createdAt;
  final String? authorUsername;
  final String? authorAvatarUrl;

  ArtworkModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.imageUrl,
    required this.tags,
    required this.likesCount,
    required this.commentsCount,
    this.favoritesCount = 0,
    required this.createdAt,
    this.authorUsername,
    this.authorAvatarUrl,
  });

  factory ArtworkModel.fromJson(Map<String, dynamic> json) {
    // Check if profiles relation was loaded
    final profile = json['profiles'] as Map<String, dynamic>?;
    
    // Check if likes/comments list/count aggregate was loaded
    int parsedLikes = 0;
    if (json['likes'] != null) {
      if (json['likes'] is List) {
        final list = json['likes'] as List;
        if (list.isNotEmpty && list.first is Map && list.first['count'] != null) {
          parsedLikes = list.first['count'] as int;
        } else {
          parsedLikes = list.length;
        }
      } else if (json['likes'] is int) {
        parsedLikes = json['likes'] as int;
      }
    } else {
      parsedLikes = json['likes_count'] as int? ?? 0;
    }

    int parsedComments = 0;
    if (json['comments'] != null) {
      if (json['comments'] is List) {
        final list = json['comments'] as List;
        if (list.isNotEmpty && list.first is Map && list.first['count'] != null) {
          parsedComments = list.first['count'] as int;
        } else {
          parsedComments = list.length;
        }
      } else if (json['comments'] is int) {
        parsedComments = json['comments'] as int;
      }
    } else {
      parsedComments = json['comments_count'] as int? ?? 0;
    }

    int parsedFavorites = 0;
    if (json['favorites'] != null) {
      if (json['favorites'] is List) {
        final list = json['favorites'] as List;
        if (list.isNotEmpty && list.first is Map && list.first['count'] != null) {
          parsedFavorites = list.first['count'] as int;
        } else {
          parsedFavorites = list.length;
        }
      } else if (json['favorites'] is int) {
        parsedFavorites = json['favorites'] as int;
      }
    } else {
      parsedFavorites = json['favorites_count'] as int? ?? 0;
    }

    return ArtworkModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      likesCount: parsedLikes,
      commentsCount: parsedComments,
      favoritesCount: parsedFavorites,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorUsername: profile?['username'] as String? ?? json['author_username'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String? ?? json['author_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'tags': tags,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'favorites_count': favoritesCount,
      'created_at': createdAt.toIso8601String(),
      'author_username': authorUsername,
      'author_avatar_url': authorAvatarUrl,
    };
  }

  ArtworkModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? imageUrl,
    List<String>? tags,
    int? likesCount,
    int? commentsCount,
    int? favoritesCount,
    DateTime? createdAt,
    String? authorUsername,
    String? authorAvatarUrl,
  }) {
    return ArtworkModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      createdAt: createdAt ?? this.createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
