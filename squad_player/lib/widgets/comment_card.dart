import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../utils/app_localizations.dart';
import 'package:squad_player/config/app_config.dart';

enum CommentAction { delete, hide, unhide, report }

class CommentCard extends StatelessWidget {
  final Comment comment;

  final bool isOwnComment;
  final bool isPostOwner;

  final bool isHidden;
  final VoidCallback? onUserTap;
  // Reply feature
  final VoidCallback? onReply;
  final String? replyToName;
  final String? replyToPreview;
  final int depth; // 0=root, 1=reply, 2=reply to reply...

  final VoidCallback? onDelete;
  final VoidCallback? onHide;
  final VoidCallback? onUnhide;
  final VoidCallback? onReport;

  bool get _canReport => !isOwnComment;

  const CommentCard({
    Key? key,
    required this.comment,
    required this.isOwnComment,
    required this.isPostOwner,
    this.isHidden = false,
    this.onReply,
    this.replyToName,
    this.replyToPreview,
    this.depth = 0,
    this.onDelete,
    this.onHide,
    this.onUnhide,
    this.onReport,
    this.onUserTap,
  }) : super(key: key);

  String _t(BuildContext context, String key, String fallback) {
    final tr = AppLocalizations.of(context);
    return tr?.tr(key) ?? fallback;
  }

  Future<bool> _confirm(
      BuildContext context, {
        required String titleKey,
        required String bodyKey,
        required String confirmKey,
        required String cancelKey,
        bool danger = false,
      }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t(ctx, titleKey, '')),
          content: Text(_t(ctx, bodyKey, '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t(ctx, cancelKey, '')),
            ),
            ElevatedButton(
              style: danger ? ElevatedButton.styleFrom(backgroundColor: Colors.red) : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t(ctx, confirmKey, '')),
            ),
          ],
        );
      },
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasMenu =
        (onDelete != null) || (onHide != null) || (onUnhide != null) || (onReport != null);

    final leftIndent = (depth * 14).clamp(0, 42).toDouble(); // tighter indent

    // compact styles
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
      height: 1.0,
      color: isDark ? Colors.white : Colors.black87,
    );

    final timeStyle = TextStyle(
      fontSize: 10.5,
      height: 1.0,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
    );

    final bodyStyle = TextStyle(
      fontSize: 12.5,
      height: 1.15,
      color: isDark ? Colors.grey[200] : Colors.black87,
    );

    String short(String s, {int max = 34}) {
      final x = s.trim();
      if (x.length <= max) return x;
      return '${x.substring(0, max)}…';
    }

    return Padding(
      padding: EdgeInsets.only(left: 8 + leftIndent, right: 8, top: 2, bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242424) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onUserTap,
              borderRadius: BorderRadius.circular(999),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: _getUserTypeColor(comment.userType),
                backgroundImage: (comment.userPhoto != null && comment.userPhoto!.isNotEmpty)
                    ? NetworkImage(AppConfig.getPhotoUrl(comment.userPhoto))
                    : null,
                child: (comment.userPhoto == null || comment.userPhoto!.isEmpty)
                    ? Text(
                  comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: onUserTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              comment.userName,
                              style: nameStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(comment.getTimeAgoLocalized(context), style: timeStyle),

                      if (isHidden) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _t(context, 'comment_hidden_badge', 'Hidden'),
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],

                      if (hasMenu) ...[
                        const SizedBox(width: 2),
                        SizedBox(
                          width: 28,
                          height: 24,
                          child: PopupMenuButton<CommentAction>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                            onSelected: (action) async {
                              switch (action) {
                                case CommentAction.delete:
                                  if (onDelete == null) return;
                                  final ok = await _confirm(
                                    context,
                                    titleKey: 'comment_confirm_delete_title',
                                    bodyKey: 'comment_confirm_delete_body',
                                    confirmKey: 'action_delete',
                                    cancelKey: 'action_cancel',
                                    danger: true,
                                  );
                                  if (ok) onDelete!.call();
                                  break;

                                case CommentAction.hide:
                                  if (onHide == null) return;
                                  final ok = await _confirm(
                                    context,
                                    titleKey: 'comment_confirm_hide_title',
                                    bodyKey: 'comment_confirm_hide_body',
                                    confirmKey: 'action_hide',
                                    cancelKey: 'action_cancel',
                                  );
                                  if (ok) onHide!.call();
                                  break;

                                case CommentAction.unhide:
                                  if (onUnhide == null) return;
                                  final ok = await _confirm(
                                    context,
                                    titleKey: 'comment_confirm_unhide_title',
                                    bodyKey: 'comment_confirm_unhide_body',
                                    confirmKey: 'action_unhide',
                                    cancelKey: 'action_cancel',
                                  );
                                  if (ok) onUnhide!.call();
                                  break;

                                case CommentAction.report:
                                  if (onReport == null) return;
                                  final ok = await _confirm(
                                    context,
                                    titleKey: 'comment_confirm_report_title',
                                    bodyKey: 'comment_confirm_report_body',
                                    confirmKey: 'action_report',
                                    cancelKey: 'action_cancel',
                                  );
                                  if (ok) onReport!.call();
                                  break;
                              }
                            },
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<CommentAction>>[];

                              if (onDelete != null) {
                                items.add(
                                  PopupMenuItem(
                                    value: CommentAction.delete,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        const SizedBox(width: 10),
                                        Text(_t(context, 'comment_action_delete', 'Delete')),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (onHide != null) {
                                items.add(
                                  PopupMenuItem(
                                    value: CommentAction.hide,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.visibility_off_outlined, size: 18),
                                        const SizedBox(width: 10),
                                        Text(_t(context, 'comment_action_hide', 'Hide')),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (onUnhide != null) {
                                items.add(
                                  PopupMenuItem(
                                    value: CommentAction.unhide,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.visibility_outlined, size: 18),
                                        const SizedBox(width: 10),
                                        Text(_t(context, 'comment_action_unhide', 'Unhide')),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (onReport != null && _canReport) {
                                items.add(
                                  PopupMenuItem(
                                    value: CommentAction.report,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.flag_outlined, size: 18),
                                        const SizedBox(width: 10),
                                        Text(_t(context, 'comment_action_report', 'Report')),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return items;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),

                  // reply meta
                  if (replyToName != null && replyToName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_t(context, 'replying_to', 'Replying to')} $replyToName'
                          '${(replyToPreview != null && replyToPreview!.trim().isNotEmpty) ? ': ${short(replyToPreview!)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.0,
                        color: isDark ? Colors.grey[350] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  Text(comment.commentText, style: bodyStyle),

                  if (onReply != null) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply, size: 15, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              _t(context, 'comment_action_reply', 'Reply'),
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.0,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  String _short(String s) {
    if (s.length <= 40) return s;
    return s.substring(0, 40) + '…';
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
