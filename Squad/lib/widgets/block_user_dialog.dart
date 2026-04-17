import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import '../utils/app_localizations.dart';

class BlockUserDialog extends StatefulWidget {
  final int userId;
  final String userName;
  final VoidCallback? onBlocked;

  const BlockUserDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.onBlocked,
  });

  @override
  State<BlockUserDialog> createState() => _BlockUserDialogState();
}

class _BlockUserDialogState extends State<BlockUserDialog> {
  bool _isBlocking = false;

  Future<void> _blockUser() async {
    setState(() => _isBlocking = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      await ApiService.blockUser(
        token: token,
        userId: widget.userId,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onBlocked?.call();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.tr('error') ?? 'خطأ'}: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBlocking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.block, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc?.tr('block_user') ?? 'حظر المستخدم',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${loc?.tr('confirm_block') ?? 'هل أنت متأكد من حظر'} ${widget.userName}?',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc?.tr('block_warning') ?? 'لن يتمكن هذا المستخدم من رؤية منشوراتك أو إرسال رسائل لك',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isBlocking ? null : () => Navigator.pop(context, false),
          child: Text(
            loc?.tr('cancel') ?? 'إلغاء',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isBlocking ? null : _blockUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isBlocking
              ? const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Text(loc?.tr('block') ?? 'حظر'),
        ),
      ],
    );
  }
}
