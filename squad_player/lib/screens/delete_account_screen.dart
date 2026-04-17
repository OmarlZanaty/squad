import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:squad_player/utils/app_localizations.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  Future<void> _redirectToWhatsApp(BuildContext context) async {
    const phoneNumber = '201003100623'; // your support number

    final uri = Uri.parse(
      'https://wa.me/$phoneNumber?text=I%20want%20to%20delete%20my%20account',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.tr('cannot_open_whatsapp'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('delete_account')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              loc.tr('delete_account_warning'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // SAME BUTTON – LOCALIZED
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _redirectToWhatsApp(context),
              child: Text(loc.tr('delete_my_account')),
            ),
          ],
        ),
      ),
    );
  }
}
