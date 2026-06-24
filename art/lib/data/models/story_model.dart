import 'artwork_model.dart';
import 'profile_model.dart';

class StoryModel {
  final String id;
  final String userId;
  final String? artworkId;
  final String mediaUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  // Relations
  final ProfileModel? profile;
  final ArtworkModel? artwork;

  StoryModel({
    required this.id,
    required this.userId,
    this.artworkId,
    required this.mediaUrl,
    required this.createdAt,
    required this.expiresAt,
    this.profile,
    this.artwork,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? profileObj;
    if (json['profiles'] != null) {
      profileObj = ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>);
    }
    ArtworkModel? artworkObj;
    if (json['artworks'] != null) {
      artworkObj = ArtworkModel.fromJson(json['artworks'] as Map<String, dynamic>);
    }

    return StoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      artworkId: json['artwork_id'] as String?,
      mediaUrl: json['media_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      profile: profileObj,
      artwork: artworkObj,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'artwork_id': artworkId,
      'media_url': mediaUrl,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      if (profile != null) 'profiles': profile!.toJson(),
      if (artwork != null) 'artworks': artwork!.toJson(),
    };
  }
}
