import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class ShareButton extends StatefulWidget {
  final String? id;
  final WallpaperSource source;
  final String? url;
  final String thumbUrl;
  final String? contextLine;
  final Future<String?> Function(String id, WallpaperSource source, String? url, String thumbUrl)? createLink;
  final Future<ShareCardResult> Function(
    BuildContext context, {
    required String imageUrl,
    required String link,
    String? contextLine,
  })
  shareCard;

  /// Shows a caption under the round button.
  final bool labelled;
  const ShareButton({
    required this.id,
    required this.source,
    required this.url,
    required this.thumbUrl,
    this.contextLine,
    this.createLink,
    this.shareCard = shareWallpaperCard,
    this.labelled = false,
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
      label: context.l10n.coreShare,
      caption: widget.labelled ? context.l10n.coreShare : null,
      onTap: () {
        PrismHaptics.tap();
        logger.d('Share');
        onShare();
      },
      isLoading: isLoading,
      child: const Icon(JamIcons.share_alt),
    );
  }

  Future<void> onShare() async {
    if (isLoading) return;

    final String? id = widget.id;
    final WallpaperSource source = widget.source;
    final String? url = widget.url;
    final String thumbUrl = safeWallpaperShareThumbnail(id ?? '', source, widget.thumbUrl);
    // Link thumbnails have a stricter allowlist than the server-owned display derivative.
    // Never use widget.url here: acquiring an original requires a separate authorization.
    final String imageUrl =
        source == WallpaperSource.prism && widget.thumbUrl.trim().isNotEmpty && Firebase.apps.isNotEmpty
        ? Uri.https('us-central1-${Firebase.app().options.projectId}.cloudfunctions.net', '/wallpaperPreview', {
            'id': id ?? '',
            'thumb': widget.thumbUrl.trim(),
          }).toString()
        : thumbUrl.trim();
    final String? contextLine = widget.contextLine;
    final createLink = widget.createLink;
    final shareCard = widget.shareCard;

    analytics.track(const InviteShareTappedEvent(sourceContext: 'wallpaper_screen'));
    setState(() {
      isLoading = true;
    });

    try {
      final String itemId = id ?? '';
      final bool isBundledStarter = BundledWallpapers.isStarterIdentity(itemId, source);
      final AppLocalizations l10n = context.l10n;
      final String canonicalLink = isBundledStarter
          ? l10n.coreShareWallpaperGeneric
          : canonicalWallpaperLink(id: itemId, source: source, url: url, thumbUrl: thumbUrl);
      String link = canonicalLink;
      if (!isBundledStarter) {
        try {
          // Allow the short-link service its full six-second request budget.
          link =
              await (createLink?.call(itemId, source, url, thumbUrl) ??
                      createDynamicLink(itemId, source, url, thumbUrl, l10n: l10n))
                  .timeout(const Duration(seconds: 6)) ??
              canonicalLink;
        } on TimeoutException catch (error, stackTrace) {
          logger.w('Short link timed out; sharing canonical wallpaper URL.', error: error, stackTrace: stackTrace);
        } catch (error, stackTrace) {
          logger.w('Short link unavailable; sharing canonical wallpaper URL.', error: error, stackTrace: stackTrace);
        }
      }
      if (!mounted) return;
      String shareImageUrl = imageUrl;
      if (isBundledStarter) {
        try {
          final file = await BundledWallpapers.localFileForStarter(itemId, source);
          if (file == null) throw StateError('Bundled wallpaper file is unavailable.');
          shareImageUrl = file.path;
        } catch (error, stackTrace) {
          logger.w('Bundled wallpaper is unavailable for sharing.', error: error, stackTrace: stackTrace);
          if (mounted) {
            analytics.track(
              const InviteShareResultEvent(
                channel: ShareChannelValue.shareSheet,
                result: EventResultValue.failure,
                reason: AnalyticsReasonValue.error,
                sourceContext: 'wallpaper_screen',
              ),
            );
            toasts.error(l10n.coreWallpaperShareFailed);
          }
          return;
        }
      }
      if (!mounted) return;
      final ShareCardResult shared = await shareCard(
        context,
        imageUrl: shareImageUrl,
        link: link,
        contextLine: contextLine,
      );
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
      if (mounted) toasts.error(context.l10n.coreWallpaperShareRetryFailed);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
