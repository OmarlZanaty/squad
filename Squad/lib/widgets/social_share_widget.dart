import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:squad/utils/app_localizations.dart';
import '../utils/share_links.dart'; // ✅ add this import
import 'package:squad/services/api_service.dart';
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

  String get _shareLink => ShareLinks.storeLink; // ✅ store link only


  String _buildMessage(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return '${loc?.tr('check_out_post_from') ?? 'Check out this post from'} '
        '$userName ${loc?.tr('on_squad') ?? 'on Squad'}:\n\n'
        '$postContent\n\n'
        '${ShareLinks.postText(postId)}\n'
        '${loc?.tr('download_app') ?? 'Download the app:'}\n$_shareLink';
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final message = _buildMessage(context);
    final encoded = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');

    try {

      print("SHARE DEBUG 1 - before API");

      // ✅ record share FIRST
      await ApiService.recordPostShare(
        postId: postId,
        platform: 'whatsapp',
      );

      print("SHARE DEBUG 2 - API recorded");

      final ok = await canLaunchUrl(whatsappUri);

      if (ok) {
        await launchUrl(
          whatsappUri,
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      // fallback if WhatsApp not installed
      await Share.share(message);

    } catch (e) {
      print("SHARE ERROR: $e");
    }
  }

  Future<void> _shareGeneral(BuildContext context) async {
    final loc = AppLocalizations.of(context);

    try {

      // ✅ record share first
      await ApiService.recordPostShare(
        postId: postId,
        platform: 'system',
      );

      await Share.share(
        _buildMessage(context),
        subject: loc?.tr('squad_post') ?? 'Squad Player Post',
      );

    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  Future<void> _copyLinkToClipboard(BuildContext context) async {
    final loc = AppLocalizations.of(context);

    await Clipboard.setData(ClipboardData(text: _shareLink));

    await ApiService.recordPostShare(
      postId: postId,
      platform: 'copy_link',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc?.tr('link_copied') ?? 'Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            // ✅ WhatsApp (direct)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
              title: Text(loc?.tr('share_whatsapp') ?? 'Share via WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _shareViaWhatsApp(context);
              },
            ),

            // ✅ More options (system share sheet)
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: Text(loc?.tr('share_more') ?? 'More Options'),
              onTap: () {
                Navigator.pop(ctx);
                _shareGeneral(context);
              },
            ),

            const Divider(),

            // ✅ Copy link
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(loc?.tr('copy_link') ?? 'Copy Link'),
              onTap: () async {
                Navigator.pop(ctx);
                await _copyLinkToClipboard(context);
                },
            ),
          ],
        ),
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