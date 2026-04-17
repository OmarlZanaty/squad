import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:squad_player/services/auth_service.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/screens/login_screen.dart';
import 'package:squad_player/providers/theme_provider.dart';
import 'package:squad_player/providers/language_provider.dart';
import 'package:squad_player/utils/app_localizations.dart';
import 'package:squad_player/screens/terms_of_use_screen.dart';
import 'package:squad_player/screens/privacy_policy_screen.dart';
import 'package:squad_player/screens/delete_account_screen.dart';

import '../services/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _appVersion = '1.0.0';

  // ================= LOGOUT =================
  Future<void> _logout() async {
    final loc = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(loc.tr('logout')),
        content: Text(loc.tr('confirm_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(loc.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.tr('logout')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ✅ clear everything once
    await AuthService.logout(); // SharedPreferences
    await SecureStorageService.clearToken(); // Secure token
    await SecureStorageService.setBiometricEnabled(false); // Disable biometric

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }


  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open link')),
      );
    }
  }

  // ================= LANGUAGE =================
  void _showLanguageDialog() {
    final languageProvider = context.read<LanguageProvider>();
    final currentLang = languageProvider.locale.languageCode;
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.tr('choose_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(loc.tr('arabic')),
              value: 'ar',
              groupValue: currentLang,
              onChanged: (val) async {
                if (val != currentLang) {
                  await languageProvider.setLanguage(val!);
                }
                if (mounted) Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text(loc.tr('english')),
              value: 'en',
              groupValue: currentLang,
              onChanged: (val) async {
                if (val != currentLang) {
                  await languageProvider.setLanguage(val!);
                }
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= ABOUT =================
  void _showAboutDialog() {
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 36),
            const SizedBox(width: 10),
            Text(loc.tr('about_app')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${loc.tr('version')} $_appVersion'),
            const SizedBox(height: 8),
            Text(loc.tr('app_description')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.tr('ok')),
          ),
        ],
      ),
    );
  }

  // ================= WHATSAPP =================
  Future<void> _openWhatsApp() async {
    final loc = AppLocalizations.of(context)!;
    final uri = Uri.parse(
      'https://api.whatsapp.com/send?phone=201003100623',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.tr('cannot_open_whatsapp'))),
        );
      }
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========= APPEARANCE =========
          _section(loc.tr('appearance')),
          Consumer<ThemeProvider>(
            builder: (_, theme, __) => _card(
              icon: Icons.dark_mode,
              title: loc.tr('dark_mode'),
              subtitle:
              theme.isDarkMode ? loc.tr('enabled') : loc.tr('disabled'),
              trailing: Switch(
                value: theme.isDarkMode,
                onChanged: (_) => theme.toggleTheme(),
                activeColor:
                isDark ? AppColors.darkAccent : AppColors.primary,
              ),
            ),
          ),
          _card(
            icon: Icons.language,
            title: loc.tr('language'),
            subtitle: context.watch<LanguageProvider>().isArabic
                ? loc.tr('arabic')
                : loc.tr('english'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showLanguageDialog,
          ),

          const SizedBox(height: 24),

          // ========= NOTIFICATIONS =========
          _section(loc.tr('notifications')),
          _card(
            icon: Icons.notifications,
            title: loc.tr('notifications'),
            subtitle: _notificationsEnabled
                ? loc.tr('enabled_feminine')
                : loc.tr('disabled_feminine'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (v) =>
                  setState(() => _notificationsEnabled = v),
            ),
          ),
          _card(
            icon: Icons.volume_up,
            title: loc.tr('sounds'),
            subtitle: _soundEnabled
                ? loc.tr('enabled_feminine')
                : loc.tr('disabled_feminine'),
            trailing: Switch(
              value: _soundEnabled,
              onChanged: (v) => setState(() => _soundEnabled = v),
            ),
          ),

          const SizedBox(height: 24),

          // ========= LEGAL =========
          _section(loc.tr('legal')),
          _card(
            icon: Icons.description,
            title: loc.tr('terms_conditions'),
            subtitle: loc.tr('view_terms_conditions'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const TermsOfUseScreen(showAcceptButton: false),
              ),
            ),
          ),
          _card(
            icon: Icons.privacy_tip,
            title: loc.tr('privacy_policy'),
            subtitle: loc.tr('view_privacy_policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),

          const SizedBox(height: 24),



          // ========= DANGER =========
          _section(loc.tr('danger_zone'), red: true),
          _card(
            icon: Icons.delete_forever,
            title: loc.tr('delete_account'),
            subtitle: loc.tr('delete_account_warning'),
            isRed: true,
            trailing:
            const Icon(Icons.arrow_forward_ios, color: Colors.red),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DeleteAccountScreen(),
              ),
            ),
          ),

          const SizedBox(height: 24),
          // ========= SUPPORT =========
          _section(loc.tr('support')),

// HELP CENTER (WhatsApp)
          _card(
            icon: Icons.help,
            title: loc.tr('help_center'),
            subtitle: loc.tr('get_help'),
            trailing: const FaIcon(
                FontAwesomeIcons.whatsapp, color: Colors.green),
            onTap: _openWhatsApp,
          ),

          const SizedBox(height: 12),

// CONTACT US (SOCIAL MEDIA)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.contact_support, color: AppColors.primary),
              ),
              title: Text(loc.tr('contact_us')),
              subtitle: Text(loc.tr('send_us_message')),
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
                    icon: const FaIcon(
                        FontAwesomeIcons.instagram, color: Color(0xFFE4405F)),
                    onPressed: () => _openUrl(
                      'https://www.instagram.com/squad.1446?utm_source=qr&igsh=MWE2b3Brd24zZXl1eQ==',
                    ),
                  ),

                  // TIKTOK (fallback icon)
                  IconButton(
                    icon: const Icon(Icons.tiktok, color: Colors.black),
                    onPressed: () => _openUrl(
                      'https://www.tiktok.com/@squad.1446',
                    ),
                  ),
                ],
              ),
            ),
          ),


          const SizedBox(height: 32),

          // ========= LOGOUT =========
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(loc.tr('logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),



          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ================= HELPERS =================
  Widget _section(String title, {bool red = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: red ? Colors.red : AppColors.primary,
      ),
    ),
  );

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isRed = false,
  }) {
    final color = isRed ? Colors.red : AppColors.primary;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: TextStyle(color: isRed ? Colors.red : null)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
