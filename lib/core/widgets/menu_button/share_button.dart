import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareButton extends StatefulWidget {
  final String? id;
  final WallpaperSource source;
  final String? url;
  final String thumbUrl;
  final String? contextLine;
  final Future<String> Function(String id, WallpaperSource source, String? url, String thumbUrl) createLink;
  final Future<ShareCardResult> Function(
    BuildContext context, {
    required String imageUrl,
    required String link,
    String? contextLine,
  })
  shareCard;
  const ShareButton({
    required this.id,
    required this.source,
    required this.url,
    required this.thumbUrl,
    this.contextLine,
    this.createLink = createDynamicLink,
    this.shareCard = shareWallpaperCard,
    super.key,
  });

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
    return CircularMenuButton(
      label: 'Share',
      onTap: () {
        logger.d('Share');
        onShare();
      },
      isLoading: isLoading,
      child: Icon(JamIcons.share_alt, color: Theme.of(context).colorScheme.secondary, size: 20),
    );
  }

  Future<void> onShare() async {
    if (isLoading) return;

    final String? id = widget.id;
    final WallpaperSource source = widget.source;
    final String? url = widget.url;
    final String thumbUrl = widget.thumbUrl;
    final String imageUrl = url?.trim().isNotEmpty == true ? url!.trim() : thumbUrl.trim();
    final String? contextLine = widget.contextLine;
    final createLink = widget.createLink;
    final shareCard = widget.shareCard;

    analytics.track(const InviteShareTappedEvent(sourceContext: 'wallpaper_screen'));
    setState(() {
      isLoading = true;
    });

    try {
      final String link = await createLink(id!, source, url, thumbUrl);
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      final ShareCardResult shared = await shareCard(context, imageUrl: imageUrl, link: link, contextLine: contextLine);
      if (!mounted) return;
      analytics.track(
        InviteShareResultEvent(
          channel: ShareChannelValue.shareSheet,
          result: shared.dismissed ? EventResultValue.cancelled : EventResultValue.success,
          reason: shared.dismissed ? AnalyticsReasonValue.userCancelled : null,
          sourceContext: 'wallpaper_screen',
          format: shared.format,
        ),
      );
    } catch (error, stackTrace) {
      logger.e('Failed to share wallpaper link', error: error, stackTrace: stackTrace);
      analytics.track(
        const InviteShareResultEvent(
          channel: ShareChannelValue.shareSheet,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'wallpaper_screen',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
