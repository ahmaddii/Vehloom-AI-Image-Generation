enum MessageStatus { sending, sent, error }

class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isRead;
  final String? replyToId;
  final String? replyToContent;
  final String? imageUrl;
  final String? sharedArtworkId;
  final String? sharedProfileId;
  final Map<String, List<String>> reactions;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final DateTime? deletedAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isRead = false,
    this.replyToId,
    this.replyToContent,
    this.imageUrl,
    this.sharedArtworkId,
    this.sharedProfileId,
    this.reactions = const {},
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.deletedAt,
  });

  /// Hidden only for users who chose "Delete for me".
  /// `deletedForEveryone` messages stay visible as a tombstone for everyone.
  bool isHiddenFor(String userId) => deletedFor.contains(userId);

  factory MessageModel.fromMap(Map<String, dynamic> data, String id) {
    Map<String, List<String>> parsedReactions = {};
    if (data['reactions'] != null) {
      final Map<String, dynamic> rawReactions = data['reactions'] is String
          ? {} // fallback if someone stored string by mistake
          : Map<String, dynamic>.from(data['reactions']);
      rawReactions.forEach((key, value) {
        if (value is List) {
          parsedReactions[key] = List<String>.from(value);
        }
      });
    }

    return MessageModel(
      id: id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: MessageStatus.sent, // Messages from DB are considered sent
      isRead: data['isRead'] == true,
      replyToId: data['replyToId'] as String?,
      replyToContent: data['replyToContent'] as String?,
      imageUrl: data['imageUrl'] as String?,
      sharedArtworkId: data['sharedArtworkId'] as String?,
      sharedProfileId: data['sharedProfileId'] as String?,
      reactions: parsedReactions,
      deletedFor: data['deletedFor'] is List
          ? List<String>.from(data['deletedFor'])
          : const [],
      deletedForEveryone: data['deletedForEveryone'] == true,
      deletedAt: data['deletedAt'] != null
          ? DateTime.tryParse(data['deletedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'senderId': senderId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };

    if (replyToId != null) map['replyToId'] = replyToId;
    if (replyToContent != null) map['replyToContent'] = replyToContent;
    if (imageUrl != null) map['imageUrl'] = imageUrl;
    if (sharedArtworkId != null) map['sharedArtworkId'] = sharedArtworkId;
    if (sharedProfileId != null) map['sharedProfileId'] = sharedProfileId;
    map['reactions'] = reactions;
    if (deletedFor.isNotEmpty) map['deletedFor'] = deletedFor;
    if (deletedForEveryone) map['deletedForEveryone'] = deletedForEveryone;
    if (deletedAt != null) map['deletedAt'] = deletedAt!.toIso8601String();

    return map;
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isRead,
    String? replyToId,
    String? replyToContent,
    String? imageUrl,
    String? sharedArtworkId,
    String? sharedProfileId,
    Map<String, List<String>>? reactions,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    DateTime? deletedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      imageUrl: imageUrl ?? this.imageUrl,
      sharedArtworkId: sharedArtworkId ?? this.sharedArtworkId,
      sharedProfileId: sharedProfileId ?? this.sharedProfileId,
      reactions: reactions ?? this.reactions,
      deletedFor: deletedFor ?? this.deletedFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
