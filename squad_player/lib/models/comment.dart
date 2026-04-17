import 'package:flutter/cupertino.dart';
import '../utils/app_localizations.dart';

class Comment {
  final int id;
  final int postId;
  final int userId;
  final String commentText;
  final DateTime createdAt;
  final String userName;
  final String? userPhoto;
  final String userType;

  /// Reply support: null = root comment, otherwise this is reply to another comment id
  final int? parentCommentId;

  /// backend: "active" | "hidden"
  final String status;

  /// backend: 0/1 sometimes exists
  final bool isHiddenFlag;

  /// Client-side nested replies (built by app)
  final List<Comment> replies;

  bool get isHidden {
    final s = status.trim().toLowerCase();
    return s == 'hidden' || isHiddenFlag == true;
  }

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.userName,
    this.userPhoto,
    required this.userType,
    this.parentCommentId,
    required this.status,
    required this.isHiddenFlag,
    List<Comment>? replies,
  }) : replies = replies ?? [];

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? 'active').toString();

    final isHiddenRaw = json['is_hidden'];
    final isHiddenFlag = isHiddenRaw == 1 || isHiddenRaw == true || isHiddenRaw == "1";

    // Accept both snake and camel just in case
    final parentRaw = json['parent_comment_id'] ?? json['parentCommentId'] ?? json['parent_id'] ?? json['parentId'];
    final parentCommentId = (parentRaw == null || parentRaw.toString().isEmpty) ? null : _toInt(parentRaw);

    return Comment(
      id: _toInt(json['id']),
      postId: _toInt(json['post_id'] ?? json['postId']),
      userId: _toInt(json['user_id'] ?? json['userId']),
      commentText: (json['comment_text'] ?? json['commentText'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      userName: (json['user_name'] ?? json['userName'] ?? '').toString(),
      userPhoto: json['user_photo']?.toString() ?? json['userPhoto']?.toString(),
      userType: (json['user_type'] ?? json['userType'] ?? '').toString(),
      parentCommentId: parentCommentId,
      status: statusRaw,
      isHiddenFlag: isHiddenFlag,
      replies: const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'comment_text': commentText,
      'created_at': createdAt.toIso8601String(),
      'user_name': userName,
      'user_photo': userPhoto,
      'user_type': userType,
      'parent_comment_id': parentCommentId,
      'status': status,
      'is_hidden': isHidden ? 1 : 0,
    };
  }
}

extension CommentTimeAgo on Comment {
  String getTimeAgoLocalized(BuildContext context) {
    final tr = AppLocalizations.of(context);
    String t(String key, String fallback) => tr?.tr(key) ?? fallback;

    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return t('time_just_now', 'Just now');
    } else if (difference.inMinutes < 60) {
      return (t('time_minutes_ago', '{m}m ago')).replaceAll('{m}', '${difference.inMinutes}');
    } else if (difference.inHours < 24) {
      return (t('time_hours_ago', '{h}h ago')).replaceAll('{h}', '${difference.inHours}');
    } else if (difference.inDays < 7) {
      return (t('time_days_ago', '{d}d ago')).replaceAll('{d}', '${difference.inDays}');
    } else if (difference.inDays < 30) {
      final w = (difference.inDays / 7).floor();
      return (t('time_weeks_ago', '{w}w ago')).replaceAll('{w}', '$w');
    } else if (difference.inDays < 365) {
      final mo = (difference.inDays / 30).floor();
      return (t('time_months_ago', '{mo}mo ago')).replaceAll('{mo}', '$mo');
    } else {
      final y = (difference.inDays / 365).floor();
      return (t('time_years_ago', '{y}y ago')).replaceAll('{y}', '$y');
    }
  }
}
