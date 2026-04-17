import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:share_plus/share_plus.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/utils/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialShareWidget extends StatelessWidget {
  final int postId;
  final String postContent;
  final String? mediaUrl;
  final String userName;
  final String baseUrl;

  const SocialShareWidget({
    super.key,
    required this.postId,
    required this.postContent,
    this.mediaUrl,
    required this.userName,
    required this.baseUrl,
  });


  static const _android =
      'https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player';
  static const _ios =
      'https://apps.apple.com/eg/app/%D9%84%D8%A7%D8%B9%D8%A8-%D8%A5%D8%B3%D9%83%D9%88%D8%A7%D8%AF/id6756811939?l=ar';

  String get _shareLink => _android; // used for copy link

  String _getShareMessage(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return '$postContent\n\n${loc?.tr('download_app') ?? 'Download the app:'}\nAndroid: $_android\niOS: $_ios';
  }



  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final loc = AppLocalizations.of(context);

    final message =
        '${loc?.tr('check_out_post_from') ?? 'Check out this post from'} $userName '
        '${loc?.tr('on_squad_player') ?? 'on Squad Player'}:\n\n'
        '$postContent\n\n$_shareLink';

    final encoded = Uri.encodeComponent(message);

    // Try native WhatsApp app first
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');

    // Fallback: wa.me opens WhatsApp if installed, otherwise web
    final waMeUri = Uri.parse('https://wa.me/?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (await canLaunchUrl(waMeUri)) {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Last fallback: system share sheet
      await Share.share(
        message,
        subject: loc?.tr('squad_player_post') ?? 'Squad Player Post',
      );
    } catch (e) {
      debugPrint('Error sharing to WhatsApp: $e');
      // Last fallback
      await Share.share(
        message,
        subject: loc?.tr('squad_player_post') ?? 'Squad Player Post',
      );
    }
  }


  Future<void> _shareViaFacebook(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final message = '${loc?.tr('check_out_post_from') ?? 'Check out this post from'} $userName ${loc?.tr('on_squad_player') ?? 'on Squad Player'}:\n\n$postContent\n\n$_shareLink';

      // Facebook share via Share.share
      await Share.share(
        message,
        subject: loc?.tr('squad_player_post') ?? 'Squad Player Post',
      );
    } catch (e) {
      debugPrint('Error sharing to Facebook: $e');
    }
  }

  Future<void> _shareViaTwitter(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final message = '${loc?.tr('check_out_post_from') ?? 'Check out this post from'} $userName ${loc?.tr('on_squad_player') ?? 'on Squad Player'}: $_shareLink';

      // Twitter share via Share.share
      await Share.share(
        message,
        subject: loc?.tr('squad_player_post') ?? 'Squad Player Post',
      );
    } catch (e) {
      debugPrint('Error sharing to Twitter: $e');
    }
  }

  Future<void> _shareViaEmail(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final subject = '${loc?.tr('squad_player_post') ?? 'Squad Player Post'} ${loc?.tr('from') ?? 'from'} $userName';
      final body = '$postContent\n\n${loc?.tr('check_it_out') ?? 'Check it out'}: $_shareLink';

      // Email share via Share.share
      await Share.share(
        body,
        subject: subject,
      );
    } catch (e) {
      debugPrint('Error sharing via email: $e');
    }
  }

  Future<void> _shareGeneral(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      await Share.share(
        _getShareMessage(context),
        subject: loc?.tr('squad_player_post') ?? 'Squad Player Post',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  void _showShareOptions(BuildContext context) {
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF25D366)),
              title: Text(loc?.tr('share_whatsapp') ?? 'Share via WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _shareViaWhatsApp(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: Text(loc?.tr('share_more') ?? 'More Options'),
              onTap: () {
                Navigator.pop(context);
                _shareGeneral(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(loc?.tr('copy_link') ?? 'Copy Link'),
              onTap: () {
                Navigator.pop(context);
                _copyLinkToClipboard(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyLinkToClipboard(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // Copy to clipboard using Clipboard
    Clipboard.setData(ClipboardData(text: _shareLink));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc?.tr('link_copied') ?? 'Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () => _showShareOptions(context),
      tooltip: loc?.tr('share_post_tooltip') ?? 'Share Post',
    );
  }
}
