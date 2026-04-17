import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:squad_player/models/notification_model.dart';
import 'package:squad_player/services/api_service.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/utils/app_localizations.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) return;

    // Load more when reaching near bottom (smooth)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNotifications(loadMore: true);
    }
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
      _page += 1;
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _notifications = [];
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          final loc = AppLocalizations.of(context);
          _error = loc?.tr('not_authenticated') ?? 'Not authenticated';

          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      final response = await ApiService.getNotifications(token, page: _page);

      if (response is Map && response['success'] == true) {
        final List<dynamic> data = (response['notifications'] ?? []) as List<dynamic>;
        final newItems = data
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        setState(() {
          _notifications.addAll(newItems);

          // if backend page size = 20, keep this.
          // Otherwise set it to your backend page size.
          _hasMore = newItems.length >= 20;

          _isLoading = false;
          _isLoadingMore = false;
          _error = null;
        });
      } else {
        setState(() {
          final loc = AppLocalizations.of(context);
          _error = (response is Map ? response['message'] : null) ??
              (loc?.tr('failed_to_load_notifications') ?? 'Failed to load notifications');
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markAsRead(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    // Optimistic UI
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final old = _notifications[index];
      setState(() {
        _notifications[index] = NotificationModel(
          id: old.id,
          type: old.type,
          isRead: true,
          createdAt: old.createdAt,
          actorId: old.actorId,
          actorName: old.actorName,
          actorPhoto: old.actorPhoto,
          postId: old.postId,
          postCaption: old.postCaption,
          postMedia: old.postMedia,
          postMediaType: old.postMediaType,
        );
      });
    }

    try {
      await ApiService.markNotificationAsRead(token, id);
    } catch (_) {
      // If you want rollback, reload page 1. Usually not necessary.
    }
  }

  Future<void> _markAllAsRead() async {
    final loc = AppLocalizations.of(context);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.markAllNotificationsAsRead(token);

      // Optimistic: mark all locally
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.isRead) return n;
          return NotificationModel(
            id: n.id,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
            actorId: n.actorId,
            actorName: n.actorName,
            actorPhoto: n.actorPhoto,
            postId: n.postId,
            postCaption: n.postCaption,
            postMedia: n.postMedia,
            postMediaType: n.postMediaType,
          );
        }).toList();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.tr('mark_all_read') ?? 'Marked all as read'),
          backgroundColor: const Color(0xFF2BC9A8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.tr('error') ?? 'Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ====== UI Helpers ======

  _NotifStyle _styleFor(NotificationModel n) {
    final loc = AppLocalizations.of(context);
    switch (n.type) {
      case 'like':
        return _NotifStyle(
          icon: Icons.thumb_up,
          iconColor: Colors.blue,
          text: loc?.tr('notification_like') ?? 'liked your post',
        );
      case 'love':
        return _NotifStyle(
          icon: Icons.favorite,
          iconColor: Colors.red,
          text: loc?.tr('notification_love') ?? 'loved your post',
        );
      case 'comment':
        return _NotifStyle(
          icon: Icons.comment,
          iconColor: Colors.green,
          text: loc?.tr('notification_comment') ?? 'commented on your post',
        );
      case 'follow':
        return _NotifStyle(
          icon: Icons.person_add,
          iconColor: Colors.orange,
          text: loc?.tr('notification_follow') ?? 'started following you',
        );
      default:
        return _NotifStyle(
          icon: Icons.notifications,
          iconColor: Colors.grey,
          text: loc?.tr('notification_generic') ?? 'interacted with you',
        );
    }
  }

  Widget _avatar(NotificationModel n, bool isDark) {
    final loc = AppLocalizations.of(context);
    final name = (n.actorName).trim().isEmpty
        ? (loc?.tr('user') ?? 'User')
        : n.actorName.trim();
    final photo = n.actorPhoto?.trim();

    final hasPhoto = photo != null && photo.isNotEmpty;

    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withOpacity(0.15),

          // ✅ only set backgroundImage if we have a photo
          backgroundImage: hasPhoto ? NetworkImage(photo) : null,

          // ✅ only set error handler if backgroundImage exists
          onBackgroundImageError: hasPhoto ? (_, __) {} : null,

          // ✅ fallback text if no photo
          child: hasPhoto
              ? null
              : Text(
            name[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),

        if (!n.isRead)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccent : AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.backgroundDark : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }



  Widget _mediaThumb(NotificationModel n, bool isDark) {
    final media = n.postMedia;
    if (media == null || media.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        color: isDark ? AppColors.cardDark.withOpacity(0.6) : Colors.grey.shade200,
        child: Image.network(
          media,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_not_supported_outlined,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 18,
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                      (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _notificationCard(NotificationModel n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final style = _styleFor(n);

    final bg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    final lang = Localizations.localeOf(context).languageCode;
    final timeLocale = (lang == 'ar') ? 'ar' : 'en';

    final timeText = timeago.format(
      n.createdAt,
      locale: timeLocale,
    );


    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (!n.isRead) _markAsRead(n.id);

        // ✅ Redirect to post if postId exists
        if (n.postId != null) {
          // ✅ Return the postId to the caller
          Navigator.pop(context, n.postId);
        }

      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(n, isDark),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title line
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${n.actorName} ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: style.text,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(style.icon, size: 14, color: style.iconColor),
                      const SizedBox(width: 6),
                      Text(
                        timeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      // Small "Unread" label optional (looks premium)
                      if (!n.isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkAccent : AppColors.primary).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            loc?.tr('unread') ?? 'Unread',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkAccent : AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // trailing thumbnail OR icon
            (n.postMedia != null && n.postMedia!.isNotEmpty)
                ? _mediaThumb(n, isDark)
                : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.iconColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 72,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 14),
            Text(
              loc?.tr('no_notifications') ?? 'No notifications yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc?.tr('no_notifications_hint') ?? 'When something happens, you will see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _loadNotifications(),
                icon: const Icon(Icons.refresh),
                label: Text(loc?.tr('refresh') ?? 'Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        loc?.tr('notifications') ?? 'Notifications',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      actions: [
        IconButton(
          tooltip: loc?.tr('mark_all_read') ?? 'Mark all as read',
          onPressed: _notifications.isEmpty ? null : _markAllAsRead,
          icon: const Icon(Icons.done_all),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: _appBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      )
          : (_notifications.isEmpty)
          ? _emptyState()
          : RefreshIndicator(
        onRefresh: () => _loadNotifications(),
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _notifications.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _notifications.length) {
              // loading more footer
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _isLoadingMore
                      ? const CircularProgressIndicator()
                      : const SizedBox.shrink(),
                ),
              );
            }

            return _notificationCard(_notifications[index]);
          },
        ),
      ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color iconColor;
  final String text;

  _NotifStyle({
    required this.icon,
    required this.iconColor,
    required this.text,
  });
}



