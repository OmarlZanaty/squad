import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import '../utils/app_localizations.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final token = await AuthService.getToken();
      _token = token;
      
      if (token != null) {
        final result = await ApiService.getBlockedUsers(token);
        if (result['success'] == true && result['data'] != null) {
          setState(() {
            _blockedUsers = result['data'];
          });
        }
      }
    } catch (e) {
      print('Error loading blocked users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(int userId, String userName) async {
    final loc = AppLocalizations.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.cardDark 
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc?.tr('unblock_user') ?? 'إلغاء حظر المستخدم',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : AppColors.textPrimary,
          ),
        ),
        content: Text(
          '${loc?.tr('confirm_unblock') ?? 'هل تريد إلغاء حظر'} $userName?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[300] 
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              loc?.tr('cancel') ?? 'إلغاء',
              style: TextStyle(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(
              loc?.tr('unblock') ?? 'إلغاء الحظر',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && _token != null) {
      try {
        final result = await ApiService.unblockUser(
          token: _token!,
          userId: userId,
        );
        
        if (result['success'] == true) {
          setState(() {
            _blockedUsers.removeWhere((user) => user['id'] == userId);
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc?.tr('user_unblocked') ?? 'تم إلغاء حظر المستخدم'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc?.tr('error') ?? 'خطأ'}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 1,
        title: Text(
          loc?.tr('blocked_users') ?? 'المستخدمون المحظورون',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState(loc, isDark)
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return _buildUserCard(user, isDark, loc);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? loc, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 80,
            color: AppColors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            loc?.tr('no_blocked_users') ?? 'لا يوجد مستخدمون محظورون',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc?.tr('blocked_users_hint') ?? 'المستخدمون الذين تحظرهم سيظهرون هنا',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isDark, AppLocalizations? loc) {
    final String name = user['name'] ?? 'Unknown';
    final String? photoUrl = user['profile_photo_url'];
    final String type = user['type'] ?? '';
    final String blockedAt = user['blocked_at'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.grey.withOpacity(0.2),
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl.startsWith('http') 
                  ? photoUrl 
                  : 'http://187.124.37.68:3000$photoUrl')
              : null,
          child: photoUrl == null || photoUrl.isEmpty
              ? Icon(Icons.person, color: AppColors.grey, size: 28)
              : null,
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type.isNotEmpty)
              Text(
                type == 'player' 
                    ? (loc?.tr('player') ?? 'لاعب')
                    : type == 'scout' 
                        ? (loc?.tr('scout') ?? 'كشاف')
                        : type,
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _unblockUser(user['id'], name),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: Text(loc?.tr('unblock') ?? 'إلغاء الحظر'),
        ),
      ),
    );
  }
}
