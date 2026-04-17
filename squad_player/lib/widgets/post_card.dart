import 'package:flutter/material.dart';
import 'package:squad_player/models/post.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/widgets/video_player_widget.dart';
import '../utils/app_localizations.dart';
import 'comments_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'facebook_like_icon.dart';
import 'social_share_widget.dart';
import 'package:squad_player/screens/media_viewer_screen.dart';
import 'package:squad_player/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Function(int postId, String reactionType) onReaction;
  final Function(int postId)? onDelete;
  final Function(int postId)? onEdit;
  final Function(int postId, bool isPinned)? onPin;
  final Function(int postId, bool isHidden)? onHide;
  final int? currentUserId;
  final VoidCallback? onCommentAdded;
  final void Function(int userId)? onUserTap;
  final void Function(String url, String heroTag)? onOpenImage;
  final void Function(String url)? onOpenVideo;
  final void Function(int postId, int newViews)? onViewsUpdated;
  final String viewScope;
  static final Set<String> _viewedThisSession = <String>{};
  final Set<int>? viewedCache;
  final bool enableViewIncrement;

  const PostCard({
    super.key,
    required this.post,
    required this.onReaction,
    this.onDelete,
    this.onEdit,
    this.onPin,
    this.onHide,
    this.currentUserId,
    this.onCommentAdded,
    this.onUserTap,
    this.onOpenImage,
    this.onOpenVideo,
    this.onViewsUpdated,
    this.viewedCache,
    this.viewScope = 'global',
    this.enableViewIncrement = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PostCard &&
              runtimeType == other.runtimeType &&
              post.id == other.post.id;

  @override
  int get hashCode => post.id.hashCode;
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late Post _localPost;
  bool _showReactionPicker = false;
  late AnimationController _reactionAnimController;
  late Animation<double> _reactionScaleAnim;

  @override
  void initState() {
    super.initState();
    _localPost = widget.post;
    _reactionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _reactionScaleAnim = CurvedAnimation(
      parent: _reactionAnimController,
      curve: Curves.easeOutBack,
    );
    if (widget.enableViewIncrement) _incrementView();
  }

  @override
  void dispose() {
    _reactionAnimController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _localPost = widget.post;
    }
  }

  Future<void> _incrementView() async {
    final k = '${widget.viewScope}:${widget.post.id}';
    if (PostCard._viewedThisSession.contains(k)) return;
    PostCard._viewedThisSession.add(k);
    try {
      await ApiService.incrementPostView(widget.post.id);
      final newViews = (_localPost.views) + 1;
      if (!mounted) return;
      setState(() {
        _localPost = _localPost.copyWith(views: newViews);
      });
      widget.onViewsUpdated?.call(widget.post.id, newViews);
    } catch (_) {}
  }

  void _handleReaction(int postId, String type) {
    final oldReaction = _localPost.userReaction;
    setState(() {
      _showReactionPicker = false;
      if (oldReaction == type) {
        _localPost = _updateReactionCount(_localPost, type, -1);
        _localPost = _localPost.copyWith(userReaction: null);
      } else {
        if (oldReaction != null) {
          _localPost = _updateReactionCount(_localPost, oldReaction, -1);
        }
        _localPost = _updateReactionCount(_localPost, type, 1);
        _localPost = _localPost.copyWith(userReaction: type);
      }
    });
    widget.onReaction(postId, type);
  }

  Post _updateReactionCount(Post post, String type, int delta) {
    switch (type) {
      case 'like':    return post.copyWith(likeCount: (post.likeCount ?? 0) + delta);
      case 'love':    return post.copyWith(loveCount: (post.loveCount ?? 0) + delta);
      case 'talent':  return post.copyWith(talentCount: (post.talentCount ?? 0) + delta);
      case 'amazing': return post.copyWith(amazingCount: (post.amazingCount ?? 0) + delta);
      default:        return post;
    }
  }

  String _getTimeAgo(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final loc = AppLocalizations.of(context)!;
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} ${loc.tr('years_ago')}';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} ${loc.tr('months_ago')}';
    if (diff.inDays > 0) return '${diff.inDays} ${loc.tr('days_ago')}';
    if (diff.inHours > 0) return '${diff.inHours} ${loc.tr('hours_ago')}';
    if (diff.inMinutes > 0) return '${diff.inMinutes} ${loc.tr('minutes_ago')}';
    return loc.tr('just_now');
  }

  String _translatePosition(String? position, BuildContext context) {
    if (position == null || position.isEmpty) return '';
    const map = {
      'Goalkeeper': 'goalkeeper', 'Right Back': 'right_back',
      'Left Back': 'left_back', 'Center Back': 'center_back',
      'Defensive Midfielder': 'defensive_midfielder',
      'Central Midfielder': 'central_midfielder',
      'Attacking Midfielder': 'attacking_midfielder',
      'Right Winger': 'right_winger', 'Left Winger': 'left_winger',
      'Forward': 'forward', 'Striker': 'striker',
    };
    final key = map[position];
    if (key != null) return AppLocalizations.of(context)!.tr(key);
    return position;
  }

  Color _getUserTypeColor(String userType, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (userType.toLowerCase()) {
      case 'player': return isDark ? AppColors.darkAccent : AppColors.primary;
      case 'scout':  return Colors.blue;
      case 'guest':  return Colors.orange;
      default:       return Colors.grey;
    }
  }

  bool get _canDelete => widget.currentUserId != null && widget.currentUserId == _localPost.userId;
  bool get _canEdit   => widget.currentUserId != null && widget.currentUserId == _localPost.userId;
  bool get _canPin    => widget.currentUserId != null && widget.currentUserId == _localPost.userId;

  bool get _isVideo {
    final url = _localPost.mediaUrl.toLowerCase();
    if (url.isEmpty) return false;
    return (_localPost.mediaType == 'video') ||
        url.endsWith('.mp4') || url.endsWith('.mov') ||
        url.endsWith('.avi') || url.endsWith('.mkv') ||
        url.endsWith('.webm') || url.endsWith('.m4v') ||
        url.contains('m3u8');
  }

  void _showDeleteDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc?.tr('delete_post') ?? 'Delete Post'),
        content: Text(loc?.tr('are_you_sure_delete') ?? 'Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc?.tr('cancel') ?? 'Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); widget.onDelete?.call(_localPost.id); },
            child: Text(loc?.tr('delete') ?? 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCommentsBottomSheet(BuildContext context) async {
    final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
    if (token == null || !context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => CommentsBottomSheet(
        postId: _localPost.id,
        token: token,
        postOwnerId: _localPost.userId,
        currentUserId: widget.currentUserId ?? -1,
      ),
    );
  }

  Future<void> _handlePin(BuildContext context) async {
    final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
    if (token == null) return;
    try {
      final result = await ApiService.pinPost(token: token, postId: _localPost.id);
      if (result['success'] == true || result['message'] != null) {
        widget.onPin?.call(_localPost.id, !_localPost.isPinned);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localPost.isPinned
                ? AppLocalizations.of(context)?.tr('post_pinned') ?? 'Post pinned'
                : AppLocalizations.of(context)?.tr('post_unpinned') ?? 'Post unpinned')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleHide(BuildContext context) async {
    final token = await SharedPreferences.getInstance().then((p) => p.getString('auth_token'));
    if (token == null) return;
    try {
      final result = await ApiService.hidePost(token: token, postId: _localPost.id);
      if (result['success'] == true || result['message'] != null) {
        widget.onHide?.call(_localPost.id, !_localPost.isHidden);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _toggleReactionPicker() {
    if (!mounted) return;
    setState(() { _showReactionPicker = !_showReactionPicker; });
    if (_showReactionPicker) {
      _reactionAnimController.forward(from: 0);
    } else {
      _reactionAnimController.reverse();
    }
  }

  /// Total reactions across all types
  int get _totalReactions =>
      (_localPost.likeCount ?? 0) +
          (_localPost.loveCount ?? 0) +
          (_localPost.talentCount ?? 0) +
          (_localPost.amazingCount ?? 0);

  Widget _buildReactionEmoji(String type, String emoji, String label, Color color) {
    return GestureDetector(
      onTap: () => _handleReaction(_localPost.id, type),
      child: ScaleTransition(
        scale: _reactionScaleAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _localPost.userReaction == type
                ? color.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _localPost.userReaction == type ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D2D44) : const Color(0xFFEEEEEE);

    return GestureDetector(
      onTap: () {
        if (_showReactionPicker) {
          setState(() => _showReactionPicker = false);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _PostHeader(
              post: _localPost,
              canDelete: _canDelete,
              canEdit: _canEdit,
              canPin: _canPin,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
              onPin: _handlePin,
              onHide: _handleHide,
              getTimeAgo: _getTimeAgo,
              getUserTypeColor: _getUserTypeColor,
              showDeleteDialog: _showDeleteDialog,
              translatePosition: _translatePosition,
              onUserTap: widget.onUserTap,
            ),

            // ── Caption ──
            if (_localPost.caption?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  _localPost.caption!,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  ),
                ),
              ),

            // ── Media ──
            if (_localPost.mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                child: _MediaContent(
                  post: _localPost,
                  isVideo: _isVideo,
                  onOpenImage: widget.onOpenImage,
                  onOpenVideo: widget.onOpenVideo,
                ),
              ),
            ],

            // ── Reaction summary row ──
            if (_totalReactions > 0 || (_localPost.commentCount ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_totalReactions > 0)
                      Row(
                        children: [
                          _buildMiniReactionBubbles(),
                          const SizedBox(width: 6),
                          Text(
                            '$_totalReactions',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    if ((_localPost.commentCount ?? 0) > 0)
                      Text(
                        '${_localPost.commentCount} ${AppLocalizations.of(context)!.tr('comments')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(
                height: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),

            // ── Reaction Picker Popup ──
            if (_showReactionPicker)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252540) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildReactionEmoji('like', '👍', AppLocalizations.of(context)!.tr('like'), Colors.blue),
                        _buildReactionEmoji('love', '❤️', AppLocalizations.of(context)!.tr('love'), Colors.red),
                        _buildReactionEmoji('talent', '⭐', AppLocalizations.of(context)!.tr('talent'), Colors.amber),
                        _buildReactionEmoji('amazing', '👎', AppLocalizations.of(context)!.tr('amazing'), const Color(0xFF26A69A)),                      ],
                    ),
                  ),
                ),
              ),

            // ── Action Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  // Like button (long-press opens picker, tap toggles like)
                  Expanded(
                    child: _ActionButton(
                      onTap: () {
                        if (_showReactionPicker) {
                          _handleReaction(_localPost.id, 'like'); // second tap = like
                        } else {
                          _toggleReactionPicker(); // first tap = open reactions
                        }
                      },
                      onLongPress: null,
                      icon: _buildCurrentReactionIcon(),
                      label: _localPost.userReaction != null
                          ? _reactionLabel(_localPost.userReaction!, context)
                          : AppLocalizations.of(context)!.tr('like'),
                      isActive: _localPost.userReaction != null,
                      activeColor: _reactionColor(_localPost.userReaction),
                    ),
                  ),
                  // Comment
                  Expanded(
                    child: _ActionButton(
                      onTap: () => _showCommentsBottomSheet(context),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      label: (_localPost.commentCount ?? 0) > 0
                          ? '${_localPost.commentCount}'
                          : AppLocalizations.of(context)!.tr('comment'),
                      isActive: false,
                      activeColor: Colors.blue,
                    ),
                  ),
                  // Views
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 18,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          '${_localPost.views}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Share
                  Expanded(
                    child: SocialShareWidget(
                      postId: _localPost.id,
                      postContent: _localPost.caption ?? AppLocalizations.of(context)!.tr('check_out_post'),
                      mediaUrl: _localPost.mediaUrl.isNotEmpty ? _localPost.mediaUrl : null,
                      userName: _localPost.userName,
                      baseUrl: ApiService.baseUrl,
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentReactionIcon() {
    switch (_localPost.userReaction) {
      case 'like':    return const Text('👍', style: TextStyle(fontSize: 18));
      case 'love':    return const Text('❤️', style: TextStyle(fontSize: 18));
      case 'talent':  return const Text('⭐', style: TextStyle(fontSize: 18));
      case 'amazing': return const Text('👎', style: TextStyle(fontSize: 18));
      default:
        return FacebookLikeIcon(isLiked: false, color: Colors.grey);
    }
  }

  Widget _buildMiniReactionBubbles() {
    final reactionTypes = <String>[];
    if ((_localPost.likeCount ?? 0) > 0)    reactionTypes.add('like');
    if ((_localPost.loveCount ?? 0) > 0)    reactionTypes.add('love');
    if ((_localPost.talentCount ?? 0) > 0)  reactionTypes.add('talent');
    if ((_localPost.amazingCount ?? 0) > 0) reactionTypes.add('amazing');

    const emojiMap = {'like': '👍', 'love': '❤️', 'talent': '⭐', 'amazing': '👎'};
    return Row(
      children: reactionTypes.take(3).map((t) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(emojiMap[t]!, style: const TextStyle(fontSize: 14)),
      )).toList(),
    );
  }

  String _reactionLabel(String type, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (type) {
      case 'like':    return loc.tr('like');
      case 'love':    return loc.tr('love');
      case 'talent':  return loc.tr('talent');
      case 'amazing': return loc.tr('amazing');
      default:        return loc.tr('like');
    }
  }

  Color _reactionColor(String? type) {
    switch (type) {
      case 'like':    return Colors.blue;
      case 'love':    return Colors.red;
      case 'talent':  return Colors.amber;
      case 'amazing': return Colors.grey;
      default:        return Colors.grey;
    }
  }
}

// ════════════════════════════════════════════════════════
// _ActionButton
// ════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget icon;
  final String label;
  final bool isActive;
  final Color activeColor;

  const _ActionButton({
    required this.onTap,
    this.onLongPress,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isActive
                ? icon
                : IconTheme(
              data: IconThemeData(
                color: isDark ? Colors.white54 : Colors.black45,
                size: 20,
              ),
              child: icon,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? activeColor : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// _PostHeader
// ════════════════════════════════════════════════════════
class _PostHeader extends StatelessWidget {
  final Post post;
  final bool canDelete;
  final bool canEdit;
  final bool canPin;
  final Function(int)? onEdit;
  final Function(int)? onDelete;
  final Function(BuildContext) onPin;
  final Function(BuildContext) onHide;
  final String Function(DateTime, BuildContext) getTimeAgo;
  final Color Function(String, BuildContext) getUserTypeColor;
  final void Function(BuildContext) showDeleteDialog;
  final String Function(String?, BuildContext) translatePosition;
  final void Function(int userId)? onUserTap;

  const _PostHeader({
    required this.post,
    required this.canDelete,
    required this.canEdit,
    required this.canPin,
    this.onEdit,
    this.onDelete,
    required this.onPin,
    required this.onHide,
    required this.getTimeAgo,
    required this.getUserTypeColor,
    required this.showDeleteDialog,
    required this.translatePosition,
    this.onUserTap,
  });

  void _showReportSheet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)?.tr('report_sent') ?? 'Report submitted'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileImageUrl = (post.userPhoto != null && post.userPhoto!.isNotEmpty)
        ? post.userPhoto
        : null;
    final isPending = post.status != null && post.status!.trim().toLowerCase() == 'pending';
    final isPinned = post.isPinned;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with colored ring
          GestureDetector(
            onTap: () => onUserTap?.call(post.userId),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    getUserTypeColor(post.userType, context),
                    getUserTypeColor(post.userType, context).withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: getUserTypeColor(post.userType, context),
                child: profileImageUrl != null
                    ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profileImageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
                    : Text(
                  post.userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Name + meta
          Expanded(
            child: GestureDetector(
              onTap: () => onUserTap?.call(post.userId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPinned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.push_pin, size: 10, color: Colors.amber),
                              SizedBox(width: 2),
                              Text('Pinned', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      if (isPending) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 10, color: Colors.orange),
                              const SizedBox(width: 2),
                              Text(
                                AppLocalizations.of(context)!.tr('pending'),
                                style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (post.country != null) ...[
                        Text(post.country!, style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        )),
                        Text('  ·  ', style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        )),
                      ],
                      if (post.position != null)
                        Text(
                          translatePosition(post.position, context),
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      if (post.country == null && post.position == null)
                        Text(post.userType, style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        )),
                      Text('  ·  ', style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                      )),
                      Text(
                        getTimeAgo(post.createdAt, context),
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: isDark ? Colors.white54 : Colors.black45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'edit':   onEdit?.call(post.id);
                case 'delete': showDeleteDialog(context);
                case 'pin':    onPin(context);
                case 'hide':   onHide(context);
                case 'report': _showReportSheet(context);
              }
            },
            itemBuilder: (ctx) {
              final loc = AppLocalizations.of(ctx);
              return [
                if (canPin) PopupMenuItem<String>(
                  value: 'pin',
                  child: _menuItem(post.isPinned ? Icons.star : Icons.push_pin, Colors.amber,
                      post.isPinned ? (loc?.tr('unpin_post') ?? 'Unpin') : (loc?.tr('pin_post') ?? 'Pin')),
                ),
                if (canPin) PopupMenuItem<String>(
                  value: 'hide',
                  child: _menuItem(post.isHidden ? Icons.visibility : Icons.visibility_off,
                      Colors.grey, post.isHidden ? (loc?.tr('show_post') ?? 'Show') : (loc?.tr('hide_post') ?? 'Hide')),
                ),
                if (canEdit) PopupMenuItem<String>(
                  value: 'edit',
                  child: _menuItem(Icons.edit_outlined, Colors.blue, loc?.tr('edit') ?? 'Edit'),
                ),
                if (canDelete) PopupMenuItem<String>(
                  value: 'delete',
                  child: _menuItem(Icons.delete_outline, Colors.red, loc?.tr('delete') ?? 'Delete'),
                ),
                if (!canDelete && !canEdit && !canPin) PopupMenuItem<String>(
                  value: 'report',
                  child: _menuItem(Icons.flag_outlined, Colors.orange, loc?.tr('report') ?? 'Report'),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, Color color, String label) => Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Text(label),
    ],
  );
}

// ════════════════════════════════════════════════════════
// _MediaContent
// ════════════════════════════════════════════════════════
class _MediaContent extends StatelessWidget {
  final Post post;
  final bool isVideo;
  final void Function(String url, String heroTag)? onOpenImage;
  final void Function(String url)? onOpenVideo;

  const _MediaContent({
    required this.post,
    required this.isVideo,
    this.onOpenImage,
    this.onOpenVideo,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = 'post_media_${post.id}';

    if (isVideo) {
      return VideoPlayerWidget(
        videoUrl: post.mediaUrl,
        thumbnailUrl: post.thumbnailUrl,
        lowQualityUrl: post.lowQualityUrl,
        mediumQualityUrl: post.mediumQualityUrl,
        highQualityUrl: post.highQualityUrl,
      );
    }

    return GestureDetector(
      onTap: () {
        if (onOpenImage != null) {
          onOpenImage!.call(post.mediaUrl, heroTag);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              imageUrl: post.mediaUrl,
            ),
          ),
        );
      },
      child: Hero(
        tag: heroTag,
        child: CachedNetworkImage(
          imageUrl: post.mediaUrl,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          placeholder: (_, __) => AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.grey[900],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          errorWidget: (_, __, ___) => AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, size: 40),
            ),
          ),
        ),
      ),
    );
  }
}
