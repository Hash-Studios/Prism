import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks the user to confirm deleting an upload, then runs [onConfirm].
void showDeleteConfirm(BuildContext context, {required String title, required Future<void> Function() onConfirm}) {
  unawaited(
    showPrismConfirm(
      context,
      title: title,
      message: "This is permanent. You can't undo it.",
      confirmLabel: 'Delete wallpaper',
      destructive: true,
    ).then((bool confirmed) async {
      if (confirmed) await onConfirm();
    }),
  );
}

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

  Future<void> _download() async {
    toasts.success('Starting download');
    if (showNotification) main.localNotification.createDownloadNotification();
    try {
      final result = await _prismMediaApi.saveMedia(SaveMediaRequest(link: link, isLocalFile: false, kind: kind));
      if (result.success) {
        analytics.track(event);
        toasts.success(successMessage);
      } else {
        toasts.error("Couldn't download. Try again.");
      }
    } on PlatformException catch (e) {
      if (e.code != 'channel-error') {
        logger.e('saveMedia failed for $failLogSuffix', error: e);
      }
      toasts.error("Couldn't download. Try again.");
    } catch (e) {
      logger.e('Unexpected saveMedia failure for $failLogSuffix', error: e);
      toasts.error("Couldn't download. Try again.");
    } finally {
      if (showNotification) main.localNotification.cancelDownloadNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismIconButton(icon: Icons.download_rounded, tooltip: 'Download wallpaper', onPressed: _download);
  }
}
