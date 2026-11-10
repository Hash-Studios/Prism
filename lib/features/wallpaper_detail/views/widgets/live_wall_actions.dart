import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart' show liveOutcomeMessage;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef LiveVideoDownloader = Future<File> Function(String url);

/// Downloads a live wall's MP4 to the temp folder. A file kept from an earlier tap is reused.
Future<File> downloadLiveVideo(String url) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/prism_live_${url.hashCode.toUnsigned(32)}.mp4');
  if (await file.exists() && await file.length() > 0) return file;
  final http.Response response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
  if (response.statusCode != 200) {
    throw HttpException('Live video download failed with ${response.statusCode}', uri: Uri.parse(url));
  }
  await file.writeAsBytes(response.bodyBytes, flush: true);
  return file;
}

/// Android: downloads the video and sets it as the live wallpaper.
class LiveSetButton extends StatefulWidget {
  const LiveSetButton({
    required this.live,
    required this.wallId,
    this.download = downloadLiveVideo,
    this.apply,
    super.key,
  });

  final WallLive live;
  final String wallId;
  final LiveVideoDownloader download;

  /// Applies the downloaded file. Null uses the live wallpaper repository.
  final Future<LiveApplyOutcome> Function(String path)? apply;

  @override
  State<LiveSetButton> createState() => _LiveSetButtonState();
}

class _LiveSetButtonState extends State<LiveSetButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    LiveApplyOutcome? outcome;
    try {
      final File file = await widget.download(widget.live.videoUrl);
      outcome = await (widget.apply ?? getIt<LiveWallpaperRepository>().applyVideo)(file.path);
    } catch (_) {
      outcome = null;
    }
    final String result = outcome == null ? 'failed' : _resultOf(outcome.status);
    unawaited(analytics.track(LiveWallSetEvent(platform: 'android', action: 'live', result: result)));
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == null) {
      _toast(l10n.liveWallSetFailed, PrismToastKind.error);
      return;
    }
    final bool perScreen = outcome.status == LiveApplyStatus.confirmInPreview && await _supportsPerScreen();
    if (!mounted) return;
    final String message = liveOutcomeMessage(l10n, outcome, perScreen);
    if (message.isEmpty) return;
    _toast(
      message,
      outcome.isError
          ? PrismToastKind.error
          : outcome.status == LiveApplyStatus.applied
          ? PrismToastKind.success
          : PrismToastKind.plain,
    );
  }

  void _toast(String message, PrismToastKind kind) => showPrismToast(Overlay.of(context), message, kind: kind);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismButton(
      label: _busy ? l10n.liveWallPreparing : l10n.liveWallSetLive,
      size: PrismButtonSize.compact,
      trailing: _busy
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
            )
          : null,
      onPressed: _run,
    );
  }
}

/// iOS: downloads the video and saves it to Photos.
class LiveSaveVideoButton extends StatefulWidget {
  const LiveSaveVideoButton({required this.live, this.download = downloadLiveVideo, this.save, super.key});

  final WallLive live;
  final LiveVideoDownloader download;

  /// Saves the downloaded file. Null uses the media host API.
  final Future<OperationResult> Function(String path)? save;

  @override
  State<LiveSaveVideoButton> createState() => _LiveSaveVideoButtonState();
}

class _LiveSaveVideoButtonState extends State<LiveSaveVideoButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    bool saved;
    try {
      final File file = await widget.download(widget.live.videoUrl);
      saved = (await (widget.save ?? PrismMediaHostApi().saveVideo)(file.path)).success;
    } catch (_) {
      saved = false;
    }
    unawaited(analytics.track(LiveWallSetEvent(platform: 'ios', action: 'video', result: saved ? 'ok' : 'failed')));
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) {
      toasts.success(l10n.liveWallSaveVideoDone);
    } else {
      toasts.error(l10n.liveWallSaveVideoFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismButton(
      label: context.l10n.liveWallSaveVideo,
      icon: Icons.video_file_outlined,
      variant: PrismButtonVariant.tonal,
      size: PrismButtonSize.compact,
      loading: _busy,
      onPressed: _run,
    );
  }
}

/// The iOS note under a live wall: live walls cannot be set on iOS, so the poster is set instead.
class LiveIosNote extends StatelessWidget {
  const LiveIosNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: PrismSpace.xs),
        Expanded(child: Text(context.l10n.liveWallIosBody, style: PrismTextStyles.body(context))),
      ],
    );
  }
}

Future<bool> _supportsPerScreen() async {
  try {
    final LiveCapabilities capabilities = await getIt<LiveWallpaperRepository>().getCapabilities();
    return capabilities.supportsPerScreen;
  } catch (_) {
    return false;
  }
}

String _resultOf(LiveApplyStatus status) => switch (status) {
  LiveApplyStatus.applied || LiveApplyStatus.confirmInPreview => 'ok',
  LiveApplyStatus.cancelled => 'cancelled',
  _ => 'failed',
};
