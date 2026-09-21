import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/share_service.dart';
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
  const ShareButton({required this.id, required this.source, required this.url, required this.thumbUrl, super.key});

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
    analytics.track(const InviteShareTappedEvent(sourceContext: 'wallpaper_screen'));
    setState(() {
      isLoading = true;
    });

    try {
      final String link = await createDynamicLink(widget.id!, widget.source, widget.url, widget.thumbUrl);
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      await ShareService.shareText(text: '🔥Check this out ➜ $link', context: context);
      analytics.track(
        const InviteShareResultEvent(
          channel: ShareChannelValue.shareSheet,
          result: EventResultValue.success,
          sourceContext: 'wallpaper_screen',
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
