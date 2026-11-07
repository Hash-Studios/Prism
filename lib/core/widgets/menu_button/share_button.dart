import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/share/open_on_computer.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/core/share/share_text.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
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

  /// The creator's display name or handle, shown on the share cards.
  final String? creator;

  /// Stored wall colours for the palette dots, most dominant first.
  final List<Color> palette;
  final Future<String?> Function(String id, WallpaperSource source, String? url, String thumbUrl)? createLink;
  final PendingShareSheetOpen openSheet;

  /// Tells whether the public web catalogue shows the wall. Tests replace it.
  final Future<bool> Function(String id) webCatalogueCheck;

  /// Shows a caption under the round button.
  final bool labelled;
  final bool duoReveal;
  const ShareButton({
    required this.id,
    required this.source,
    required this.url,
    required this.thumbUrl,
    this.contextLine,
    this.creator,
    this.palette = const <Color>[],
    this.createLink,
    this.openSheet = showPendingShareSheet,
    this.webCatalogueCheck = isOnWebCatalogue,
    this.labelled = false,
    this.duoReveal = false,
    super.key,
  });

  @override
  _ShareButtonState createState() => _ShareButtonState();
}

/// False when the check fails or takes too long: the sheet then hides Open on computer.
Future<bool> _isOnWebCatalogue(Future<bool> Function(String id) check, String id) async {
  try {
    return await check(id).timeout(const Duration(seconds: 6));
  } catch (error, stackTrace) {
    logger.w('Web catalogue check failed; hiding Open on computer', error: error, stackTrace: stackTrace);
    return false;
  }
}

class _ShareButtonState extends State<ShareButton> {
  // True from the tap until the sheet is closed and its content has settled, so a second tap starts nothing.
  bool _sharing = false;

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
      isLoading: false,
      child: const Icon(JamIcons.share_alt),
    );
  }

  /// Opens the sheet on the first frame. The short link, the web catalogue check and a bundled wall's file load
  /// inside the open sheet, so the tap never waits on the network.
  Future<void> onShare() async {
    if (_sharing) return;
    if (!await requireSignedInAction(context) || !mounted || _sharing) return;

    final String? id = widget.id;
    final WallpaperSource source = widget.source;
    final String? url = widget.url;
    final Future<bool> Function(String id) webCatalogueCheck = widget.webCatalogueCheck;
    final String originalUrl = url?.trim() ?? '';
    final String rawThumbUrl = widget.thumbUrl.trim();
    final String itemId = id ?? '';
    final bool isBundledStarter = BundledWallpapers.isStarterIdentity(itemId, source);
    final Future<bool> onWebCatalogue = source == WallpaperSource.prism && !isBundledStarter && itemId.isNotEmpty
        ? _isOnWebCatalogue(webCatalogueCheck, itemId)
        : Future<bool>.value(false);
    final bool originalThumbnailFallback =
        !isBundledStarter &&
        originalUrl.isNotEmpty &&
        rawThumbUrl == originalUrl &&
        (source == WallpaperSource.prism || source == WallpaperSource.wallhaven || source == WallpaperSource.pexels);
    final String thumbUrl = safeWallpaperShareThumbnail(
      id ?? '',
      source,
      originalThumbnailFallback ? '' : widget.thumbUrl,
    );
    // Link thumbnails have a stricter allowlist than the server-owned display derivative.
    // Never use widget.url here: acquiring an original requires a separate authorization.
    final String previewUrl = source == WallpaperSource.prism && !originalThumbnailFallback && Firebase.apps.isNotEmpty
        ? prismWallpaperPreviewUrl(id: itemId, thumbnail: rawThumbUrl, projectId: Firebase.app().options.projectId)
        : '';
    final String imageUrl = previewUrl.isNotEmpty ? previewUrl : thumbUrl.trim();
    final String? contextLine = widget.contextLine;
    final String? creator = shareCreatorMark(widget.creator);
    final List<Color> palette = widget.palette;
    final bool duoReveal = widget.duoReveal;
    final createLink = widget.createLink;
    final PendingShareSheetOpen openSheet = widget.openSheet;
    final AppLocalizations l10n = context.l10n;
    final String canonicalLink = isBundledStarter
        ? l10n.coreShareWallpaperGeneric
        : canonicalWallpaperLink(id: itemId, source: source, url: url, thumbUrl: thumbUrl);

    ShareCardContent content({required String link, required String imageUrl, Uri? computerLink}) => ShareCardContent(
      imageUrl: imageUrl,
      link: link,
      brandName: l10n.appTitle,
      contextLine: contextLine,
      creator: creator,
      creatorLine: creator == null ? null : l10n.coreShareCardBy(creator),
      palette: palette,
      duoReveal: duoReveal,
      contentId: itemId,
      foldedLabel: l10n.duoFolded,
      unfoldedLabel: l10n.duoUnfolded,
      cta: l10n.duoGetOnPrism,
      computerLink: computerLink,
    );

    void trackFailure() => analytics.track(
      const InviteShareResultEvent(
        channel: ShareChannelValue.shareSheet,
        result: EventResultValue.failure,
        reason: AnalyticsReasonValue.error,
        sourceContext: 'wallpaper_screen',
      ),
    );

    /// The final content, or null (with a toast) when the wall cannot be shared. Never throws.
    Future<ShareCardContent?> resolve() async {
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
      String shareImageUrl = imageUrl;
      if (isBundledStarter) {
        try {
          final file = await BundledWallpapers.localFileForStarter(itemId, source);
          if (file == null) throw StateError('Bundled wallpaper file is unavailable.');
          shareImageUrl = file.path;
        } catch (error, stackTrace) {
          logger.w('Bundled wallpaper is unavailable for sharing.', error: error, stackTrace: stackTrace);
          trackFailure();
          toasts.error(l10n.coreWallpaperShareFailed);
          return null;
        }
      }
      final Uri? computerLink = await onWebCatalogue ? openOnComputerLink(wallId: itemId, shareLink: link) : null;
      return content(link: link, imageUrl: shareImageUrl, computerLink: computerLink);
    }

    analytics.track(const InviteShareTappedEvent(sourceContext: 'wallpaper_screen'));
    _sharing = true;
    final Future<ShareCardContent?> ready = resolve();
    try {
      await openSheet(context, content(link: canonicalLink, imageUrl: imageUrl), ready, 'wallpaper_screen');
      await ready;
    } catch (error, stackTrace) {
      logger.e('Failed to share wallpaper link', error: error, stackTrace: stackTrace);
      trackFailure();
      if (mounted) toasts.error(l10n.coreWallpaperShareRetryFailed);
    } finally {
      _sharing = false;
    }
  }
}
