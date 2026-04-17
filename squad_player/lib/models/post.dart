class Post {
  final int id;
  final int userId;
  final String userName;
  final String? userPhoto;
  final String? country;
  final String? position;
  final String mediaType;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
  int likeCount;
  int loveCount;
  int talentCount;
  int amazingCount;
  String? userReaction;
  final String? authorType;
  bool isHidden; // Changed from final to mutable
  bool isPinned; // Changed from final to mutable
  int commentCount;
  final String? status;
  int views; // Added views field
  final String? thumbnailUrl;
  final String? lowQualityUrl;
  final String? mediumQualityUrl;
  final String? highQualityUrl;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.country,
    this.position,
    required this.mediaType,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
    this.likeCount = 0,
    this.loveCount = 0,
    this.talentCount = 0,
    this.amazingCount = 0,
    this.userReaction,
    this.authorType,
    this.isHidden = false,
    this.isPinned = false,
    this.commentCount = 0,
    this.status,
    this.views = 0, // Default to 0
    this.thumbnailUrl,
    this.lowQualityUrl,
    this.mediumQualityUrl,
    this.highQualityUrl,
  });

  String get userType {
    if (authorType != null) {
      return authorType!;
    }
    if (country != null && position != null) {
      return 'player';
    } else if (country == null && position == null) {
      return 'scout';
    }
    return 'guest';
  }

  // Added reactions getter for easy access
  Map<String, int> get reactions {
    return {
      'like': likeCount,
      'love': loveCount,
      'talent': talentCount,
      'amazing': amazingCount,
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    // DEBUG LOG: Print raw JSON status
    // print('Post.fromJson ID: ${json['id']}, Raw Status: ${json['status']}, Post Status: ${json['post_status']}');

    return Post(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['author_name'] ?? 'Unknown',
      userPhoto: json['author_photo'],
      country: json['country'],
      position: json['position'],
      mediaType: json['media_type'] ?? 'image',
      mediaUrl: json['media_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      lowQualityUrl: json['low_quality_url'] as String?,
      mediumQualityUrl: json['medium_quality_url'] as String?,
      highQualityUrl: json['high_quality_url'] as String?,
      caption: json['caption'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      likeCount: int.tryParse(json['like_count']?.toString() ?? '0') ?? 0,
      loveCount: int.tryParse(json['love_count']?.toString() ?? '0') ?? 0,
      talentCount: int.tryParse(json['talent_count']?.toString() ?? '0') ?? 0,
      amazingCount: int.tryParse(json['amazing_count']?.toString() ?? '0') ?? 0,
      userReaction: json['user_reaction'],
      authorType: json['author_type'],
      isHidden: json['is_hidden_by_me'] == 1 || json['is_hidden_by_me'] == true || json['is_hidden'] == 1 || json['is_hidden'] == true,
      isPinned: json['is_pinned'] == 1 || json['is_pinned'] == true,
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
      // DEBUG: Fallback to 'STATUS_MISSING' if null
      status: (json['post_status'] ?? json['status'])?.toString() ?? 'STATUS_MISSING',
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0, // Parse views
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'author_name': userName,
      'author_photo': userPhoto,
      'country': country,
      'position': position,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'like_count': likeCount,
      'love_count': loveCount,
      'talent_count': talentCount,
      'amazing_count': amazingCount,
      'user_reaction': userReaction,
      'author_type': authorType,
      'is_hidden': isHidden,
      'is_pinned': isPinned,
      'comment_count': commentCount,
      'status': status,
      'views': views,
      'thumbnail_url': thumbnailUrl,
      'low_quality_url': lowQualityUrl,
      'medium_quality_url': mediumQualityUrl,
      'high_quality_url': highQualityUrl,
    };
  }

  Post copyWith({
    int? views,
    int? likeCount,
    int? loveCount,
    int? talentCount,
    int? amazingCount,
    int? commentCount,
    String? userReaction,
    bool? isPinned,
    bool? isHidden,
    String? status,
    String? mediaType,
    String? mediaUrl,
    String? caption,
    String? authorType,
    String? userPhoto,
    String? country,
    String? position,
    String? userName,
    int? userId,
    String? thumbnailUrl,
    String? lowQualityUrl,
    String? mediumQualityUrl,
    String? highQualityUrl,
  }) {
    return Post(
      id: id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      country: country ?? this.country,
      position: position ?? this.position,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      loveCount: loveCount ?? this.loveCount,
      talentCount: talentCount ?? this.talentCount,
      amazingCount: amazingCount ?? this.amazingCount,
      userReaction: userReaction ?? this.userReaction,
      authorType: authorType ?? this.authorType,
      isHidden: isHidden ?? this.isHidden,
      isPinned: isPinned ?? this.isPinned,
      commentCount: commentCount ?? this.commentCount,
      status: status ?? this.status,
      views: views ?? this.views,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      lowQualityUrl: lowQualityUrl ?? this.lowQualityUrl,
      mediumQualityUrl: mediumQualityUrl ?? this.mediumQualityUrl,
      highQualityUrl: highQualityUrl ?? this.highQualityUrl,
    );
  }

  void incrementReaction(String reactionType) {
    switch (reactionType) {
      case "like":
        likeCount++;
        break;
      case "love":
        loveCount++;
        break;
      case "talent":
        talentCount++;
        break;
      case "amazing":
        amazingCount++;
        break;
    }
  }

  void decrementReaction(String reactionType) {
    switch (reactionType) {
      case "like":
        likeCount--;
        break;
      case "love":
        loveCount--;
        break;
      case "talent":
        talentCount--;
        break;
      case "amazing":
        amazingCount--;
        break;
    }
  }
}
