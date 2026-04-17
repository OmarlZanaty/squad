import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import '../utils/app_localizations.dart';

class ReportContentSheet extends StatefulWidget {
  final int contentId;
  final String contentType; // 'post', 'comment', or 'user'
  final String contentTitle;

  const ReportContentSheet({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.contentTitle,
  });

  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _token;

  final List<Map<String, String>> _reportReasons = [
    {'key': 'impersonation', 'ar': 'انتحال شخصية', 'en': 'Impersonation'},
    {'key': 'impersonation', 'ar': 'نشر معلومات كاذبة', 'en': 'Fake News'},
    {'key': 'copyright', 'ar': 'انتهاك حقوق الملكية', 'en': 'Copyright violation'},
    {'key': 'spam', 'ar': 'محتوى مزعج', 'en': 'Spam'},
    {'key': 'spam', 'ar': 'محتوى محرض', 'en': 'Hate'},
    {'key': 'violence', 'ar': 'محتوى عنصرى', 'en': 'Violence'},
    {'key': 'sexual_content', 'ar': 'محتوى جنسي', 'en': 'Sexual content'},
    {'key': 'false_info', 'ar': 'محتوي غير مناسب للاطفال', 'en': 'Not Good For Kids'},
    {'key': 'other', 'ar': 'سبب آخر', 'en': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await AuthService.getToken();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.tr('select_reason') ?? 'الرجاء اختيار سبب الإبلاغ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.tr('login_required') ?? 'يجب تسجيل الدخول'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.reportContent(
        token: _token!,
        contentId: widget.contentId,
        contentType: widget.contentType,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] == true
                ? (AppLocalizations.of(context)?.tr('report_submitted') ?? 'تم إرسال البلاغ بنجاح')
                : (result['message'] ?? 'حدث خطأ')),
            backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String getContentTypeLabel() {
      switch (widget.contentType) {
        case 'post':
          return loc?.tr('post') ?? 'منشور';
        case 'comment':
          return loc?.tr('comment') ?? 'تعليق';
        case 'user':
          return loc?.tr('user') ?? 'مستخدم';
        default:
          return loc?.tr('content') ?? 'محتوى';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).size.height * 0.10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  const Icon(Icons.flag, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc?.tr('report') ?? 'الإبلاغ عن'} ${getContentTypeLabel()}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        if (widget.contentTitle.isNotEmpty)
                          Text(
                            widget.contentTitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Reason selection
              Text(
                loc?.tr('select_reason') ?? 'اختر سبب الإبلاغ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Reason options
              ...(_reportReasons.map((reason) => RadioListTile<String>(
                value: reason['key']!,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() => _selectedReason = value);
                },
                title: Text(
                  isArabic ? reason['ar']! : reason['en']!,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ))),

              const SizedBox(height: 16),

              // Additional details
              Text(
                loc?.tr('additional_details') ?? 'تفاصيل إضافية (اختياري)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: loc?.tr('report_details_hint') ?? 'أضف تفاصيل إضافية...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.backgroundDark : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    loc?.tr('submit_report') ?? 'إرسال البلاغ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    loc?.tr('cancel') ?? 'إلغاء',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
            );
  }
}
