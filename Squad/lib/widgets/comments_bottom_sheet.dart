// lib/widgets/comments_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/app_localizations.dart';
import 'comment_card.dart';

class CommentsBottomSheet extends StatefulWidget {
  final int postId;
  final String token;

  const CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.token,
  }) : super(key: key);

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

enum CommentsSort { newest, oldest, mostReacted, allComments }

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  // Static cache to preserve comments across widget recreations
  static final Map<int, List<Comment>> _commentsCache = {};

  final TextEditingController _commentController = TextEditingController();


  List<Comment> _comments = []; // ✅ ROOTS (tree)
  bool _isLoading = true;
  bool _isSending = false;
  List<Comment> _originalTree = []; // ✅ keeps backend order (no sort)

  int? _currentUserId;
  Comment? _replyTo;

  CommentsSort _sort = CommentsSort.mostReacted; // ✅ default

  List<Comment> _dedupeFlatById(List<Comment> flat) {
    final byId = <int, Comment>{};

    for (final c in flat) {
      final existing = byId[c.id];
      if (existing == null) {
        byId[c.id] = c;
        continue;
      }

      // Prefer the version that has a parentCommentId (threaded info)
      final keepExistingHasParent = existing.parentCommentId != null;
      final newHasParent = c.parentCommentId != null;

      if (!keepExistingHasParent && newHasParent) {
        byId[c.id] = c;
      } else if (keepExistingHasParent && !newHasParent) {
        // keep existing
      } else {
        // otherwise last wins (usually newer data)
        byId[c.id] = c;
      }
    }

    return byId.values.toList();
  }

  @override
  void initState() {
    super.initState();

    // load user id from token
    _loadCurrentUser();

    // load comments (cache first)
    if (_commentsCache.containsKey(widget.postId) &&
        _commentsCache[widget.postId]!.isNotEmpty) {
      setState(() {
        _comments = _commentsCache[widget.postId]!;
        _isLoading = false;
      });
    } else {
      _loadComments();
    }
  }

  // ==========================
  // Reply helpers
  // ==========================
  void _setReplyTo(Comment c) => setState(() => _replyTo = c);
  void _cancelReply() => setState(() => _replyTo = null);

  // ==========================
  // Sorting
  // ==========================
  String _sortLabel(BuildContext context, CommentsSort sort) {
    final loc = AppLocalizations.of(context);

    switch (sort) {
      case CommentsSort.newest:
        return loc?.tr('comments_sort_newest') ?? 'Newest';
      case CommentsSort.oldest:
        return loc?.tr('comments_sort_oldest') ?? 'Oldest';
      case CommentsSort.mostReacted:
        return loc?.tr('comments_sort_most_reacted') ?? 'Most reacted';
      case CommentsSort.allComments:
        return loc?.tr('comments_sort_all') ?? 'All comments';
    }
  }

  List<Comment> _cloneTree(List<Comment> nodes) {
    Comment cloneNode(Comment c) {
      final cloned = _cloneCommentWith(
        c,
        replies: [], // we will fill
        parentCommentId: c.parentCommentId,
      );
      cloned.replies = c.replies.map(cloneNode).toList();
      return cloned;
    }

    return nodes.map(cloneNode).toList();
  }

  void _applySort() {
    if (_comments.isEmpty) return;

    int byCreatedAtDesc(Comment a, Comment b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad); // newest first
    }

    int byCreatedAtAsc(Comment a, Comment b) => -byCreatedAtDesc(a, b);

    int byMostReacted(Comment a, Comment b) {
      // ✅ most likes + replies (as requested)
      final ar = (a.likesCount) + (a.repliesCount);
      final br = (b.likesCount) + (b.repliesCount);

      final cmp = br.compareTo(ar);
      if (cmp != 0) return cmp;

      // tie-breaker: newest first
      return byCreatedAtDesc(a, b);
    }

    void sortTree(List<Comment> nodes, int Function(Comment, Comment) cmp) {
      nodes.sort(cmp);
      for (final c in nodes) {
        if (c.replies.isNotEmpty) sortTree(c.replies, cmp);
      }
    }

    // ✅ All comments = restore original backend order (no sort)
    if (_sort == CommentsSort.allComments) {
      _comments = _cloneTree(_originalTree);
      _commentsCache[widget.postId] = List.from(_comments);
      return;
    }

    // otherwise sort
    final sorted = List<Comment>.from(_comments);

    switch (_sort) {
      case CommentsSort.newest:
        sortTree(sorted, byCreatedAtDesc);
        break;
      case CommentsSort.oldest:
        sortTree(sorted, byCreatedAtAsc);
        break;
      case CommentsSort.mostReacted:
        sortTree(sorted, byMostReacted);
        break;
      case CommentsSort.allComments:
        break;
    }

    _comments = sorted;
    _commentsCache[widget.postId] = List.from(_comments);
  }


  // ==========================
  // Render tree
  // ==========================
// ==========================
// Render tree (UPDATED)
// ==========================
  List<Widget> _renderCommentTree(
      List<Comment> items, {
        int depth = 0,
        Comment? parent, // ✅ NEW
      }) {
    final widgets = <Widget>[];

    for (final c in items) {
      final isOwn = _currentUserId != null &&
          c.userId.toString() == _currentUserId.toString();

      final isReply = parent != null;

      widgets.add(
        CommentCard(
          comment: c,
          depth: depth,
          isOwnComment: isOwn,

          // ✅ NEW: show reply target in UI
          replyToName: isReply ? parent!.userName : null,
          replyToPreview: isReply ? parent!.commentText : null,

          onEdit: isOwn ? () => _editComment(c) : null,
          onDelete: isOwn ? () => _deleteComment(c.id) : null,
          onLike: () => _toggleReaction(c, CommentReaction.like),
          onDislike: () => _toggleReaction(c, CommentReaction.dislike),
          onReply: () => _setReplyTo(c),
        ),
      );

      if (c.replies.isNotEmpty) {
        widgets.addAll(
          _renderCommentTree(
            c.replies,
            depth: depth + 1,
            parent: c, // ✅ NEW: pass current comment as parent
          ),
        );
      }
    }

    return widgets;
  }


  // ==========================
  // Load current user
  // ==========================
  Future<void> _loadCurrentUser() async {
    try {
      final decoded = JwtDecoder.decode(widget.token);
      final id = decoded['id'];
      setState(() {
        _currentUserId = id is int ? id : int.tryParse(id.toString());
      });
    } catch (_) {
      // ignore
    }
  }

  // ==========================
  // Load comments (tree)
  // ==========================
  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getComments(
        token: widget.token,
        postId: widget.postId,
      );

      List<Comment> flat = [];

      if (response is List) {
        flat = response
            .map((j) => Comment.fromJson(j as Map<String, dynamic>))
            .toList();
      } else if (response is Map && response['comments'] is List) {
        flat = (response['comments'] as List)
            .map((j) => Comment.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        setState(() {
          _comments = [];
          _commentsCache[widget.postId] = [];
          _isLoading = false;
        });
        return;
      }

      // ✅ dedupe flat first
      final deduped = _dedupeFlatById(flat);

      final tree = _buildTree(deduped);
      _dedupeTreeInPlace(tree, <int>{});

      setState(() {
        _originalTree = _cloneTree(tree); // ✅ keep backend natural order
        _comments = tree;
        _applySort(); // ✅ default is mostReacted
        _commentsCache[widget.postId] = List.from(_comments);
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    }
  }


  List<Comment> _buildTree(List<Comment> flat) {
    final map = <int, Comment>{};

    for (final c in flat) {
      c.replies = [];
      map[c.id] = c;
    }

    final roots = <Comment>[];
    for (final c in flat) {
      final pid = c.parentCommentId;
      if (pid == null) {
        roots.add(c);
      } else {
        final parent = map[pid];
        if (parent != null) {
          parent.replies.add(c);
        } else {
          roots.add(c); // orphan => root
        }
      }
    }

    return roots;
  }


  // ==========================
  // Reactions
  // ==========================
  Future<void> _toggleReaction(Comment comment, CommentReaction reaction) async {
    // NOTE: _comments is roots; comment object is same reference inside tree.
    // We'll just do optimistic changes then refresh sort/caches.

    final prev = comment.myReaction;

    setState(() {
      if (reaction == CommentReaction.like) {
        if (prev == CommentReaction.like) {
          comment.myReaction = null;
          comment.likesCount = (comment.likesCount - 1).clamp(0, 1 << 30);
        } else {
          if (prev == CommentReaction.dislike) {
            comment.dislikesCount =
                (comment.dislikesCount - 1).clamp(0, 1 << 30);
          }
          comment.myReaction = CommentReaction.like;
          comment.likesCount = comment.likesCount + 1;
        }
      } else {
        if (prev == CommentReaction.dislike) {
          comment.myReaction = null;
          comment.dislikesCount = (comment.dislikesCount - 1).clamp(0, 1 << 30);
        } else {
          if (prev == CommentReaction.like) {
            comment.likesCount = (comment.likesCount - 1).clamp(0, 1 << 30);
          }
          comment.myReaction = CommentReaction.dislike;
          comment.dislikesCount = comment.dislikesCount + 1;
        }
      }

      _commentsCache[widget.postId] = List.from(_comments);
      _applySort();
    });

    try {
      if (prev == reaction) {
        final res = await ApiService.removeCommentReaction(
          token: widget.token,
          commentId: comment.id,
        );
        _applyReactionResponseIfPresent(comment.id, res);
      } else {
        final res = await ApiService.reactToComment(
          token: widget.token,
          commentId: comment.id,
          reaction: reaction == CommentReaction.like ? 'like' : 'dislike',
        );
        _applyReactionResponseIfPresent(comment.id, res);
      }
    } catch (e) {
      // rollback
      if (!mounted) return;
      setState(() {
        // best-effort rollback: set back prev (counts are tricky; reload is safest)
        comment.myReaction = prev;
        _commentsCache[widget.postId] = List.from(_comments);
        _applySort();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.tr('failed_to_update_reaction') ??
                'Failed to update reaction',
          ),
        ),
      );
    }
  }

  void _applyReactionResponseIfPresent(int commentId, dynamic res) {
    if (!mounted) return;

    Map<String, dynamic>? data;
    if (res is Map && res['comment'] is Map) {
      data = Map<String, dynamic>.from(res['comment']);
    } else if (res is Map && res['id'] != null) {
      data = Map<String, dynamic>.from(res);
    }

    if (data == null) return;
    final updated = Comment.fromJson(data);

    // find comment in tree and update counts
    final target = _findInTree(_comments, commentId);
    if (target == null) return;

    setState(() {
      target.likesCount = updated.likesCount;
      target.dislikesCount = updated.dislikesCount;
      target.myReaction = updated.myReaction;

      _commentsCache[widget.postId] = List.from(_comments);
      _applySort();
    });
  }

  Comment? _findInTree(List<Comment> nodes, int id) {
    for (final c in nodes) {
      if (c.id == id) return c;
      if (c.replies.isNotEmpty) {
        final r = _findInTree(c.replies, id);
        if (r != null) return r;
      }
    }
    return null;
  }
  void _dedupeTreeInPlace(List<Comment> nodes, Set<int> seen) {
    for (int i = nodes.length - 1; i >= 0; i--) {
      final c = nodes[i];
      if (seen.contains(c.id)) {
        nodes.removeAt(i);
        continue;
      }
      seen.add(c.id);
      if (c.replies.isNotEmpty) {
        _dedupeTreeInPlace(c.replies, seen);
      }
    }
  }

  // ==========================
  // Add / Delete / Edit
  // ==========================
  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final response = await ApiService.addComment(
        token: widget.token,
        postId: widget.postId,
        content: text,
        parentCommentId: _replyTo?.id,
      );

      Comment? newComment;

      if (response is Map && response['comment'] is Map) {
        newComment = Comment.fromJson(response['comment'] as Map<String, dynamic>);
      } else if (response is Map && response['id'] != null) {
        newComment = Comment.fromJson(response as Map<String, dynamic>);
      }

      if (!mounted) return;

      if (newComment == null) {
        setState(() => _isSending = false);
        return;
      }

      // ✅ ensure parent id is set for replies if backend didn't return it
      if (_replyTo != null && newComment.parentCommentId == null) {
        newComment = _cloneCommentWith(
          newComment,
          parentCommentId: _replyTo!.id,
        );
      }

      setState(() {
        // ✅ IMPORTANT: remove any existing copy of this comment id (prevents double display)
        _removeFromTree(_comments, newComment!.id);

        if (_replyTo == null) {
          _comments.add(newComment!);
        } else {
          final parent = _findInTree(_comments, _replyTo!.id);
          if (parent != null) {
            parent.replies.add(newComment!);
          } else {
            _comments.add(newComment!);
          }
        }

        _commentController.clear();
        _replyTo = null;

        _applySort();
        _commentsCache[widget.postId] = List.from(_comments);
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await ApiService.deleteComment(token: widget.token, commentId: commentId);

      setState(() {
        _removeFromTree(_comments, commentId);
        _commentsCache[widget.postId] = List.from(_comments);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.tr('comment_deleted') ??
                  'Comment deleted',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  bool _removeFromTree(List<Comment> nodes, int id) {
    for (int i = 0; i < nodes.length; i++) {
      final c = nodes[i];
      if (c.id == id) {
        nodes.removeAt(i);
        return true;
      }
      if (c.replies.isNotEmpty) {
        final removed = _removeFromTree(c.replies, id);
        if (removed) return true;
      }
    }
    return false;
  }

// ==========================
// EDIT (final-safe)
// ==========================

  Future<void> _editComment(Comment comment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: comment.commentText);

    final newText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)?.tr('edit_comment') ?? 'Edit comment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: null,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)?.tr('write_comment') ??
                        'Write a comment...',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(AppLocalizations.of(context)?.tr('cancel') ?? 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                        child: Text(AppLocalizations.of(context)?.tr('save') ?? 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (newText == null) return;

    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == comment.commentText) return;

    final oldText = comment.commentText;

    // ✅ optimistic: replace the comment node in the tree with a cloned object
    setState(() {
      _comments = _replaceCommentTextInTree(_comments, comment.id, trimmed);
      _commentsCache[widget.postId] = List.from(_comments);
    });

    try {
      final response = await ApiService.updateComment(
        token: widget.token,
        commentId: comment.id,
        commentText: trimmed,
      );

      Comment? updated;
      if (response is Map && response['comment'] is Map) {
        updated = Comment.fromJson(response['comment'] as Map<String, dynamic>);
      } else if (response is Map && response['id'] != null) {
        updated = Comment.fromJson(response as Map<String, dynamic>);
      }

      if (!mounted) return;

      if (updated != null) {
        // ✅ apply backend-confirmed text (still final-safe replacement)
        setState(() {
          _comments = _replaceCommentNodeInTree(_comments, updated!);
          _commentsCache[widget.postId] = List.from(_comments);
        });
      }
    } catch (e) {
      if (!mounted) return;

      // rollback
      setState(() {
        _comments = _replaceCommentTextInTree(_comments, comment.id, oldText);
        _commentsCache[widget.postId] = List.from(_comments);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit comment: $e')),
      );
    }
  }

  /// Replace ONLY the commentText for a given comment id (final-safe).
  /// Keeps replies and all other fields.
  List<Comment> _replaceCommentTextInTree(List<Comment> nodes, int id, String newText) {
    return nodes.map((c) {
      // First update children
      final updatedReplies = c.replies.isNotEmpty
          ? _replaceCommentTextInTree(c.replies, id, newText)
          : c.replies;

      // If this is the node -> clone with new text
      if (c.id == id) {
        final cloned = _cloneCommentWith(
          c,
          commentText: newText,
          replies: updatedReplies,
        );
        return cloned;
      }

      // If children changed -> clone parent to carry new replies
      final changedReplies = !identical(updatedReplies, c.replies);
      if (changedReplies) {
        return _cloneCommentWith(c, replies: updatedReplies);
      }

      // unchanged
      return c;
    }).toList();
  }

  /// Replace whole node by id using [updated] from backend.
  /// Keeps existing replies if backend doesn't include them.
  List<Comment> _replaceCommentNodeInTree(List<Comment> nodes, Comment updated) {
    return nodes.map((c) {
      final updatedReplies = c.replies.isNotEmpty
          ? _replaceCommentNodeInTree(c.replies, updated)
          : c.replies;

      if (c.id == updated.id) {
        // ✅ keep local replies + keep parent id if backend didn't send it
        final keepReplies = updatedReplies;
        final keepParentId = updated.parentCommentId ?? c.parentCommentId;

        return _cloneCommentWith(
          updated,
          replies: keepReplies,
          parentCommentId: keepParentId, // ✅ important
        );
      }

      final changedReplies = !identical(updatedReplies, c.replies);
      if (changedReplies) {
        return _cloneCommentWith(c, replies: updatedReplies);
      }

      return c;
    }).toList();
  }


  /// Clone helper: creates a new Comment while preserving all fields.
  /// IMPORTANT: adjust fields here to match your Comment constructor exactly.
  Comment _cloneCommentWith(
      Comment base, {
        String? commentText,
        List<Comment>? replies,
        int? parentCommentId, // ✅ add this

      }) {
    final cloned = Comment(
      id: base.id,
      postId: base.postId,
      userId: base.userId,
      commentText: commentText ?? base.commentText,
      createdAt: base.createdAt,
      userName: base.userName,
      userPhoto: base.userPhoto,
      userType: base.userType,
      parentCommentId: parentCommentId ?? base.parentCommentId, // ✅ add this

      // If your model has these fields, keep them too:
      likesCount: base.likesCount,
      dislikesCount: base.dislikesCount,
      myReaction: base.myReaction,
    );

    // replies is probably NOT final in your model (you used: c.replies = [])
    cloned.replies = replies ?? base.replies;
    return cloned;
  }


  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

          // Title row
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
                  '(${_countAllComments(_comments)})',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const Spacer(),

                PopupMenuButton<CommentsSort>(
                  initialValue: _sort,
                  onSelected: (v) {
                    setState(() {
                      _sort = v;
                      _applySort();
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: CommentsSort.mostReacted,
                      child: Text(_sortLabel(context, CommentsSort.mostReacted)),
                    ),
                    PopupMenuItem(
                      value: CommentsSort.newest,
                      child: Text(_sortLabel(context, CommentsSort.newest)),
                    ),
                    PopupMenuItem(
                      value: CommentsSort.oldest,
                      child: Text(_sortLabel(context, CommentsSort.oldest)),
                    ),
                    PopupMenuItem(
                      value: CommentsSort.allComments,
                      child: Text(_sortLabel(context, CommentsSort.allComments)),
                    ),
                  ],

                  child: Row(
                    children: [
                      Icon(Icons.sort,
                          size: 18,
                          color: isDark ? Colors.grey[300] : Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(
                        _sortLabel(context, _sort),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down,
                          size: 18,
                          color: isDark ? Colors.grey[300] : Colors.grey[700]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comments list (tree)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_comments.isEmpty)
                ? _EmptyComments(isDark: isDark)
                : ListView(
              padding: const EdgeInsets.only(top: 8),
              children: _renderCommentTree(_comments),
            ),
          ),

          // ✅ Replying bar (UPDATED: shows preview line too)
          if (_replyTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : Colors.grey[200],
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[850]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${AppLocalizations.of(context)?.tr('replying_to') ?? 'Replying to'} ${_replyTo!.userName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '“${(() {
                            final t = _replyTo!.commentText.trim();
                            if (t.isEmpty) return '';
                            if (t.length > 60) return '${t.substring(0, 60)}…';
                            return t;
                          })()}”',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelReply,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),

          // Input
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)?.tr('write_comment') ??
                              'Write a comment...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }


  int _countAllComments(List<Comment> nodes) {
    int count = 0;
    for (final c in nodes) {
      count++;
      if (c.replies.isNotEmpty) count += _countAllComments(c.replies);
    }
    return count;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class _EmptyComments extends StatelessWidget {
  final bool isDark;
  const _EmptyComments({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.comment_outlined,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.tr('no_comments') ?? 'No comments yet',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
