import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import '../utils/app_localizations.dart';

class TermsOfUseScreen extends StatefulWidget {
  final VoidCallback? onAccepted;
  final bool showAcceptButton;

  const TermsOfUseScreen({
    super.key,
    this.onAccepted,
    this.showAcceptButton = true,
  });

  @override
  State<TermsOfUseScreen> createState() => _TermsOfUseScreenState();
}

class _TermsOfUseScreenState extends State<TermsOfUseScreen> {
  bool _hasScrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToEnd) {
        setState(() {
          _hasScrolledToEnd = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(loc?.tr('terms_conditions') ?? 'الشروط والأحكام'),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    isDark,
                    loc?.tr('terms_intro_title') ?? 'مقدمة',
                    loc?.tr('terms_intro_content') ?? '''
مرحباً بك في تطبيق سكواد. باستخدامك لهذا التطبيق، فإنك توافق على الالتزام بهذه الشروط والأحكام. يرجى قراءتها بعناية قبل استخدام التطبيق.

تطبيق سكواد هو منصة تواصل اجتماعي مخصصة للاعبي كرة القدم والمستكشفين والمدربين. نحن نسعى لتوفير بيئة آمنة ومهنية لجميع المستخدمين.
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_account_title') ?? 'حسابك',
                    loc?.tr('terms_account_content') ?? '''
• يجب أن تكون بعمر 13 سنة على الأقل لاستخدام التطبيق
• أنت مسؤول عن الحفاظ على سرية معلومات حسابك
• يجب تقديم معلومات دقيقة وصحيحة عند التسجيل
• لا يجوز مشاركة حسابك مع الآخرين
• يحق لنا تعليق أو إنهاء حسابك في حالة انتهاك هذه الشروط
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_content_title') ?? 'المحتوى والسلوك',
                    loc?.tr('terms_content_content') ?? '''
أنت مسؤول عن جميع المحتوى الذي تنشره. يُحظر:

• نشر محتوى مسيء أو عنيف أو تمييزي
• التحرش بالمستخدمين الآخرين أو تهديدهم
• نشر معلومات كاذبة أو مضللة
• انتحال شخصية الآخرين
• نشر محتوى ينتهك حقوق الملكية الفكرية
• استخدام التطبيق لأغراض غير قانونية
• إرسال رسائل غير مرغوب فيها (سبام)
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_privacy_title') ?? 'الخصوصية',
                    loc?.tr('terms_privacy_content') ?? '''
نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. يرجى مراجعة سياسة الخصوصية الخاصة بنا لمعرفة كيفية جمع واستخدام وحماية معلوماتك.

نحن نجمع البيانات اللازمة لتشغيل التطبيق وتحسين تجربتك. لن نشارك بياناتك مع أطراف ثالثة دون موافقتك.
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_ip_title') ?? 'حقوق الملكية الفكرية',
                    loc?.tr('terms_ip_content') ?? '''
جميع حقوق الملكية الفكرية للتطبيق، بما في ذلك التصميم والشعارات والمحتوى، محفوظة لنا.

المحتوى الذي تنشره يبقى ملكاً لك، لكنك تمنحنا ترخيصاً غير حصري لاستخدامه وعرضه في التطبيق.
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_termination_title') ?? 'إنهاء الحساب',
                    loc?.tr('terms_termination_content') ?? '''
يمكنك حذف حسابك في أي وقت من إعدادات التطبيق. عند حذف الحساب:

• سيتم حذف جميع بياناتك الشخصية
• سيتم حذف جميع منشوراتك وتعليقاتك
• لن تتمكن من استرداد حسابك بعد الحذف
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_changes_title') ?? 'التغييرات على الشروط',
                    loc?.tr('terms_changes_content') ?? '''
نحتفظ بالحق في تعديل هذه الشروط في أي وقت. سيتم إخطارك بأي تغييرات جوهرية. استمرارك في استخدام التطبيق بعد التغييرات يعني موافقتك عليها.
''',
                  ),
                  _buildSection(
                    isDark,
                    loc?.tr('terms_contact_title') ?? 'التواصل معنا',
                    loc?.tr('terms_contact_content') ?? '''
إذا كانت لديك أي أسئلة حول هذه الشروط، يمكنك التواصل معنا عبر:

رقم التليفون: 01003100623
''',
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      loc?.tr('last_updated') ?? 'آخر تحديث: إبريل 2026',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (widget.showAcceptButton)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (!_hasScrolledToEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        loc?.tr('scroll_to_accept') ?? 'قم بالتمرير للأسفل لقراءة جميع الشروط',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _hasScrolledToEnd
                          ? () {
                        widget.onAccepted?.call();
                        Navigator.pop(context, true);
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkModeAccent : AppColors.primary,
                        foregroundColor: isDark ? AppColors.black : Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        loc?.tr('accept_terms') ?? 'أوافق على الشروط والأحكام',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(bool isDark, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.grey[300] : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
