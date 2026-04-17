import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../services/api_service.dart';
import 'chat_conversation_screen.dart';
import 'package:squad/screens/search_screen.dart';
import 'dart:async';
import '../utils/app_localizations.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';

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
  bool _showArchived = false; // toggle archived view

  // Multi-select state
  bool _isSelectionMode = false;
  Set<int> _selectedChatIds = {};
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadChats();
    // Auto-refresh chat list every 5 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      _loadChats(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isPinned(Map<String, dynamic> chat) {
    final v = chat['is_pinned'];
    return v == 1 || v == true || v == '1';
  }

  bool _isArchived(Map<String, dynamic> chat) {
    final v = chat['is_archived'];
    return v == 1 || v == true || v == '1';
  }

  Future<void> _togglePinChat(int chatId, bool newPinned) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    // Optimistic update
    setState(() {
      final i = _chats.indexWhere((c) => c['chat_id'] == chatId);
      if (i != -1) _chats[i]['is_pinned'] = newPinned ? 1 : 0;

      final j = _allChats.indexWhere((c) => c['chat_id'] == chatId);
      if (j != -1) _allChats[j]['is_pinned'] = newPinned ? 1 : 0;
    });

    try {
      await ApiService.pinChat(token, chatId, newPinned);
      _loadChats(silent: true); // refresh order (pinned first)
    } catch (e) {
      // rollback by reload
      _loadChats(silent: true);
    }
  }

  Future<void> _toggleArchiveChat(int chatId, bool newArchived) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      await ApiService.archiveChat(token, chatId, newArchived);

      // If we archived while in inbox -> remove it from list immediately
      // If we unarchived while in archived view -> remove it from list immediately
      setState(() {
        _chats.removeWhere((c) => c['chat_id'] == chatId);
        _allChats.removeWhere((c) => c['chat_id'] == chatId);
      });

      _loadChats(silent: true);
    } catch (e) {
      _loadChats(silent: true);
    }
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

      final response = await ApiService.getChats(token, includeArchived: _showArchived);

      print('📦 Chat response type: ${response.runtimeType}');
      print('📦 Chat response: $response');

      // Handle the response - it's directly a List from the backend
      if (response is List) {
        final list = (response as List).map((e) => e as Map<String, dynamic>).toList();

        final filtered = _showArchived
            ? list.where((c) => _isArchived(c)).toList()     // ONLY archived
            : list.where((c) => !_isArchived(c)).toList();   // ONLY inbox (not archived)

        setState(() {
          _allChats = list;          // keep all for search if you want
          _chats = filtered;         // what you display
          _isLoading = false;
        });

        print('✅ Loaded ${_chats.length} chats (showArchived=$_showArchived)');
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
          print('✅ Loaded ${_chats.length} chats from map');
        } else {
          setState(() {
            _chats = [];
            _isLoading = false;
          });
          print('⚠️ No chats found in response');
        }
      } else {
        setState(() {
          _chats = [];
          _isLoading = false;
        });
        print('⚠️ Unknown response type');
      }
    } catch (e) {
      print('Error loading chats: $e');
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startNewChat() async {
    // Navigate to user search screen with chat mode
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchScreen(mode: SearchMode.chat),
      ),
    );

    // Refresh chat list when returning
    if (result != null || mounted) {
      _loadChats(silent: true);
    }
  }


  void _filterChats(String query) {
    print('🔍 Search query: "$query"');
    print('📊 Total chats: ${_allChats.length}');

    if (query.isEmpty) {
      setState(() {
        _chats = _allChats;
      });
      print('✅ Reset to all chats');
      return;
    }

    final filtered = _allChats.where((chat) {
      final name = (chat['other_user_name'] ?? '').toLowerCase();
      final message = (chat['last_message'] ?? '').toLowerCase();
      final searchLower = query.toLowerCase();
      final matches = name.contains(searchLower) || message.contains(searchLower);
      if (matches) {
        print('✅ Match found: $name');
      }
      return matches;
    }).toList();

    setState(() {
      _chats = filtered;
    });
    print('📊 Filtered chats: ${_chats.length}');
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

      final response = await ApiService.deleteChat(token, chatId);

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
              backgroundColor: Colors.green,
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      int successCount = 0;
      int failCount = 0;

      // Delete chats one by one
      for (final chatId in _selectedChatIds.toList()) {
        try {
          final response = await ApiService.deleteChat(token, chatId);
          if (response['success'] == true) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          print('Error deleting chat $chatId: $e');
        }
      }

      // Clear selection and exit selection mode
      setState(() {
        _selectedChatIds.clear();
        _isSelectionMode = false;
      });

      // Reload chats
      _loadChats();

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.tr('deleted')} $successCount ${AppLocalizations.of(context)!.tr('chats')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting chats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('error')),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        return '${difference.inMinutes} ${AppLocalizations.of(context)!.tr('minutes_ago')}';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} ${AppLocalizations.of(context)!.tr('hours_ago')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ${AppLocalizations.of(context)!.tr('days_ago')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: const AppTopBar(),
            body: Column(
        children: [
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showArchived
                        ? (AppLocalizations.of(context)!.tr('archived_chats') /* add key */)
                        : (AppLocalizations.of(context)!.tr('messages')),
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
                    _loadChats();
                  },
                  icon: Icon(_showArchived ? Icons.inbox_outlined : Icons.archive_outlined,
                      color: isDark ? Colors.white70 : Colors.black54),
                  label: Text(
                    _showArchived
                        ? (AppLocalizations.of(context)!.tr('inbox') /* add key */)
                        : (AppLocalizations.of(context)!.tr('archived') /* add key */),
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),

          _buildSearchBar(isDark),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
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

        padding: EdgeInsets.only(bottom: 90), // Lift above bottom nav bar
        child: FloatingActionButton(
          onPressed: _startNewChat,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
          child: Icon(Icons.edit, color: Colors.white),
        ),
      ),
      //bottomNavigationBar: AppBottomBar(currentIndex: 3), // Messages tab is index 3
    );
  }

  Widget _buildHeader(bool isDark) {
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
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.04,
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
    final otherUserName = chat['other_user_name'] ?? 'Unknown User';
    final otherUserPhoto = chat['other_user_photo'];
    final lastMessage =
        chat['last_message'] ?? AppLocalizations.of(context)!.tr('no_messages_yet');
    final lastMessageTime = chat['last_message_time'];
    final chatId = chat['chat_id'];

    final pinned = _isPinned(chat);
    final archived = _isArchived(chat);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor:
          Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
          backgroundImage: otherUserPhoto != null && otherUserPhoto.isNotEmpty
              ? NetworkImage(otherUserPhoto)
              : null,
          child: otherUserPhoto == null || otherUserPhoto.isEmpty
              ? Text(
            otherUserName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          )
              : null,
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

        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
          onSelected: (value) {
            if (value == 'pin') {
              _togglePinChat(chatId, !pinned);
            } else if (value == 'archive') {
              _toggleArchiveChat(chatId, !archived);
            } else if (value == 'delete') {
              _deleteChat(chatId);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'pin',
              child: Row(
                children: [
                  Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    pinned
                        ? AppLocalizations.of(context)!.tr('unpin')   // add key
                        : AppLocalizations.of(context)!.tr('pin'),    // add key
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
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    archived
                        ? AppLocalizations.of(context)!.tr('unarchive') // add key
                        : AppLocalizations.of(context)!.tr('archive'),  // add key
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
                    AppLocalizations.of(context)!.tr('delete'), // already exists in your app
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],

        ),

        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.normal,
          ),
        ),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatConversationScreen(
                chatId: chatId,
                otherUserName: otherUserName,
                otherUserPhoto: otherUserPhoto,
              ),
            ),
          ).then((_) => _loadChats(silent: true));
        },
      ),
    );
  }

}