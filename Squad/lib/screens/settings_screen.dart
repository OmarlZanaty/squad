import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/screens/login_screen.dart';
import 'package:squad/providers/theme_provider.dart';
import 'package:squad/utils/language_provider.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/widgets/app_bottom_bar.dart';
import 'package:squad/screens/terms_of_use_screen.dart';
import 'package:squad/screens/privacy_policy_screen.dart';
import 'package:squad/screens/delete_account_screen.dart';
import 'package:squad/screens/blocked_users_screen.dart';
import 'package:squad/screens/version_check_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    //_loadAppVersion();
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url.trim());
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showSnack('لا يمكن فتح الرابط');
    } catch (e) {
      _showSnack('لا يمكن فتح الرابط');
    }
  }


  Future<void> _openWhatsApp() async {
    const phoneNumber = '201003100623'; // no '+'
    const message = 'أهلا مستخدم إسكواد';
    final text = Uri.encodeComponent(message);

    final Uri appUrl = Uri.parse('whatsapp://send?phone=$phoneNumber&text=$text');
    final Uri webUrl = Uri.parse('https://wa.me/$phoneNumber?text=$text');

    try {
      final ok = await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      if (!ok) {
        final okWeb = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        if (!okWeb) _showSnack('Cannot open WhatsApp');
      }
    } catch (_) {
      try {
        final okWeb = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        if (!okWeb) _showSnack('Cannot open WhatsApp');
      } catch (e) {
        _showSnack('Cannot open WhatsApp');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }



  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(AppLocalizations.of(context)!.tr('logout')),
        content: Text(AppLocalizations.of(context)!.tr('confirm_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.tr('logout')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _showLanguageDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.locale.languageCode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(AppLocalizations.of(context)!.tr('choose_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(AppLocalizations.of(context)!.tr('arabic')),
              value: 'ar',
              groupValue: currentLanguage,
              onChanged: (value) async {
                if (value != currentLanguage) {
                  await languageProvider.changeLanguage(value!);
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => SettingsScreen()),
                          (route) => route.isFirst,
                    );
                  }
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: Text(AppLocalizations.of(context)!.tr('english')),
              value: 'en',
              groupValue: currentLanguage,
              onChanged: (value) async {
                if (value != currentLanguage) {
                  await languageProvider.changeLanguage(value!);
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => SettingsScreen()),
                          (route) => route.isFirst,
                    );
                  }
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 40),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.tr('about_app')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context)!.tr('version')} $_appVersion'),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.tr('app_description')),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.tr('copyright')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.tr('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.tr('settings')),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader(loc.tr('appearance')),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return _buildSettingCard(
                icon: Icons.dark_mode,
                title: loc.tr('dark_mode'),
                subtitle: themeProvider.isDarkMode ? loc.tr('enabled') : loc.tr('disabled'),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) async {
                    await themeProvider.toggleTheme();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? loc.tr('dark_mode_enabled') : loc.tr('dark_mode_disabled')),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  activeColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              final isArabic = languageProvider.locale.languageCode == 'ar';
              return _buildSettingCard(
                icon: Icons.language,
                title: loc.tr('language'),
                subtitle: isArabic ? loc.tr('arabic') : loc.tr('english'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showLanguageDialog,
              );
            },
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(loc.tr('notifications')),
          _buildSettingCard(
            icon: Icons.notifications,
            title: loc.tr('notifications'),
            subtitle: _notificationsEnabled ? loc.tr('enabled_feminine') : loc.tr('disabled_feminine'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? loc.tr('notifications_enabled') : loc.tr('notifications_disabled')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              activeColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            icon: Icons.volume_up,
            title: loc.tr('sounds'),
            subtitle: _soundEnabled ? loc.tr('enabled_feminine') : loc.tr('disabled_feminine'),
            trailing: Switch(
              value: _soundEnabled,
              onChanged: (value) {
                setState(() => _soundEnabled = value);
              },
              activeColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
            ),
          ),

          const SizedBox(height: 24),

          // Privacy & Security Section
          _buildSectionHeader(loc.tr('privacy_security') ?? 'الخصوصية والأمان'),
          _buildSettingCard(
            icon: Icons.block,
            title: loc.tr('blocked_users') ?? 'المستخدمون المحظورون',
            subtitle: loc.tr('manage_blocked_users') ?? 'إدارة قائمة الحظر',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // App Section
          _buildSectionHeader(loc.tr('app') ?? 'التطبيق'),
          _buildSettingCard(
            icon: Icons.info,
            title: loc.tr('about_app'),
            subtitle: '${loc.tr('version')} $_appVersion',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showAboutDialog,
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            icon: Icons.system_update_alt,
            title: 'Version check',
            subtitle: 'Check backend minimum/latest version status',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VersionCheckScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Legal Section (Terms & Privacy)
          _buildSectionHeader(loc.tr('legal') ?? 'القانونية'),
          _buildSettingCard(
            icon: Icons.description,
            title: loc.tr('terms_conditions'),
            subtitle: loc.tr('view_terms_conditions'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfUseScreen(showAcceptButton: false)),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            icon: Icons.privacy_tip,
            title: loc.tr('privacy_policy'),
            subtitle: loc.tr('view_privacy_policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),

          const SizedBox(height: 24),


          // ========= DANGER =========
          _buildSectionHeader(loc.tr('danger_zone') ?? 'منطقة الخطر', isRed: true),
          _buildSettingCard(
            icon: Icons.delete_forever,
            title: loc.tr('delete_account') ?? 'حذف الحساب',
            subtitle: loc.tr('delete_account_warning') ?? 'حذف حسابك نهائيًا',
            isRed: true,
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
            ),
          ),

          const SizedBox(height: 24),

// ========= SUPPORT =========
          _buildSectionHeader(loc.tr('support') ?? 'الدعم'),

// HELP CENTER (WhatsApp)
          _buildSettingCard(
            icon: Icons.help,
            title: loc.tr('help_center') ?? 'مركز المساعدة',
            subtitle: loc.tr('get_help') ?? 'احصل على مساعدة',
            trailing: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
            onTap: _openWhatsApp,
          ),

          const SizedBox(height: 12),

// CONTACT US (SOCIAL MEDIA)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.check_circle, color: AppColors.primary),
              ),
              title: Text(loc.tr('contact_us') ?? 'تواصل معنا'),
              subtitle: Text(loc.tr('send_us_message') ?? 'أرسل لنا رسالة'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FACEBOOK
                  IconButton(
                    icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                    onPressed: () => _openUrl(
                      'https://www.facebook.com/profile.php?id=61584973333900&rdid=KdZCSPvmnbhKWxkr&share_url=https%3A%2F%2Fwww.facebook.com%2Fshare%2F17FSFJDChi%2F#',
                    ),
                  ),

                  // INSTAGRAM
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFFE4405F)),
                    onPressed: () => _openUrl(
                      'https://www.instagram.com/squad.1447?igsh=MWE2b3Brd24zZXl1eQ==',
                    ),
                  ),

                  // TIKTOK
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.tiktok, color: Colors.black),
                    onPressed: () => _openUrl(
                      'https://www.tiktok.com/@squad.2026',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Logout Button
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(loc.tr('logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(
            height: 80 + MediaQuery.of(context).padding.bottom,
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isRed
              ? Colors.red
              : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isRed = false,
  }) {
    final primaryColor = isRed
        ? Colors.red
        : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRed
              ? Colors.red.withOpacity(0.3)
              : Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isRed ? Colors.red : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isRed ? Colors.red.withOpacity(0.7) : Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 14,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
