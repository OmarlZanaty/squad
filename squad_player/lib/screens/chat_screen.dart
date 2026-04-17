import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../services/api_service.dart';
import 'chat_conversation_screen.dart';
import 'package:squad_player/screens/notification_screen.dart';
import 'user_search_screen.dart';
import 'dart:async';
import '../utils/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _allChats = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Multi-select state
  bool _isSelectionMode = false;
  Set<int> _selectedChatIds = {};
  int _unreadNotifications = 0;
  bool _showArchived = false;
  // ===== Local flags (works even if backend not ready) =====

  String _pinKey(int chatId) => 'chat_pin_$chatId';
  String _archKey(int chatId) => 'chat_arch_$chatId';

  // ✅ NEW: block/report local
  String _blockKey(int otherUserId) => 'blocked_user_$otherUserId';

  Future<bool> _isBlockedUser(int otherUserId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_blockKey(otherUserId)) ?? false;
  }

  Future<void> _setBlockedUser(int otherUserId, bool blocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blockKey(otherUserId), blocked);
  }

  bool _isPinned(Map<String, dynamic> chat) {
    final v = chat['is_pinned'];
    return v == 1 || v == true || v == '1';
  }

  bool _isArchived(Map<String, dynamic> chat) {
    final v = chat['is_archived'];
    return v == 1 || v == true || v == '1';
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _applyLocalFlagsToChats(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in list) {
      final id = _toInt(c['chat_id']);
      final pinned = prefs.getBool(_pinKey(id)) ?? false;
      final archived = prefs.getBool(_archKey(id)) ?? false;
      c['is_pinned'] = pinned ? 1 : 0;
      c['is_archived'] = archived ? 1 : 0;
    }
  }


  Future<void> _setPinnedLocal(int chatId, bool pinned) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinKey(chatId), pinned);
  }

  Future<void> _setArchivedLocal(int chatId, bool archived) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_archKey(chatId), archived);
  }

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadUnreadNotifications();
    // Auto-refresh chat list every 5 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      _loadChats(silent: true);
      _loadUnreadNotifications();
    });
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        final response = await ApiService.getUnreadNotificationCount(token);
        if (response['success'] == true) {
          if (mounted) {
            setState(() {
              _unreadNotifications = response['count'] ?? 0;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading unread notifications: $e');
    }
  }

  Future<void> _togglePinChat(int chatId, bool newPinned) async {
    // optimistic UI update
    setState(() {
      for (final c in _allChats) {
        if (c['chat_id'] == chatId) c['is_pinned'] = newPinned ? 1 : 0;
      }
      for (final c in _chats) {
        if (c['chat_id'] == chatId) c['is_pinned'] = newPinned ? 1 : 0;
      }
    });

    await _setPinnedLocal(chatId, newPinned);
    _loadChats(silent: true); // refresh sorting
  }

  Future<void> _toggleArchiveChat(int chatId, bool newArchived) async {
    await _setArchivedLocal(chatId, newArchived);

    // remove immediately from current view
    setState(() {
      _chats.removeWhere((c) => c['chat_id'] == chatId);
      for (final c in _allChats) {
        if (c['chat_id'] == chatId) c['is_archived'] = newArchived ? 1 : 0;
      }
    });

    _loadChats(silent: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await ApiService.getChats(token);

      // Handle the response - it's directly a List from the backend
      if (response is List) {
        final list = List<Map<String, dynamic>>.from(response);

        // Apply local pin/archive flags (works now)
        await _applyLocalFlagsToChats(list);

        // Filter by current view
        final filtered = _showArchived
            ? list.where((c) => _isArchived(c)).toList()
            : list.where((c) => !_isArchived(c)).toList();

        // Sort: pinned first, then by last_message_time desc
        filtered.sort((a, b) {
          final ap = _isPinned(a) ? 1 : 0;
          final bp = _isPinned(b) ? 1 : 0;
          if (ap != bp) return bp.compareTo(ap);

          final at = DateTime.tryParse((a['last_message_time'] ?? '').toString());
          final bt = DateTime.tryParse((b['last_message_time'] ?? '').toString());
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });

        setState(() {
          _allChats = list;
          _chats = filtered;
          _isLoading = false;
        });
      }
      else if (response is Map) {
        // If wrapped in a map, try to extract the list
        dynamic data = response['data'] ?? response['chats'] ?? [];
        if (data is List) {
          setState(() {
            _allChats = List<Map<String, dynamic>>.from(data);
            _chats = _allChats;
            _isLoading = false;
          });
        } else {
          setState(() {
            _chats = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _chats = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading chats: $e');
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startNewChat() async {
    // Navigate to user search screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserSearchScreen(),
      ),
    );

    // Refresh chat list when returning
    if (result != null || mounted) {
      _loadChats(silent: true);
    }
  }


  void _filterChats(String query) {
    final base = _showArchived
        ? _allChats.where((c) => _isArchived(c)).toList()
        : _allChats.where((c) => !_isArchived(c)).toList();

    if (query.trim().isEmpty) {
      setState(() => _chats = base);
      return;
    }

    final q = query.toLowerCase();
    final filtered = base.where((chat) {
      final name = (chat['other_user_name'] ?? '').toString().toLowerCase();
      final message = (chat['last_message'] ?? '').toString().toLowerCase();
      return name.contains(q) || message.contains(q);
    }).toList();

    setState(() => _chats = filtered);
  }


  Future<void> _deleteChat(int chatId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.tr('delete_chat')),
        content: Text(AppLocalizations.of(context)!.tr('delete_chat_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await ApiService.deleteChat(
        token: token,
        chatId: chatId,
      );

      if (response['success'] == true) {
        // Remove chat from local list immediately
        setState(() {
          _chats.removeWhere((chat) => chat['chat_id'] == chatId);
          _allChats.removeWhere((chat) => chat['chat_id'] == chatId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.tr('chat_deleted_successfully')),
              backgroundColor: Color(0xFF2BC9A8),
            ),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to delete chat');
      }
    } catch (e) {
      print('Error deleting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('error_deleting_chat')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelection(int chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.tr('delete_selected_chats')),
        content: Text(AppLocalizations.of(context)!.tr('delete_selected_chats_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      int successCount = 0;
      List<int> failedIds = [];

      // Delete chats one by one (or use a bulk API if available)
      for (final chatId in _selectedChatIds) {
        try {
          final response = await ApiService.deleteChat(
            token: token,
            chatId: chatId,
          );
          if (response['success'] == true) {
            successCount++;
          } else {
            failedIds.add(chatId);
          }
        } catch (e) {
          failedIds.add(chatId);
        }
      }

      setState(() {
        _chats.removeWhere((chat) => _selectedChatIds.contains(chat['chat_id']) && !failedIds.contains(chat['chat_id']));
        _allChats.removeWhere((chat) => _selectedChatIds.contains(chat['chat_id']) && !failedIds.contains(chat['chat_id']));
        _selectedChatIds.clear();
        _isSelectionMode = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.tr('deleted')} $successCount ${AppLocalizations.of(context)!.tr('chats')}'),
            backgroundColor: successCount > 0 ? Color(0xFF2BC9A8) : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting chats: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('error_deleting_chats')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(int otherUserId, String otherUserName) async {
    final blocked = await _isBlockedUser(otherUserId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked
            ? AppLocalizations.of(context)!.tr('unblock_user')
            : AppLocalizations.of(context)!.tr('block_user')),
        content: Text(
          blocked
              ? '${AppLocalizations.of(context)!.tr('unblock_user_confirmation')} $otherUserName?'
              : '${AppLocalizations.of(context)!.tr('block_user_confirmation')} $otherUserName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: blocked ? const Color(0xFF2BC9A8) : Colors.red,
            ),
            child: Text(blocked
                ? AppLocalizations.of(context)!.tr('unblock')
                : AppLocalizations.of(context)!.tr('block')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _setBlockedUser(otherUserId, !blocked);

    // remove chats with blocked user from current lists (optional UX)
    setState(() {
      _chats.removeWhere((c) => _toInt(c['other_user_id']) == otherUserId);
      _allChats.removeWhere((c) => _toInt(c['other_user_id']) == otherUserId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked
                ? AppLocalizations.of(context)!.tr('user_unblocked')
                : AppLocalizations.of(context)!.tr('user_blocked'),
          ),
          backgroundColor: blocked ? const Color(0xFF2BC9A8) : Colors.red,
        ),
      );
    }
  }

  Future<void> _reportUser(int otherUserId, String otherUserName) async {
    final controller = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.tr('report_user')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context)!.tr('report_user_prompt')} $otherUserName'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.tr('write_reason'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(AppLocalizations.of(context)!.tr('send')),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    final reason = controller.text.trim();

    // TODO later: ApiService.reportUser(...)
    // ignore: avoid_print
    print('REPORT userId=$otherUserId reason="$reason"');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tr('report_sent')),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return AppLocalizations.of(context)!.tr('just_now');
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}${AppLocalizations.of(context)!.tr('minutes_ago')}';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}${AppLocalizations.of(context)!.tr('hours_ago')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}${AppLocalizations.of(context)!.tr('days_ago')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  String _translateUserType(String type) {
    final typeMap = {
      'player': AppLocalizations.of(context)!.tr('player'),
      'scout': AppLocalizations.of(context)!.tr('scout'),
      'guest': AppLocalizations.of(context)!.tr('guest'),
    };
    return typeMap[type.toLowerCase()] ?? type;
  }

  Color _getUserTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'player':
        return Color(0xFF2BC9A8); // Teal for players
      case 'scout':
        return Color(0xFF667eea); // Purple for scouts
      case 'guest':
        return Color(0xFF95a5a6); // Gray for guests
      default:
        return Color(0xFF95a5a6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: _isSelectionMode
              ? Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.primary.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppColors.shadowDark : AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedChatIds.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedChatIds.length}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),

                // Delete button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteSelectedChats,
                    tooltip: AppLocalizations.of(context)!.tr('delete_selected_chats'),
                  ),
                ),
              ],
            ),
          )
              : Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppColors.shadowDark : AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left - Notification icon with badge
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 28,
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationScreen()),
                        );
                        _loadUnreadNotifications();
                      },
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccent : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              _unreadNotifications > 99
                                  ? AppLocalizations.of(context)!.tr('notifications_99_plus') // "99+"
                                  : _unreadNotifications.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Center - Logo
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo3.png',
                      height: 140,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          'SQUAD',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Right - Phone/contact icon
                IconButton(
                  icon: Image.asset(
                    isDark ? 'assets/images/ringing_phone_white.png' : 'assets/images/ringing_phone_black.png',
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.tr('contact_us_coming_soon'))),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // ✅ Inbox / Archived toggle row (added)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showArchived
                        ? AppLocalizations.of(context)!.tr('archived_chats')
                        : AppLocalizations.of(context)!.tr('messages'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showArchived = !_showArchived);
                    _loadChats(); // reload with filter
                  },
                  icon: Icon(
                    _showArchived ? Icons.inbox_outlined : Icons.archive_outlined,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  label: Text(
                    _showArchived
                        ? AppLocalizations.of(context)!.tr('inbox')
                        : AppLocalizations.of(context)!.tr('archived'),
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          _buildSearchBar(isDark),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chats.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
              onRefresh: () => _loadChats(),
              child: _buildChatList(isDark),
            ),
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90), // Lift above bottom nav bar
        child: FloatingActionButton(
          onPressed: _startNewChat,
          backgroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );

  }

  Widget _buildHeader(bool isDark) {
    if (_isSelectionMode) {
      return Container(
        padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
        color: isDark ? AppColors.cardDark : AppColors.primary.withOpacity(0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                ),
                SizedBox(width: 8),
                Text(
                  '${_selectedChatIds.length}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            // Ensure the delete button is visible and has enough space
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelectedChats,
                tooltip: AppLocalizations.of(context)!.tr('delete_selected_chats'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.tr('messages'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            onPressed: () => _loadChats(),
            icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.tr('search_chats'),
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.grey),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        onChanged: _filterChats,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.tr('no_conversations'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.tr('start_chat_to_connect'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startNewChat,
            icon: Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.tr('start_new_chat')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return _buildChatItem(chat, isDark);
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, bool isDark) {
    final otherUserName =
    (chat['other_user_name']?.toString().trim().isNotEmpty ?? false)
        ? chat['other_user_name'].toString()
        : AppLocalizations.of(context)!.tr('unknown_user');
    final otherUserPhoto = chat['other_user_photo'];
    final otherUserType =
    (chat['other_user_type']?.toString().trim().isNotEmpty ?? false)
        ? chat['other_user_type'].toString()
        : 'guest'; // ✅ keep internal key, UI translation happens via _translateUserType
    final lastMessage =
    (chat['last_message']?.toString().trim().isNotEmpty ?? false)
        ? chat['last_message'].toString()
        : AppLocalizations.of(context)!.tr('no_messages_yet');
    final lastMessageTime = chat['last_message_time'];
    final chatId = chat['chat_id'];
    final isSelected = _selectedChatIds.contains(chatId);
    final pinned = _isPinned(chat);
    final archived = _isArchived(chat);
    final int otherUserId = (chat['other_user_id'] ?? chat['receiver_id'] ?? 0) as int;

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _toggleSelection(chatId);
        });
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(chatId);
        } else {
          // Navigate to chat conversation
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatConversationScreen(
                chatId: chatId,
                otherUserId: otherUserId, // ✅ ADD THIS
                otherUserName: otherUserName,
                otherUserPhoto: otherUserPhoto,
              ),
            ),
          ).then((_) {
            // Refresh chat list when returning
            _loadChats(silent: true);
          });
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.1))
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
                backgroundImage: otherUserPhoto != null && otherUserPhoto.isNotEmpty
                    ? NetworkImage(otherUserPhoto)
                    : null,
                child: otherUserPhoto == null || otherUserPhoto.isEmpty
                    ? Text(
                  otherUserName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (pinned) ...[
                      const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        otherUserName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(lastMessageTime),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),

          trailing: FutureBuilder<bool>(
        future: _isBlockedUser(otherUserId),
        builder: (context, snap) {
          final isBlocked = snap.data ?? false;

          return PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
            onSelected: (value) {
              if (value == 'pin') {
                _togglePinChat(chatId, !pinned);
              } else if (value == 'archive') {
                _toggleArchiveChat(chatId, !archived);
              } else if (value == 'delete') {
                _deleteChat(chatId);
              } else if (value == 'block') {
                _blockUser(otherUserId, otherUserName);
              } else if (value == 'report') {
                _reportUser(otherUserId, otherUserName);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      pinned
                          ? AppLocalizations.of(context)!.tr('unpin')
                          : AppLocalizations.of(context)!.tr('pin'),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      archived
                          ? AppLocalizations.of(context)!.tr('unarchive')
                          : AppLocalizations.of(context)!.tr('archive'),
                    ),
                  ],
                ),
              ),

              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(isBlocked ? Icons.block_flipped : Icons.block, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isBlocked
                          ? AppLocalizations.of(context)!.tr('unblock')
                          : AppLocalizations.of(context)!.tr('block'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.tr('report'),
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),

              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.tr('delete'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}