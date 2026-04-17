
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
  final int likeCount;
  final int loveCount;
  final int talentCount;
  final int amazingCount;
  final int? commentCount;
  final String? userReaction;
  final String? authorType;
  final bool isPinned;
  final bool isHidden;
  final int viewCount;
  final int views;
  final String status;
  final String? type; // "video" / "image" / "text" ... (depends on backend)
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
    this.commentCount,
    this.userReaction,
    this.authorType,
    this.isPinned = false,
    this.isHidden = false,
    this.viewCount = 0,
    this.views = 0,
    this.status = 'active',
    this.type,
    this.thumbnailUrl,
    this.lowQualityUrl,      // ✅ ADD
    this.mediumQualityUrl,   // ✅ ADD
    this.highQualityUrl,     // ✅ ADD
  });

  // Determine user type based on author_type or fallback to country/position
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

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['author_name'] ?? 'Unknown',
      userPhoto: json['author_photo'],
      country: json['country'],
      position: json['position'],
      mediaType: json['media_type'] ?? 'image',
      mediaUrl: json['media_url'] ?? '',
      caption: json['caption'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      likeCount: int.tryParse(json['like_count']?.toString() ?? '0') ?? 0,
      loveCount: int.tryParse(json['love_count']?.toString() ?? '0') ?? 0,
      talentCount: int.tryParse(json['talent_count']?.toString() ?? '0') ?? 0,
      amazingCount: int.tryParse(json['amazing_count']?.toString() ?? '0') ?? 0,
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '0'),
      userReaction: json['user_reaction'],
      authorType: json['author_type'],
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      isHidden: json['is_hidden'] == true || json['is_hidden'] == 1,
      viewCount: int.tryParse(json['view_count']?.toString() ?? '0') ?? 0,
      views: int.tryParse(json['views']?.toString() ?? json['view_count']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'active',
      type: json['type'] ?? json['post_type'] ?? json['media_type'],
      lowQualityUrl: json['low_quality_url'] as String?,
      mediumQualityUrl: json['medium_quality_url'] as String?,
      highQualityUrl: json['high_quality_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
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
      'comment_count': commentCount,
      'user_reaction': userReaction,
      'author_type': authorType,
      'is_pinned': isPinned ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'view_count': viewCount,
      'views': views,
      'status': status,
      'type': type,
    };
  }

  Post copyWith({
    int? views,
    int? viewCount,
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
    String? type,
    String? authorType,
    String? userPhoto,
    String? country,
    String? position,
    String? userName,
    int? userId,
    String? thumbnailUrl,       // ✅ ADD
    String? lowQualityUrl,      // ✅ ADD
    String? mediumQualityUrl,   // ✅ ADD
    String? highQualityUrl,     // ✅ ADD

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
      commentCount: commentCount ?? this.commentCount,
      userReaction: userReaction ?? this.userReaction,

      authorType: authorType ?? this.authorType,

      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,

      viewCount: viewCount ?? this.viewCount,
      views: views ?? this.views,

      status: status ?? this.status,
      type: type ?? this.type,

      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,       // ✅ ADD
      lowQualityUrl: lowQualityUrl ?? this.lowQualityUrl,    // ✅ ADD
      mediumQualityUrl: mediumQualityUrl ?? this.mediumQualityUrl, // ✅ ADD
      highQualityUrl: highQualityUrl ?? this.highQualityUrl, // ✅ ADD
    );
  }


}
