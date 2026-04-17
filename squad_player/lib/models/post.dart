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
    };
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
