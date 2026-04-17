import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';

class ShareLinkWidget extends StatefulWidget {
  final int mediaId;
  final String mediaUrl;
  final String mediaTitle;

  const ShareLinkWidget({
    required this.mediaId,
    required this.mediaUrl,
    required this.mediaTitle,
    super.key,
  });

  @override
  State<ShareLinkWidget> createState() => _ShareLinkWidgetState();
}

class _ShareLinkWidgetState extends State<ShareLinkWidget> {
  late String _shareableLink;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _shareableLink = 'https://squad-player.app/media/${widget.mediaId}';
  }

  String _buildMessage(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return '${loc?.tr('check_out_media') ?? 'Check out this media'}: '
        '${widget.mediaTitle}\n$_shareableLink';
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _shareableLink));
    if (!mounted) return;

    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.tr('link_copied')),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final message = _buildMessage(context);
    final encoded = Uri.encodeComponent(message);

    final uri1 = Uri.parse('whatsapp://send?text=$encoded');
    final uri2 = Uri.parse('https://wa.me/?text=$encoded');

    try {
      // Try open WhatsApp directly (don’t rely on canLaunchUrl)
      final launched = await launchUrl(uri1, mode: LaunchMode.externalApplication);
      if (launched) return;

      // Fallback
      final launched2 = await launchUrl(uri2, mode: LaunchMode.externalApplication);
      if (launched2) return;

      // Final fallback: system share sheet
      await Share.share(
        message,
        subject: widget.mediaTitle,
      );
    } catch (e) {
      debugPrint('WhatsApp launch failed: $e');

      await Share.share(
        message,
        subject: widget.mediaTitle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc?.tr('share_this_media') ?? 'Share This Media',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Link row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _shareableLink,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _copied ? Icons.check : Icons.copy,
                      color: _copied ? Colors.green : AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Buttons row: Copy + WhatsApp
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: Text(
                    _copied
                        ? (loc?.tr('copied') ?? 'Copied!')
                        : (loc?.tr('copy_link') ?? 'Copy Link'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareViaWhatsApp(context),
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(loc?.tr('share_whatsapp') ?? 'WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}