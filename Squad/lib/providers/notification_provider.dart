import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:squad/models/app_notification.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _loading = false;
  bool get loading => _loading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _page = 1;
  Timer? _pollTimer;

  // optional setting (you can wire this to SettingsScreen later)
  bool notificationsEnabled = true;

  Future<String?> _token() => AuthService.getToken();

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // better: refresh count every 30s while app is open
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await refreshUnreadCount(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      refreshUnreadCount(silent: true);
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  Future<void> refreshUnreadCount({bool silent = false}) async {
    if (!notificationsEnabled) return;

    final token = await _token();
    if (token == null || token.isEmpty) return;

    final res = await ApiService.getUnreadNotificationCount(token);
    if (res is Map && res['success'] == false) return;

    final count = (res['count'] ?? 0);
    final newCount = count is int ? count : int.tryParse('$count') ?? 0;

    if (_unreadCount != newCount) {
      _unreadCount = newCount;
      notifyListeners();
    } else if (!silent) {
      notifyListeners();
    }
  }

  Future<void> refreshFirstPage() async {
    _page = 1;
    _hasMore = true;
    _items.clear();
    notifyListeners();
    await loadMore();
    await refreshUnreadCount(silent: true);
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    if (!notificationsEnabled) return;

    final token = await _token();
    if (token == null || token.isEmpty) return;

    _loading = true;
    notifyListeners();

    try {
      final res = await ApiService.getNotifications(token: token, page: _page);

      if (res is Map && res['success'] == false) {
        _loading = false;
        notifyListeners();
        return;
      }

      final rawList = (res['data'] ?? res['notifications'] ?? res) as dynamic;
      final list = rawList is List ? rawList : <dynamic>[];

      final newItems = list
          .whereType<Map>()
          .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      _items.addAll(newItems);

      // "better": don’t hardcode page size — but if backend doesn’t send has_more, do a safe fallback
      final hasMoreFromApi = res['has_more'];
      if (hasMoreFromApi is bool) {
        _hasMore = hasMoreFromApi;
      } else {
        _hasMore = newItems.isNotEmpty; // fallback
      }

      _page += 1;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;

    final token = await _token();
    if (token == null || token.isEmpty) return;

    // optimistic
    final idx = _items.indexWhere((x) => x.id == n.id);
    if (idx != -1) {
      _items[idx] = AppNotification(
        id: n.id,
        type: n.type,
        isRead: true,
        createdAt: n.createdAt,
        actorId: n.actorId,
        actorName: n.actorName,
        actorPhoto: n.actorPhoto,
        postId: n.postId,
        chatId: n.chatId,
      );
      if (_unreadCount > 0) _unreadCount -= 1;
      notifyListeners();
    }

    await ApiService.markNotificationAsRead(token: token, id: n.id);
  }

  Future<void> markAllRead() async {
    final token = await _token();
    if (token == null || token.isEmpty) return;

    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      if (!n.isRead) {
        _items[i] = AppNotification(
          id: n.id,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
          actorId: n.actorId,
          actorName: n.actorName,
          actorPhoto: n.actorPhoto,
          postId: n.postId,
          chatId: n.chatId,
        );
      }
    }
    _unreadCount = 0;
    notifyListeners();

    await ApiService.markAllNotificationsAsRead(token: token);
  }

  Future<void> deleteOne(AppNotification n) async {
    final token = await _token();
    if (token == null || token.isEmpty) return;

    _items.removeWhere((x) => x.id == n.id);
    notifyListeners();

    await ApiService.deleteNotification(token: token, id: n.id);
    await refreshUnreadCount(silent: true);
  }
}
