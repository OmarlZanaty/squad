import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/app_localizations.dart';
import 'comment_card.dart';
import 'package:squad_player/screens/player_profile_screen.dart';

class CommentsBottomSheet extends StatefulWidget {
  final int postId;
  final String token;
  final int postOwnerId;
  final int currentUserId;

  const CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.token,
    required this.postOwnerId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  // Static cache to preserve comments across widget recreations
  static final Map<int, List<Comment>> _commentsCache = {};

  final TextEditingController _commentController = TextEditingController();

  // IMPORTANT: keep raw list as loaded from API (flat list)
  List<Comment> _flatComments = [];

  bool _isLoading = true;
  bool _isSending = false;

  // Reply feature
  Comment? _replyTo;

  bool get _isPostOwner => widget.currentUserId == widget.postOwnerId;

  String t(String key, String fallback) {
    final tr = AppLocalizations.of(context);
    return tr?.tr(key) ?? fallback;
  }

  void _openUserProfile(int userId) {
    // Optional: close bottom sheet first
    // Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(userId: userId),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (_commentsCache.containsKey(widget.postId) && _commentsCache[widget.postId]!.isNotEmpty) {
      setState(() {
        _flatComments = List<Comment>.from(_commentsCache[widget.postId]!);
        _isLoading = false;
      });

      // background refresh
      _loadComments(forceRefresh: true);
    } else {
      _loadComments(forceRefresh: true);
    }
  }

  // ---------------------------
  // Reply helpers
  // ---------------------------

  void _setReplyTo(Comment c) {
    setState(() {
      _replyTo = c;
    });
  }

  void _clearReplyTo() {
    setState(() {
      _replyTo = null;
    });
  }

  // Build a tree from flat comments using parentCommentId
  List<_TreeNode> _buildTree(List<Comment> flat) {
    final byId = <int, _TreeNode>{};

    for (final c in flat) {
      byId[c.id] = _TreeNode(comment: c);
    }

    final roots = <_TreeNode>[];

    for (final node in byId.values) {
      final pid = node.comment.parentCommentId;
      if (pid == null || pid == 0) {
        roots.add(node);
      } else {
        final parent = byId[pid];
        if (parent != null) {
          parent.children.add(node);
        } else {
          // orphan -> treat as root
          roots.add(node);
        }
      }
    }

    // Optional: keep order stable (same as backend order)
    // We keep the same order of appearance in flat list.
    final orderIndex = <int, int>{};
    for (int i = 0; i < flat.length; i++) {
      orderIndex[flat[i].id] = i;
    }

    int cmp(_TreeNode a, _TreeNode b) {
      final ia = orderIndex[a.comment.id] ?? 999999;
      final ib = orderIndex[b.comment.id] ?? 999999;
      return ia.compareTo(ib);
    }

    void sortRec(List<_TreeNode> list) {
      list.sort(cmp);
      for (final n in list) {
        sortRec(n.children);
      }
    }

    sortRec(roots);
    return roots;
  }

  // ---------------------------
  // Existing features
  // ---------------------------

  void _reportComment(int commentId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('comment_report_title', 'Report comment')),
        content: Text(t('comment_report_body', 'Do you want to report this comment?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('action_cancel', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('comment_reported', 'Reported. Thank you.'))),
              );
            },
            child: Text(t('action_report', 'Report')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadComments({bool forceRefresh = false}) async {
    if (!forceRefresh && _commentsCache.containsKey(widget.postId) && _commentsCache[widget.postId]!.isNotEmpty) {
      setState(() {
        _flatComments = List<Comment>.from(_commentsCache[widget.postId]!);
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getComments(
        token: widget.token,
        postId: widget.postId,
      );

      List<Comment> comments = [];

      if (response is List) {
        comments = response.map((json) => Comment.fromJson(json as Map<String, dynamic>)).toList();
      } else if (response is Map && response['comments'] != null) {
        comments = (response['comments'] as List)
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      setState(() {
        _flatComments = comments;
        _commentsCache[widget.postId] = List<Comment>.from(comments);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('comments_load_failed', 'Failed to load comments')}: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final parentId = _replyTo?.id;

      final response = await ApiService.addComment(
        token: widget.token,
        postId: widget.postId,
        content: text,
        parentCommentId: parentId, // ✅ reply support
      );

      if (response is Map) {
        Comment? newComment;

        if (response['comment'] != null) {
          newComment = Comment.fromJson(response['comment'] as Map<String, dynamic>);
        } else if (response['id'] != null) {
          newComment = Comment.fromJson(response as Map<String, dynamic>);
        }

        if (newComment != null) {
          setState(() {
            // Add to flat list (tree is derived)
            _flatComments.insert(0, newComment!);
            _commentsCache[widget.postId] = List<Comment>.from(_flatComments);

            _commentController.clear();
            _isSending = false;
            _replyTo = null; // ✅ clear reply mode after send
          });

          return;
        }

        setState(() => _isSending = false);
      } else {
        setState(() => _isSending = false);
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('comment_add_failed', 'Failed to add comment')}: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await ApiService.deleteComment(
        token: widget.token,
        commentId: commentId,
      );

      setState(() {
        // Remove target + its replies (flat remove by parent chain)
        final toRemove = <int>{commentId};

        bool changed = true;
        while (changed) {
          changed = false;
          for (final c in _flatComments) {
            if (c.parentCommentId != null && toRemove.contains(c.parentCommentId)) {
              if (!toRemove.contains(c.id)) {
                toRemove.add(c.id);
                changed = true;
              }
            }
          }
        }

        _flatComments.removeWhere((c) => toRemove.contains(c.id));
        _commentsCache[widget.postId] = List<Comment>.from(_flatComments);

        // If we were replying to a deleted comment -> clear reply
        if (_replyTo != null && toRemove.contains(_replyTo!.id)) {
          _replyTo = null;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('comment_deleted', 'Comment deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('comment_delete_failed', 'Failed to delete comment')}: $e')),
        );
      }
    }
  }

  Future<void> _hideComment(int commentId) async {
    try {
      await ApiService.hideComment(token: widget.token, commentId: commentId);
      await _loadComments(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('comment_hidden', 'Comment hidden'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('comment_hide_failed', 'Failed to hide comment')}: $e')),
        );
      }
    }
  }

  Future<void> _unhideComment(int commentId) async {
    try {
      await ApiService.unhideComment(token: widget.token, commentId: commentId);
      await _loadComments(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('comment_unhidden', 'Comment unhidden'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('comment_unhide_failed', 'Failed to unhide comment')}: $e')),
        );
      }
    }
  }

  // ---------------------------
  // Rendering
  // ---------------------------

  Widget _buildNode(_TreeNode node, {required int depth}) {
    final comment = node.comment;

    // Apply hidden filtering rule:
    // - Post owner sees all
    // - Others see only not hidden
    if (!_isPostOwner && comment.isHidden) {
      return const SizedBox.shrink();
    }

    final isHidden = comment.isHidden;
    final isOwnComment = comment.userId == widget.currentUserId;
    final isPostOwner = _isPostOwner;

    final canDelete = isOwnComment || isPostOwner;
    final canReport = !isOwnComment;

    // If it’s hidden and user is NOT post owner -> it won’t render anyway.
    // Reply allowed only if comment is visible.
    final canReply = true;

    // For reply meta: show the parent info if this is a reply
    String? replyToName;
    String? replyToPreview;
    if (comment.parentCommentId != null && comment.parentCommentId != 0) {
      final parent = _flatComments.firstWhere(
            (c) => c.id == comment.parentCommentId,
        orElse: () => Comment(
          id: 0,
          postId: widget.postId,
          userId: 0,
          commentText: '',
          createdAt: DateTime.now(),
          userName: '',
          userType: '',
          status: 'active',
          isHiddenFlag: false,
          parentCommentId: null,
        ),
      );

      if (parent.id != 0) {
        replyToName = parent.userName;
        replyToPreview = parent.commentText;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommentCard(
          comment: comment,
          isOwnComment: isOwnComment,
          isPostOwner: isPostOwner,
          isHidden: isHidden,
          depth: depth,
          replyToName: replyToName,
          replyToPreview: replyToPreview,
          onReply: canReply ? () => _setReplyTo(comment) : null,
          onDelete: canDelete ? () => _deleteComment(comment.id) : null,
          onHide: (isPostOwner && !isHidden && !isOwnComment) ? () => _hideComment(comment.id) : null,
          onUnhide: (isPostOwner && isHidden) ? () => _unhideComment(comment.id) : null,
          onReport: canReport ? () => _reportComment(comment.id) : null,
          onUserTap: () => _openUserProfile(comment.userId),
        ),

        // Children (replies)
        for (final child in node.children) _buildNode(child, depth: (depth + 1).clamp(0, 3)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build visible count (for header) based on flat list + hidden rule.
    final visibleCount = _isPostOwner ? _flatComments.length : _flatComments.where((c) => !c.isHidden).length;

    final roots = _buildTree(_flatComments);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)?.tr('comments') ?? 'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($visibleCount)',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comments List
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (visibleCount == 0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)?.tr('no_comments') ?? 'No comments yet',
                          style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Render full tree
                return ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  children: [
                    for (final root in roots) _buildNode(root, depth: 0),
                  ],
                );
              },
            ),
          ),

          // Reply bar + input
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTo != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${t('replying_to', 'Replying to')} ${_replyTo!.userName}: "${_replyTo!.commentText}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.grey[200] : Colors.grey[800], fontSize: 12),
                              ),
                            ),
                            IconButton(
                              onPressed: _clearReplyTo,
                              icon: Icon(Icons.close, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: _replyTo != null
                                  ? (AppLocalizations.of(context)?.tr('write_reply') ?? 'Write a reply...')
                                  : (AppLocalizations.of(context)?.tr('write_comment') ?? 'Write a comment...'),
                              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500]),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _addComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSending
                            ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                            : IconButton(
                          onPressed: _addComment,
                          icon: const Icon(Icons.send),
                          color: Colors.blue,
                          iconSize: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

// Simple tree wrapper
class _TreeNode {
  final Comment comment;
  final List<_TreeNode> children;
  _TreeNode({required this.comment}) : children = [];
}
