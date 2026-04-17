class AppNotification {
  final int id;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  // optional actor data (depends on backend)
  final int? actorId;
  final String? actorName;
  final String? actorPhoto;

  // optional target data (post, chat, etc.)
  final int? postId;
  final int? chatId;

  AppNotification({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.actorPhoto,
    this.postId,
    this.chatId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return AppNotification(
      id: (json['id'] ?? 0) is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      type: (json['type'] ?? '').toString(),
      isRead: json['is_read'] == true || json['isRead'] == true,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      actorId: json['actor_id'] is int ? json['actor_id'] : int.tryParse('${json['actor_id']}'),
      actorName: json['actor_name']?.toString(),
      actorPhoto: json['actor_photo']?.toString(),
      postId: json['post_id'] is int ? json['post_id'] : int.tryParse('${json['post_id']}'),
      chatId: json['chat_id'] is int ? json['chat_id'] : int.tryParse('${json['chat_id']}'),
    );
  }
}
