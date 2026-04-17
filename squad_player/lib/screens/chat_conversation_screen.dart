import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';
import 'dart:async';
import 'player_profile_screen.dart'; // <- change path to your real file

class ChatConversationScreen extends StatefulWidget {
  final int chatId;
  final String otherUserName;
  final String? otherUserPhoto;
  final int otherUserId;
  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.otherUserId,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  int? _currentUserId;
  Timer? _refreshTimer;


  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMessages();
    // Auto-refresh messages every 3 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _openOtherUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(userId: widget.otherUserId),
      ),
    );
  }

  void _openProfileForMessage(bool isMine) {
    final id = isMine ? _currentUserId : widget.otherUserId;
    if (id == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(userId: id),
      ),
    );
  }


  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }
      if (_messages.isNotEmpty) {
        debugPrint('FIRST MESSAGE KEYS: ${_messages.first.keys.toList()}');
        debugPrint('FIRST MESSAGE DATA: ${_messages.first}');
      }

      final response = await ApiService.getMessages(
        token: token,
        chatId: widget.chatId,
      );

      // Handle the response - it's directly a List from the backend
      if (response is List) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      } else if (response is Map) {
        // If wrapped in a map, try to extract the list
        dynamic data = response['data'] ?? response['messages'] ?? [];
        if (data is List) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        } else {
          setState(() {
            _messages = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _messages = [];
          _isLoading = false;
        });
      }

      // Sort messages: Pinned messages first, then by date
      _messages.sort((a, b) {
        // Parse dates safely
        DateTime dateA;
        DateTime dateB;
        try {
          dateA = DateTime.parse(a['created_at']);
        } catch (e) {
          dateA = DateTime.fromMillisecondsSinceEpoch(0);
        }
        try {
          dateB = DateTime.parse(b['created_at']);
        } catch (e) {
          dateB = DateTime.fromMillisecondsSinceEpoch(0);
        }

        // Sort by date first (oldest to newest)
        int dateComparison = dateA.compareTo(dateB);

        // Pinned messages logic:
        // If you want pinned messages to appear at the TOP of the chat view (which is the START of the list in a standard ListView),
        // they should come FIRST in the list (index 0).

        bool aPinned = a['is_pinned'] == true || a['is_pinned'] == 1;
        bool bPinned = b['is_pinned'] == true || b['is_pinned'] == 1;

        if (aPinned && !bPinned) return -1; // a comes before b (a is pinned)
        if (!aPinned && bPinned) return 1;  // b comes before a (b is pinned)

        return dateComparison;
      });

      // Scroll to bottom after loading messages
      if (!silent && _messages.isNotEmpty) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await ApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        message: message,
      );

      if (response['message'] == 'Message sent successfully.') {
        _messageController.clear();
        await _loadMessages(silent: true);

        // Scroll to bottom after sending
        Future.delayed(Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.tr('failed_to_start_chat'))),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.tr('error')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final isMine = message['sender_id'] == _currentUserId;
    final isPinned = message['is_pinned'] == true || message['is_pinned'] == 1;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin Option (Available for everyone in the chat)
              ListTile(
                leading: Icon(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    color: isDark ? Colors.white : Colors.black
                ),
                title: Text(
                  isPinned
                      ? AppLocalizations.of(context)!.tr('unpin_message')
                      : AppLocalizations.of(context)!.tr('pin_message'),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pinMessage(message['id']);
                },
              ),

              // Edit Option (Only for sender)
              if (isMine)
                ListTile(
                  leading: Icon(Icons.edit, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    AppLocalizations.of(context)!.tr('edit_message'),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditMessageDialog(message);
                  },
                ),

              // Delete Option (Only for sender)
              if (isMine)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    AppLocalizations.of(context)!.tr('delete_message'),
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message['id']);
                  },
                ),

              ListTile(
                leading: Icon(
                  Icons.cancel_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                title: Text(
                  AppLocalizations.of(context)!.tr('cancel'),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(Map<String, dynamic> message) {
    // Check if message is older than 24 hours
    try {
      final messageDate = DateTime.parse(message['created_at']);
      final now = DateTime.now();
      final difference = now.difference(messageDate);

      if (difference.inHours >= 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('cannot_edit_old_message')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      print('Error parsing message date: $e');
    }

    final TextEditingController editController = TextEditingController(text: message['message']);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: Text(
            AppLocalizations.of(context)!.tr('edit_message'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: TextField(
            controller: editController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.tr('type_message'),
              hintStyle: TextStyle(color: Colors.grey),
            ),
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                if (editController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _editMessage(message['id'], editController.text.trim());
                }
              },
              child: Text(
                AppLocalizations.of(context)!.tr('save'),
                style: TextStyle(color: Color(0xFF2BC9A8)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editMessage(int messageId, String newMessage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('Not authenticated');

      final response = await ApiService.editMessage(
        token: token,
        messageId: messageId,
        newMessage: newMessage,
      );

      if (response['success'] == true) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg['id'] == messageId);
          if (index != -1) {
            _messages[index]['message'] = newMessage;
            _messages[index]['is_edited'] = true;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.tr('message_edited_successfully')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error editing message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('error_editing_message')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pinMessage(int messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('Not authenticated');

      final response = await ApiService.pinMessage(
        token: token,
        messageId: messageId,
      );

      if (response['success'] == true) {
        final isPinned = response['is_pinned'] == true;

        setState(() {
          final index = _messages.indexWhere((msg) => msg['id'] == messageId);
          if (index != -1) {
            _messages[index]['is_pinned'] = isPinned;
          }

          // Re-sort messages
          _messages.sort((a, b) {
            bool aPinned = a['is_pinned'] == true || a['is_pinned'] == 1;
            bool bPinned = b['is_pinned'] == true || b['is_pinned'] == 1;

            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;

            // Parse dates safely
            DateTime dateA;
            DateTime dateB;
            try {
              dateA = DateTime.parse(a['created_at']);
            } catch (e) {
              dateA = DateTime.fromMillisecondsSinceEpoch(0);
            }
            try {
              dateB = DateTime.parse(b['created_at']);
            } catch (e) {
              dateB = DateTime.fromMillisecondsSinceEpoch(0);
            }

            return dateA.compareTo(dateB);
          });
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPinned
                  ? AppLocalizations.of(context)!.tr('message_pinned')
                  : AppLocalizations.of(context)!.tr('message_unpinned')
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error pinning message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('error_pinning_message')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await ApiService.deleteMessage(
        token: token,
        messageId: messageId,
      );

      if (response['success'] == true) {
        // Remove message from local list immediately
        setState(() {
          _messages.removeWhere((msg) => msg['id'] == messageId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.tr('message_deleted_successfully')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to delete message');
      }
    } catch (e) {
      print('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('error_deleting_message')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            InkWell(
              onTap: () {
                debugPrint('✅ avatar tapped -> open profile ${widget.otherUserId}');
                _openOtherUserProfile();
              },
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.all(2), // makes hit area bigger
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkAccent
                      : AppColors.primary,
                  backgroundImage: (widget.otherUserPhoto != null &&
                      widget.otherUserPhoto!.trim().isNotEmpty)
                      ? NetworkImage(widget.otherUserPhoto!)
                      : null,
                  child: (widget.otherUserPhoto == null ||
                      widget.otherUserPhoto!.trim().isEmpty)
                      ? Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),
            ),


            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.tr('online'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _loadMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
              child: Text(
                AppLocalizations.of(context)!.tr('no_messages_yet'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message['sender_id'] == _currentUserId;
                return _buildMessageBubble(message, isMine, isDark);
              },
            ),
          ),
          // Add padding to avoid keyboard covering the input field
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: _buildMessageInput(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMine, bool isDark) {
    final isPinned = message['is_pinned'] == true || message['is_pinned'] == 1;
    final isEdited = message['is_edited'] == true || message['is_edited'] == 1;

    // Sender name & photo (best effort)
    final senderName = (message['sender_name'] ?? widget.otherUserName ?? 'U').toString();
    final senderPhoto = (message['sender_photo'] ?? widget.otherUserPhoto ?? '').toString();

    Widget avatar() {
      final hasPhoto = senderPhoto.trim().isNotEmpty;

      return InkWell(
        onTap: () => _openProfileForMessage(isMine),
        borderRadius: BorderRadius.circular(999),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
          backgroundImage: hasPhoto ? NetworkImage(senderPhoto) : null,
          child: !hasPhoto
              ? Text(
            senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          )
              : null,
        ),
      );
    }

    Widget bubble() {
      return GestureDetector(
        onLongPress: () => _showMessageOptions(message),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.68,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? AppColors.primary
                : (isDark ? AppColors.cardDark : Colors.grey[200]),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: isPinned ? Border.all(color: Colors.amber, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 12, color: isMine ? Colors.white70 : Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.tr('pinned'),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine ? Colors.white70 : Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Message text
              Text(
                (message['message'] ?? '').toString(),
                style: TextStyle(
                  color: isMine ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 4),

              // time + edited
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '(${AppLocalizations.of(context)!.tr('edited')})',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: isMine ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ),
                  Text(
                    _formatTime(message['created_at']),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Layout with avatar beside bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMine
            ? [
          bubble(),
          const SizedBox(width: 8),
          avatar(),
        ]
            : [
          avatar(),
          const SizedBox(width: 8),
          bubble(),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.tr('type_message'),
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),

          ],
        ),
      ),
    );
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
      } else if (difference.inDays < 1) {
        return '${difference.inHours}${AppLocalizations.of(context)!.tr('hours_ago')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
