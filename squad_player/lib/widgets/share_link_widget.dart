import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _generateShareableLink();
  }

  void _generateShareableLink() {
    _shareableLink =
    'https://squad-online.com/landing/open-app.html?type=post&id=${widget.mediaId}';
  }

  Future<void> _shareToWhatsApp() async {
    final loc = AppLocalizations.of(context);

    final message =
        '${loc?.tr('check_out_media') ?? 'Check out this media'}: ${widget.mediaTitle}\n$_shareableLink';

    final encoded = Uri.encodeComponent(message);

    final uri1 = Uri.parse('whatsapp://send?text=$encoded');
    final uri2 = Uri.parse('https://wa.me/?text=$encoded');

    try {
      final launched = await launchUrl(uri1,
          mode: LaunchMode.externalApplication);

      if (!launched) {
        await launchUrl(uri2,
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await Share.share(message);
    }
  }


  Future<void> _copyToClipboard( ) async {
    await Clipboard.setData(ClipboardData(text: _shareableLink));
    setState(() => _copied = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.tr('link_copied')),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareLink() async {
    final loc = AppLocalizations.of(context);
    await Share.share(
      '${loc?.tr('check_out_media') ?? 'Check out this media'}: ${widget.mediaTitle}\n$_shareableLink',
      subject: widget.mediaTitle,
    );
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _shareableLink,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyToClipboard,
                  child: Icon(
                    _copied ? Icons.check : Icons.copy,
                    color: _copied ? Colors.green : AppColors.primary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: Text(_copied ? (loc?.tr('copied') ?? 'Copied!') : (loc?.tr('copy_link') ?? 'Copy Link')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.share),
                  label: Text(loc?.tr('share') ?? 'Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkAccent,
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
