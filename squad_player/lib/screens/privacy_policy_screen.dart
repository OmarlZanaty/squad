import 'package:flutter/material.dart';
import 'package:squad_player/utils/app_colors.dart';
import '../utils/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          loc?.tr('privacy_policy') ?? 'سياسة الخصوصية',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: loc?.tr('privacy_intro_title') ?? 'مقدمة',
              content: loc?.tr('privacy_intro_content') ??
                  'نحن في سكواد نلتزم بحماية خصوصيتك. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية معلوماتك الشخصية عند استخدام تطبيقنا.',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_data_collected_title') ?? 'البيانات التي نجمعها',
              content: loc?.tr('privacy_data_collected_content') ??
                  'نقوم بجمع الأنواع التالية من المعلومات:\n\n'
                      '• معلومات الحساب: الاسم، البريد الإلكتروني، رقم الهاتف\n'
                      '• معلومات الملف الشخصي: الصورة، الموقع، المركز، النادي\n'
                      '• المحتوى المنشور: المنشورات، التعليقات، الصور، الفيديوهات\n'
                      '• بيانات الاستخدام: كيفية تفاعلك مع التطبيق\n'
                      '• معلومات الجهاز: نوع الجهاز، نظام التشغيل',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_data_use_title') ?? 'كيف نستخدم بياناتك',
              content: loc?.tr('privacy_data_use_content') ??
                  'نستخدم المعلومات التي نجمعها للأغراض التالية:\n\n'
                      '• تقديم وتحسين خدماتنا\n'
                      '• إنشاء وإدارة حسابك\n'
                      '• التواصل معك بشأن التحديثات والإشعارات\n'
                      '• ضمان أمان التطبيق ومنع الاحتيال\n'
                      '• تحليل استخدام التطبيق لتحسين تجربة المستخدم',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_data_sharing_title') ?? 'مشاركة البيانات',
              content: loc?.tr('privacy_data_sharing_content') ??
                  'لا نبيع معلوماتك الشخصية لأطراف ثالثة. قد نشارك معلوماتك في الحالات التالية:\n\n'
                      '• مع مقدمي الخدمات الذين يساعدوننا في تشغيل التطبيق\n'
                      '• عند الاقتضاء بموجب القانون أو لحماية حقوقنا\n'
                      '• مع موافقتك الصريحة',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_data_security_title') ?? 'أمان البيانات',
              content: loc?.tr('privacy_data_security_content') ??
                  'نتخذ إجراءات أمنية مناسبة لحماية معلوماتك من الوصول غير المصرح به أو التغيير أو الإفصاح أو الإتلاف. تشمل هذه الإجراءات التشفير والتحكم في الوصول والمراقبة المستمرة.',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_data_retention_title') ?? 'الاحتفاظ بالبيانات',
              content: loc?.tr('privacy_data_retention_content') ??
                  'نحتفظ بمعلوماتك طالما كان حسابك نشطًا أو حسب الحاجة لتقديم خدماتنا. يمكنك طلب حذف حسابك وبياناتك في أي وقت من خلال إعدادات التطبيق.',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_user_rights_title') ?? 'حقوقك',
              content: loc?.tr('privacy_user_rights_content') ??
                  'لديك الحقوق التالية فيما يتعلق ببياناتك:\n\n'
                      '• الوصول إلى بياناتك الشخصية\n'
                      '• تصحيح البيانات غير الدقيقة\n'
                      '• حذف حسابك وبياناتك\n'
                      '• الاعتراض على معالجة بياناتك\n'
                      '• نقل بياناتك إلى خدمة أخرى',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_children_title') ?? 'خصوصية الأطفال',
              content: loc?.tr('privacy_children_content') ??
                  'تطبيقنا غير موجه للأطفال دون سن 13 عامًا. لا نجمع عن قصد معلومات شخصية من الأطفال. إذا علمنا أننا جمعنا معلومات من طفل، سنتخذ خطوات لحذفها.',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_cookies_title') ?? 'ملفات تعريف الارتباط',
              content: loc?.tr('privacy_cookies_content') ??
                  'نستخدم ملفات تعريف الارتباط والتقنيات المماثلة لتحسين تجربتك وتحليل استخدام التطبيق. يمكنك التحكم في إعدادات ملفات تعريف الارتباط من خلال إعدادات جهازك.',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_changes_title') ?? 'التغييرات على السياسة',
              content: loc?.tr('privacy_changes_content') ??
                  'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سنقوم بإخطارك بأي تغييرات جوهرية عبر التطبيق أو البريد الإلكتروني.',
              isDark: isDark,
            ),
            _buildSection(
              title: loc?.tr('privacy_contact_title') ?? 'اتصل بنا',
              content: loc?.tr('privacy_contact_content') ??
                  'إذا كانت لديك أي أسئلة حول سياسة الخصوصية هذه أو ممارسات البيانات الخاصة بنا، يرجى التواصل معنا:\n\n'
                      'البريد الإلكتروني: privacy@squad-app.com\n'
                      'العنوان: [عنوان الشركة]',
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            Text(
              loc?.tr('privacy_last_updated') ?? 'آخر تحديث: ديسمبر 2025',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required bool isDark,
  }) {
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
