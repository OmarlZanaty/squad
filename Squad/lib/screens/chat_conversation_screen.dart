import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';
import 'dart:async';

class ChatConversationScreen extends StatefulWidget {
  final int? chatId;  // Nullable - will be null for new chats
  final int? otherUserId;  // Required for new chats
  final String otherUserName;
  final String? otherUserPhoto;

  const ChatConversationScreen({
    super.key,
    this.chatId,
    this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
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
  int? _actualChatId;  // The real chat ID after creation
  Timer? _refreshTimer;
  bool _phoneBlockedLive = false;

  @override
  void initState() {
    super.initState();
    _actualChatId = widget.chatId;  // Set initial chat ID
    _loadCurrentUser();
    // Only load messages if chat already exists
    if (_actualChatId != null) {
      _loadMessages();
      // Auto-refresh messages every 3 seconds
      _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) {
        _loadMessages(silent: true);
      });
    } else {
      // New chat - no messages yet
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!mounted) return;

    // Skip if chat doesn't exist yet
    if (_actualChatId == null) return;

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await ApiService.getMessages(
        token: token,
        chatId: _actualChatId!,
      );

      if (!mounted) return;

      print('📦 Received messages response type: ${response.runtimeType}');
      print('📦 Response content: $response');

      // Handle the response - it's directly a List from the backend
      if (response is List) {
        setState(() {
          _messages = (response as List).map((e) => e as Map<String, dynamic>).toList();
          _isLoading = false;
        });
        print('✅ Loaded ${_messages.length} messages');
      } else if (response is Map) {
        // If wrapped in a map, try to extract the list
        dynamic data = response['data'] ?? response['messages'] ?? [];
        if (data is List) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
          print('✅ Loaded ${_messages.length} messages from map');
        } else {
          setState(() {
            _messages = [];
            _isLoading = false;
          });
          print('⚠️ No messages found in response');
        }
      } else {
        setState(() {
          _messages = [];
          _isLoading = false;
        });
        print('⚠️ Unknown response type');
      }

      // Scroll to bottom after loading messages
      if (!silent && _messages.isNotEmpty) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted && _scrollController.hasClients) {
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
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _containsPhoneNumber(String text) {
    final norm = _normalizeForPhoneDetection(text);

    // Egypt mobile: 010/011/012/015 + 8 digits
    final egypt = RegExp(r'(?:\+?20)?01[0125]\d{8}');
    if (egypt.hasMatch(norm)) return true;

    final digitsOnly = norm.replaceAll(RegExp(r'[^0-9]'), '');

    // Strong rule: 9+ digits is almost always a phone/contact number
    if (digitsOnly.length >= 9) return true;

    // Egypt local hint: starts with 01 and long enough
    if (digitsOnly.startsWith('01') && digitsOnly.length >= 10) return true;

    // Country code hint
    if (digitsOnly.startsWith('20') && digitsOnly.length >= 11) return true;

    // Split groups case: "010 12 34 5678"
    final groups = RegExp(r'\d+').allMatches(norm).map((m) => m.group(0)!).toList();
    final total = groups.fold<int>(0, (sum, g) => sum + g.length);
    if (total >= 9 && groups.length >= 2) return true;

    // "0-1-0-1-2-..." single digit pieces trick
    final singleDigitPieces = groups.where((g) => g.length == 1).length;
    if (singleDigitPieces >= 7) return true;

    // Weak rule: 7–8 digits only blocked if "contact intent" words exist
    if (digitsOnly.length >= 7 && digitsOnly.length <= 8) {
      final lower = text.toLowerCase();
      final hasContactWords = RegExp(
          r'(whatsapp|call|phone|tel|mobile|number|رقم|اتصل|واتس|واتساب|تليفون|موبايل)'
      ).hasMatch(lower);

      if (hasContactWords) return true;
    }

    return false;
  }


  /// Normalize to catch tricks:
  /// - Convert Arabic-Indic digits to 0-9
  /// - Convert common words to digits (English + Arabic)
  /// - Replace 'O'/'o' with 0 when near digits
  /// - Remove separators and noise but keep digits & plus
  String _normalizeForPhoneDetection(String input) {
    var s = input.toLowerCase();

    // Convert Arabic-Indic digits to Latin digits
    s = _arabicIndicToLatinDigits(s);

    // Replace common obfuscations
    // O/o used as zero (only safe-ish replacement because we target phone detection)
    s = s.replaceAll('o', '0');

    // Replace number words (EN)
    final en = <String, String>{
      'zero': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
    };
    en.forEach((k, v) {
      s = s.replaceAll(RegExp(r'\b' + k + r'\b'), v);
    });

    // Replace number words (AR) — basic
    final ar = <String, String>{
      'صفر': '0',
      'واحد': '1',
      'اتنين': '2',
      'اثنين': '2',
      'تلاتة': '3',
      'ثلاثة': '3',
      'اربعة': '4',
      'أربعة': '4',
      'خمسة': '5',
      'ستة': '6',
      'سبعة': '7',
      'تمانية': '8',
      'ثمانية': '8',
      'تسعة': '9',
    };
    ar.forEach((k, v) {
      s = s.replaceAll(k, v);
    });

    // Remove common separators & invisible chars
    s = s.replaceAll(RegExp(r'[\s\-\(\)\[\]\{\}\._,;:/\\|]+'), '');

    // Keep only digits and plus (optional)
    s = s.replaceAll(RegExp(r'[^0-9\+]'), '');

    return s;
  }

  String _arabicIndicToLatinDigits(String input) {
    const map = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    };

    var out = input;
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /*bool _containsPhoneNumber(String text) {
    final s = text.trim();

    // Remove spaces, dashes, parentheses to catch "010-123 45678"
    final normalized = s.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // 1) Egypt common formats:
    // 010xxxxxxxx / 011xxxxxxxx / 012xxxxxxxx / 015xxxxxxxx (11 digits)
    // +2010xxxxxxxx / 2010xxxxxxxx (12-13 digits with country code)
    final egyptLocal = RegExp(r'\b01[0-2,5]\d{8}\b'); // 11 digits
    final egyptIntlPlus = RegExp(r'\+20?1[0-2,5]\d{8}\b'); // +2010xxxxxxxx (rough)
    final egyptIntlNoPlus = RegExp(r'\b20?1[0-2,5]\d{8}\b'); // 2010xxxxxxxx or 210xxxxxxxx (rough)

    if (egyptLocal.hasMatch(s)) return true;
    if (egyptIntlPlus.hasMatch(normalized)) return true;
    if (egyptIntlNoPlus.hasMatch(normalized)) return true;

    // 2) Generic: if message contains a long digit sequence (7+ digits) => treat as phone.
    // This catches "1234567", "00201123456789", etc.
    final genericDigits = RegExp(r'\d{7,}');
    if (genericDigits.hasMatch(normalized)) return true;

    return false;
  }*/

  void _showPhoneBlocked() {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc?.tr('cant_send_phone_number') ?? "Can't send phone number in chat"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    // ✅ BLOCK phone numbers
    if (_containsPhoneNumber(message)) {
      _showPhoneBlocked();
      return;
    }

    setState(() => _isSending = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      // If chat doesn't exist yet, create it first
      if (_actualChatId == null && widget.otherUserId != null) {
        print('📝 Creating new chat with user ${widget.otherUserId}');
        final chatResponse = await ApiService.startChat(
          token: token,
          otherUserId: widget.otherUserId!,
        );
        _actualChatId = chatResponse['chat_id'];
        print('✅ Chat created with ID: $_actualChatId');

        // Start auto-refresh timer now that chat exists
        _refreshTimer = Timer.periodic(Duration(seconds: 3), (timer) {
          _loadMessages(silent: true);
        });
      }

      final response = await ApiService.sendMessage(
        token: token,
        chatId: _actualChatId!,
        message: message,
      );

      print('📬 Send message response: $response');

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
          final errorMsg = response['message'] ?? AppLocalizations.of(context)!.tr('failed_to_start_chat');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
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

  void _showDeleteMessageOptions(int messageId) {
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
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  AppLocalizations.of(context)!.tr('delete_message'),
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
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

  Future<void> _deleteMessage(int messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await ApiService.deleteMessage(token, messageId);

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
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
              backgroundImage: widget.otherUserPhoto != null
                  ? NetworkImage(widget.otherUserPhoto!)
                  : null,
              child: widget.otherUserPhoto == null
                  ? Text(
                widget.otherUserName[0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              )
                  : null,
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
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMine, bool isDark) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMine) {
            _showDeleteMessageOptions(message['id']);
          }
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isMine
                ? AppColors.primary
                : (isDark ? AppColors.cardDark : Colors.grey[200]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: isMine ? Radius.circular(16) : Radius.circular(4),
              bottomRight: isMine ? Radius.circular(4) : Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Text(
                  message['sender_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
                  ),
                ),
              if (!isMine) SizedBox(height: 4),
              Text(
                message['message'] ?? '',
                style: TextStyle(
                  color: isMine ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _formatTime(message['created_at']),
                style: TextStyle(
                  fontSize: 11,
                  color: isMine ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    final loc = AppLocalizations.of(context);

    final bool disableSend = _isSending || _messageController.text.trim().isEmpty || _phoneBlockedLive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.backgroundDark : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: _phoneBlockedLive
                          ? Border.all(color: Colors.red.withOpacity(0.7), width: 1.2)
                          : null,
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: loc?.tr('type_message') ?? 'اكتب رسالة...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      maxLines: null,
                      textInputAction: TextInputAction.send,

                      onChanged: (val) {
                        final blocked = _containsPhoneNumber(val);
                        if (blocked != _phoneBlockedLive) {
                          setState(() => _phoneBlockedLive = blocked);
                        } else {
                          // عشان زر الإرسال يحدث لما النص يفضى/يمتلئ
                          setState(() {});
                        }
                      },

                      onSubmitted: (_) {
                        if (_phoneBlockedLive) {
                          _showPhoneBlocked();
                          return;
                        }
                        _sendMessage();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // زر الإرسال
                GestureDetector(
                  onTap: disableSend
                      ? () {
                    if (_phoneBlockedLive) _showPhoneBlocked();
                  }
                      : _sendMessage,
                  child: Opacity(
                    opacity: disableSend ? 0.5 : 1,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkAccent
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),

            // تحذير أسفل الحقل (Live)
            if (_phoneBlockedLive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc?.tr('cant_send_phone_number') ?? 'ممنوع إرسال أرقام هاتف داخل الدردشة',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
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