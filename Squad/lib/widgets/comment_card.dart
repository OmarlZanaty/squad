import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../utils/app_localizations.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;
  final bool isOwnComment;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final int depth;
  final String? replyToName;
  final String? replyToPreview;
  final VoidCallback? onReply;
  final VoidCallback? onViewReplies; // optional
  static const String baseUrl = 'http://187.124.37.68:3000';

  const CommentCard({
    Key? key,
    required this.comment,
    required this.isOwnComment,
    this.onDelete,
    this.onEdit,
    this.onLike,
    this.onDislike,
    this.onReply,
    this.replyToPreview,
    this.depth = 0,
    this.onViewReplies,
    this.replyToName,
  }) : super(key: key);

  String _getPhotoUrl(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return '';
    if (photoPath.startsWith('http')) return photoPath;
    return '$baseUrl$photoPath';
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    // ✅ limit indentation so UI doesn't go crazy
    final safeDepth = depth.clamp(0, 5);
    final leftPad = 16.0 + (safeDepth * 14.0);

    final isReply = safeDepth > 0;

    // Small UX: show "Replying to X" + optional preview
    final hasReplyMeta = isReply && (replyToName != null && replyToName!.isNotEmpty);

    // Small UX: short preview text (if provided)
    String? preview = replyToPreview;
    if (preview != null) {
      preview = preview.trim();
      if (preview.isEmpty) preview = null;
      if (preview != null && preview.length > 70) {
        preview = '${preview.substring(0, 70)}…';
      }
    }

    final replyLineColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final replyChipBg = isDark ? const Color(0xFF2A2A2A) : Colors.grey[100];
    final replyChipText = isDark ? Colors.grey[300] : Colors.grey[700];

    return Container(
      padding: EdgeInsets.only(left: leftPad, right: 16, top: 12, bottom: 12),
      decoration: BoxDecoration(
        // ✅ vertical thread line for replies
        border: isReply
            ? Border(
          left: BorderSide(color: replyLineColor!, width: 2),
        )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _getUserTypeColor(comment.userType),
            backgroundImage: comment.userPhoto != null && comment.userPhoto!.isNotEmpty
                ? NetworkImage(_getPhotoUrl(comment.userPhoto))
                : null,
            child: (comment.userPhoto == null || comment.userPhoto!.isEmpty)
                ? Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Reply meta (small UX upgrade)
                if (hasReplyMeta)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: replyChipBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc?.tr('replying_to') ?? 'Replying to'} $replyToName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: replyChipText,
                          ),
                        ),
                        if (preview != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '“$preview”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // header row: name + time + menu
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      comment.getTimeAgo(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (isOwnComment && (onDelete != null || onEdit != null)) ...[
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit' && onEdit != null) onEdit!();
                          if (v == 'delete' && onDelete != null) onDelete!();
                        },
                        itemBuilder: (context) => [
                          if (onEdit != null)
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Text(loc?.tr('edit') ?? 'Edit'),
                                ],
                              ),
                            ),
                          if (onDelete != null)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(loc?.tr('delete') ?? 'Delete'),
                                ],
                              ),
                            ),
                        ],
                        child: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // comment text
                Text(
                  comment.commentText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                // reactions + reply row
                Row(
                  children: [
                    _ReactionButton(
                      icon: Icons.thumb_up_alt_outlined,
                      activeIcon: Icons.thumb_up_alt,
                      count: comment.likesCount,
                      isActive: comment.myReaction == CommentReaction.like,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 12),
                    _ReactionButton(
                      icon: Icons.thumb_down_alt_outlined,
                      activeIcon: Icons.thumb_down_alt,
                      count: comment.dislikesCount,
                      isActive: comment.myReaction == CommentReaction.dislike,
                      onTap: onDislike,
                    ),
                    const SizedBox(width: 12),

                    // ✅ Reply button + micro UX
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: (onReply == null)
                                  ? (isDark ? Colors.grey[600] : Colors.grey[400])
                                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              loc?.tr('reply') ?? 'Reply',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: (onReply == null)
                                    ? (isDark ? Colors.grey[600] : Colors.grey[400])
                                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ),
                            // ✅ tiny hint for better UX
                            if (onReply != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                loc?.tr('tap') ?? 'tap',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // ✅ optional: show replies count (only if there are replies)
                    if (comment.repliesCount > 0)
                      InkWell(
                        onTap: onViewReplies, // you can expand/collapse later
                        child: Text(
                          '${loc?.tr('replies') ?? 'Replies'} (${comment.repliesCount})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }




  Color _getUserTypeColor(String userType) {
    switch (userType.toLowerCase()) {
      case 'player':
        return Colors.blue;
      case 'coach':
        return Colors.green;
      case 'parent':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  const _ReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 18,
            color: isActive ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              color: isActive ? Colors.blue : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
