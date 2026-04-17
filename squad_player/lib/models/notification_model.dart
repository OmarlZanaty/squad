class NotificationModel {
  final int id;
  final String type; // 'like', 'comment', 'follow', 'mention', 'system'
  final bool isRead;
  final DateTime createdAt;
  final int actorId;
  final String actorName;
  final String? actorPhoto;
  final int? postId;
  final String? postCaption;
  final String? postMedia;
  final String? postMediaType;

  NotificationModel({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.actorId,
    required this.actorName,
    this.actorPhoto,
    this.postId,
    this.postCaption,
    this.postMedia,
    this.postMediaType,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      type: json['type'],
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at']),
      actorId: json['actor_id'],
      actorName: json['actor_name'],
      actorPhoto: json['actor_photo'],
      postId: json['post_id'],
      postCaption: json['post_caption'],
      postMedia: json['post_media'],
      postMediaType: json['post_media_type'],
    );
  }
}
