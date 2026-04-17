import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad/providers/notification_provider.dart';
import 'package:squad/models/app_notification.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _scroll = ScrollController();

  String t(BuildContext context, String key) {
    return AppLocalizations.of(context)?.tr(key) ?? key;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().refreshFirstPage();
    });

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<NotificationProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'notifications')),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => context.read<NotificationProvider>().markAllRead(),
            tooltip: t(context, 'notifications_mark_all_read'),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, p, _) {
          return RefreshIndicator(
            onRefresh: () => p.refreshFirstPage(),
            child: ListView.builder(
              controller: _scroll,
              itemCount: p.items.length + 1,
              itemBuilder: (context, i) {
                if (i == p.items.length) {
                  if (p.loading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!p.hasMore && p.items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(t(context, 'notifications_empty')),
                      ),
                    );
                  }
                  return const SizedBox(height: 24);
                }

                final n = p.items[i];
                return _NotificationTile(
                  n: n,
                  isDark: isDark,
                  titleText: _titleFromType(context, n.type),
                  deleteLabel: t(context, 'delete'),
                  onTap: () async {
                    await p.markRead(n);
                    // TODO: navigate based on type/postId/chatId
                  },
                  onDelete: () => p.deleteOne(n),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _titleFromType(BuildContext context, String type) {
    switch (type) {
      case 'like':
        return t(context, 'notification_type_like');
      case 'comment':
        return t(context, 'notification_type_comment');
      case 'follow':
        return t(context, 'notification_type_follow');
      default:
        return t(context, 'notification_type_default');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  final bool isDark;
  final String titleText;
  final String deleteLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.n,
    required this.isDark,
    required this.titleText,
    required this.deleteLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !n.isRead
        ? (isDark ? AppColors.cardDark : AppColors.primary.withOpacity(0.08))
        : Colors.transparent;

    return Dismissible(
      key: ValueKey('notif_${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.red,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              deleteLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                (n.actorPhoto != null && n.actorPhoto!.isNotEmpty)
                    ? NetworkImage(n.actorPhoto!)
                    : null,
                child: (n.actorPhoto == null || n.actorPhoto!.isEmpty)
                    ? const Icon(Icons.notifications)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontWeight:
                        n.isRead ? FontWeight.w500 : FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.actorName ?? '',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                n.isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
