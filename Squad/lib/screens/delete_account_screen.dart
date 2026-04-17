import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import '../utils/app_localizations.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;
  bool _obscurePassword = true;
  bool _understandConsequences = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await AuthService.getToken();
    setState(() {
      _token = token;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canDelete {
    return _understandConsequences &&
        _passwordController.text.isNotEmpty &&
        _confirmController.text.toLowerCase() == 'delete' &&
        !_isDeleting;
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete) return;

    final loc = AppLocalizations.of(context);

    // Show final confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc?.tr('final_warning') ?? 'تحذير أخير',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          loc?.tr('delete_account_final_confirm') ??
              'هذا الإجراء لا يمكن التراجع عنه. سيتم حذف حسابك وجميع بياناتك نهائيًا.\n\nهل أنت متأكد تمامًا؟',
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
              backgroundColor: AppColors.error,
            ),
            child: Text(
              loc?.tr('yes_delete') ?? 'نعم، احذف حسابي',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await ApiService.deleteAccount(
        token: _token!,
        password: _passwordController.text,
      );

      // Clear local data and logout
      await AuthService.logout();

      if (mounted) {
        // Navigate to login screen and clear all routes
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.tr('account_deleted') ??
                'تم حذف حسابك بنجاح. نأسف لرؤيتك تغادر.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
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
          loc?.tr('delete_account') ?? 'حذف الحساب',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc?.tr('delete_warning') ??
                          'تحذير: حذف حسابك إجراء دائم ولا يمكن التراجع عنه.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // What will be deleted
            Text(
              loc?.tr('what_will_be_deleted') ?? 'ما الذي سيتم حذفه:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildDeleteItem(
              icon: Icons.person_outline,
              text: loc?.tr('delete_profile') ?? 'ملفك الشخصي ومعلوماتك',
              isDark: isDark,
            ),
            _buildDeleteItem(
              icon: Icons.article_outlined,
              text: loc?.tr('delete_posts') ?? 'جميع منشوراتك وتعليقاتك',
              isDark: isDark,
            ),
            _buildDeleteItem(
              icon: Icons.chat_outlined,
              text: loc?.tr('delete_messages') ?? 'جميع رسائلك ومحادثاتك',
              isDark: isDark,
            ),
            _buildDeleteItem(
              icon: Icons.photo_library_outlined,
              text: loc?.tr('delete_media') ?? 'جميع الصور والفيديوهات',
              isDark: isDark,
            ),
            _buildDeleteItem(
              icon: Icons.favorite_outline,
              text: loc?.tr('delete_likes') ?? 'جميع إعجاباتك وتفاعلاتك',
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Confirmation checkbox
            GestureDetector(
              onTap: () {
                setState(() {
                  _understandConsequences = !_understandConsequences;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _understandConsequences
                        ? AppColors.error
                        : AppColors.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _understandConsequences,
                      onChanged: (value) {
                        setState(() {
                          _understandConsequences = value ?? false;
                        });
                      },
                      activeColor: AppColors.error,
                    ),
                    Expanded(
                      child: Text(
                        loc?.tr('understand_delete') ??
                            'أفهم أن هذا الإجراء دائم ولا يمكن التراجع عنه',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Password field
            Text(
              loc?.tr('enter_password') ?? 'أدخل كلمة المرور للتأكيد:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: loc?.tr('password') ?? 'كلمة المرور',
                hintStyle: TextStyle(color: AppColors.grey),
                filled: true,
                fillColor: isDark ? AppColors.cardDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            // Type DELETE confirmation
            Text(
              loc?.tr('type_delete') ?? 'اكتب "delete" للتأكيد:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'delete',
                hintStyle: TextStyle(color: AppColors.grey),
                filled: true,
                fillColor: isDark ? AppColors.cardDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 32),

            // Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canDelete ? _deleteAccount : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor: AppColors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isDeleting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  loc?.tr('delete_my_account') ?? 'حذف حسابي نهائيًا',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _canDelete ? Colors.white : AppColors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  loc?.tr('keep_account') ?? 'الاحتفاظ بحسابي',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteItem({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
