import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

enum CommentReaction { like, dislike }

class Comment {
  final int id;
  final int postId;
  final int userId;
  final String commentText;
  final DateTime? createdAt;
  final String userName;
  final String? userPhoto;
  final String userType;

  int likesCount;
  int dislikesCount;
  CommentReaction? myReaction;

  // ✅ threaded
  final int? parentCommentId;
  final int repliesCount;
  List<Comment> replies = [];

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.userName,
    this.userPhoto,
    required this.userType,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.myReaction,
    this.parentCommentId,
    this.repliesCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    int? _toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    CommentReaction? _parseReaction(dynamic v) {
      final s = v?.toString().toLowerCase();
      if (s == 'like') return CommentReaction.like;
      if (s == 'dislike') return CommentReaction.dislike;
      return null;
    }

    return Comment(
      id: _toInt(json['id']) ?? 0,
      postId: _toInt(json['post_id'] ?? json['postId']) ?? 0,
      userId: _toInt(json['user_id'] ?? json['userId']) ?? 0,
      commentText: (json['comment_text'] ?? json['commentText'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null),
      userName: (json['user_name'] ?? json['userName'] ?? '').toString(),
      userPhoto: (json['user_photo'] ?? json['userPhoto'])?.toString(),
      userType: (json['user_type'] ?? json['userType'] ?? '').toString(),

      // ✅ THIS is the critical field for threading
      parentCommentId: _toInt(json['parent_comment_id'] ?? json['parentCommentId']),

      // ✅ counts: accept both snake_case and camelCase
      likesCount: _toInt(json['likes_count'] ?? json['likesCount']) ?? 0,
      dislikesCount: _toInt(json['dislikes_count'] ?? json['dislikesCount']) ?? 0,
      repliesCount: _toInt(json['replies_count'] ?? json['repliesCount']) ?? 0,

      // ✅ reaction: accept both keys
      myReaction: _parseReaction(json['my_reaction'] ?? json['myReaction']),
    );
  }


  // ✅ keep it ONCE فقط
  int get reactionsCount => likesCount + dislikesCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'user_name': userName,
      'user_photo': userPhoto,
      'user_type': userType,
      'comment_text': commentText,
      'created_at': createdAt?.toIso8601String(),
      'parent_comment_id': parentCommentId,
      'repliesCount': repliesCount,
    };
  }

  String getTimeAgo(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final now = DateTime.now();

    final created = createdAt;
    if (created == null) {
      return localizations?.tr('unknown_time') ?? '';
    }

    final difference = now.difference(created);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      final yearText = localizations?.tr(years == 1 ? 'year' : 'years') ?? '';
      final agoText = localizations?.tr('ago') ?? '';
      return '$agoText $years $yearText'.trim();
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      final monthText = localizations?.tr(months == 1 ? 'month' : 'months') ?? '';
      final agoText = localizations?.tr('ago') ?? '';
      return '$agoText $months $monthText'.trim();
    } else if (difference.inDays > 0) {
      final dayText = localizations?.tr(difference.inDays == 1 ? 'day' : 'days') ?? '';
      final agoText = localizations?.tr('ago') ?? '';
      return '$agoText ${difference.inDays} $dayText'.trim();
    } else if (difference.inHours > 0) {
      final hourText = localizations?.tr(difference.inHours == 1 ? 'hour' : 'hours') ?? '';
      final agoText = localizations?.tr('ago') ?? '';
      return '$agoText ${difference.inHours} $hourText'.trim();
    } else if (difference.inMinutes > 0) {
      final minuteText = localizations?.tr(difference.inMinutes == 1 ? 'minute' : 'minutes') ?? '';
      final agoText = localizations?.tr('ago') ?? '';
      return '$agoText ${difference.inMinutes} $minuteText'.trim();
    } else {
      return localizations?.tr('just_now') ?? '';
    }
  }
}
