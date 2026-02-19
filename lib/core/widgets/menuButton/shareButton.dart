import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareButton extends StatefulWidget {
  final String? id;
  final String? provider;
  final String? url;
  final String thumbUrl;
  const ShareButton({required this.id, required this.provider, required this.url, required this.thumbUrl, super.key});

  @override
  _ShareButtonState createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  late bool isLoading;
  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        logger.d('Share');
        onShare();
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(JamIcons.share_alt, color: Theme.of(context).colorScheme.secondary, size: 20),
          ),
          Positioned(
            top: 0,
            left: 0,
            height: 53,
            width: 53,
            child: isLoading ? const CircularProgressIndicator() : Container(),
          ),
        ],
      ),
    );
  }

  Future<void> onShare() async {
    setState(() {
      isLoading = true;
    });

    try {
      final String link = await createDynamicLink(widget.id!, widget.provider!, widget.url, widget.thumbUrl);
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      await ShareService.shareText(text: '🔥Check this out ➜ $link', context: context);
      analytics.logShare(contentType: 'wallpaperScreen', itemId: widget.id!, method: 'link');
    } catch (error, stackTrace) {
      logger.e('Failed to share wallpaper link', error: error, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
