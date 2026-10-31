import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReviewDownloadButton extends StatelessWidget {
  const ReviewDownloadButton({
    super.key,
    required this.link,
    required this.kind,
    required this.event,
    required this.successMessage,
    required this.failLogSuffix,
    this.showNotification = false,
  });

  final String link;
  final SaveMediaKind kind;
  final AnalyticsEvent event;
  final String successMessage;
  final String failLogSuffix;
  final bool showNotification;

  static final PrismMediaHostApi _prismMediaApi = PrismMediaHostApi();

  Future<void> _download(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    toasts.success(l10n.wallpaperUploadDownloadStarting, haptic: false);
    if (showNotification) main.localNotification.createDownloadNotification(l10n);
    try {
      final result = await _prismMediaApi.saveMedia(SaveMediaRequest(link: link, isLocalFile: false, kind: kind));
      if (result.success) {
        analytics.track(event);
        toasts.success(successMessage);
      } else {
        toasts.error(l10n.wallpaperUploadDownloadError);
      }
    } on PlatformException catch (e) {
      if (e.code != 'channel-error') {
        logger.e('saveMedia failed for $failLogSuffix', error: e);
      }
      toasts.error(l10n.wallpaperUploadDownloadError);
    } catch (e) {
      logger.e('Unexpected saveMedia failure for $failLogSuffix', error: e);
      toasts.error(l10n.wallpaperUploadDownloadError);
    } finally {
      if (showNotification) main.localNotification.cancelDownloadNotification(l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismIconButton(
      icon: Icons.download_rounded,
      tooltip: context.l10n.wallpaperDownloadWallpaper,
      onPressed: () => _download(context),
    );
  }
}
