import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:squad/providers/notification_provider.dart';
import 'package:squad/screens/notification_screen.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  String t(BuildContext context, String key) {
    return AppLocalizations.of(context)?.tr(key) ?? key;
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final phone = phoneNumber.replaceAll('+', '');

    final Uri scheme = Uri.parse('whatsapp://send?phone=$phone');

    try {
      final ok = await launchUrl(
        scheme,
        mode: LaunchMode.externalApplication,
      );

      if (ok) return;
    } catch (_) {}

    final Uri web = Uri.parse('https://wa.me/$phone');

    try {
      await launchUrl(
        web,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not available')),
      );
    }
  }

  void showContactOptions(BuildContext context, String phoneNumber) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              // 📞 CALL
              ListTile(
                leading: Icon(Icons.phone, color: isDark ? Colors.white : null),
                title: Text(t(context, 'contact_call')),
                onTap: () async {
                  Navigator.pop(context);

                  final uri = Uri(scheme: 'tel', path: phoneNumber);

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),

              // 💬 WHATSAPP (FIXED)
              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                ),
                title: Text(t(context, 'contact_whatsapp')),
                onTap: () async {
                  Navigator.pop(context); // close bottom sheet

                  final phone = phoneNumber.replaceAll('+', '');
                  final uri = Uri.parse('whatsapp://send?phone=$phone');

                  try {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {
                    final web = Uri.parse('https://wa.me/$phone');

                    await launchUrl(
                      web,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = context.watch<NotificationProvider>().unreadCount;

    return AppBar(
      // ✅ this prevents any default system title like "SQUAD"
      title: const SizedBox.shrink(),
      centerTitle: true,
      automaticallyImplyLeading: false,

      // ✅ remove Material3 tint that sometimes changes the top area
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: isDark ? AppColors.shadowDark : AppColors.shadow,

      // ✅ your custom layout lives here
      flexibleSpace: SafeArea(
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔔 Notifications
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 28,
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                      tooltip: t(context, 'notifications'),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationScreen()),
                        );
                        context.read<NotificationProvider>().refreshUnreadCount(silent: true);
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccent : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              count > 99 ? t(context, 'notifications_99_plus') : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // 🏷 Logo
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo3.png',
                      height: 80, // ✅ IMPORTANT: AppBar height is 70, so 140 was too big
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          t(context, 'app_name'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 📞 Contact
                IconButton(
                  tooltip: t(context, 'contact_support'),
                  icon: Image.asset(
                    isDark
                        ? 'assets/images/ringing_phone_white.png'
                        : 'assets/images/ringing_phone_black.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.phone,
                        size: 28,
                        color: isDark ? Colors.white : AppColors.black,
                      );
                    },
                  ),
                  onPressed: () => showContactOptions(context, '+201003100623'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}