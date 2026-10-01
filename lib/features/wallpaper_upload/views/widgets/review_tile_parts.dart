import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showDeleteConfirm(BuildContext context, {required String title, required Future<void> Function() onConfirm}) {
  final ThemeData theme = Theme.of(context);
  final AlertDialog dialog = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    title: Text(
      title,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme.colorScheme.secondary),
    ),
    content: Text(
      "This is permanent, and this action can't be undone!",
      style: TextStyle(
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.normal,
        fontSize: 14,
        color: theme.colorScheme.secondary,
      ),
    ),
    actions: [
      MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: theme.hintColor,
        onPressed: () async {
          PrismHaptics.tap();
          Navigator.pop(context);
          await onConfirm();
        },
        child: const Text('DELETE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
      ),
      MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: theme.colorScheme.error,
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('CANCEL', style: TextStyle(fontSize: 16.0, color: Colors.white)),
      ),
    ],
    backgroundColor: theme.primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(context: context, builder: (BuildContext context) => dialog);
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
    toasts.success("Starting Download");
    if (showNotification) main.localNotification.createDownloadNotification();
    try {
      final result = await _prismMediaApi.saveMedia(SaveMediaRequest(link: link, isLocalFile: false, kind: kind));
      if (result.success) {
        analytics.track(event);
        toasts.success(successMessage);
      } else {
        toasts.success("Couldn't download! Please Retry!");
      }
    } on PlatformException catch (e) {
      if (e.code != 'channel-error') {
        logger.e('saveMedia failed for $failLogSuffix', error: e);
      }
      toasts.success("Couldn't download! Please Retry!");
    } catch (e) {
      logger.e('Unexpected saveMedia failure for $failLogSuffix', error: e);
      toasts.success("Couldn't download! Please Retry!");
    } finally {
      if (showNotification) main.localNotification.cancelDownloadNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
      child: IconButton(
        tooltip: 'Download wallpaper',
        icon: Icon(JamIcons.download, color: Theme.of(context).primaryColor),
        onPressed: _download,
      ),
    );
  }
}

class ReviewInfoRow extends StatelessWidget {
  const ReviewInfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.secondary),
    );
    final Widget row = Row(
      children: [
        Icon(icon, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
    return row;
  }
}
