class ProfileModel {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? websiteUrl;
  final String? instagramUsername;
  final List<String> specialties;
  final DateTime createdAt;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool isVerified;

  ProfileModel({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.websiteUrl,
    this.instagramUsername,
    this.specialties = const [],
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.isVerified = false,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      websiteUrl: json['website_url'] as String?,
      instagramUsername: json['instagram_username'] as String?,
      specialties:
          (json['specialties'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      isVerified:
          json['is_verified'] == true ||
          json['is_verified'] == 'true' ||
          json['is_verified'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'website_url': websiteUrl,
      'instagram_username': instagramUsername,
      'specialties': specialties,
      'created_at': createdAt.toIso8601String(),
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'is_verified': isVerified,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? websiteUrl,
    String? instagramUsername,
    List<String>? specialties,
    DateTime? createdAt,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isVerified,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      instagramUsername: instagramUsername ?? this.instagramUsername,
      specialties: specialties ?? this.specialties,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
