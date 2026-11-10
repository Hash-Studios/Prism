import 'dart:async';
import 'dart:convert';
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
import 'package:Prism/features/wallpaper_upload/biz/live_upload_limits.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef LiveVideoDownloader = Future<File> Function(String url);

final Map<String, Future<File>> _downloads = <String, Future<File>>{};

/// Downloads a live wall's MP4 to the temp folder. A file kept from an earlier tap is reused.
Future<File> downloadLiveVideo(String url) => _downloads.putIfAbsent(
  url,
  () => _downloadLiveVideo(url).whenComplete(() {
    _downloads.remove(url);
  }),
);

Future<File> _downloadLiveVideo(String url) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/prism_live_${sha256.convert(utf8.encode(url))}.mp4');
  final FileStat cached = await file.stat();
  if (cached.type == FileSystemEntityType.file) {
    if (cached.size > 0 && cached.size <= LiveUploadLimits.maxBytes) return file;
    await file.delete();
  }
  final Uri uri = Uri.parse(url);
  final http.Client client = http.Client();
  final Stopwatch elapsed = Stopwatch()..start();
  const Duration timeout = Duration(seconds: 60);
  Directory? staging;
  RandomAccessFile? output;
  StreamIterator<List<int>>? chunks;
  try {
    final http.StreamedResponse response = await client.send(http.Request('GET', uri)).timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException('Live video download failed with ${response.statusCode}', uri: uri);
    }
    if (response.contentLength == 0 || (response.contentLength ?? 0) > LiveUploadLimits.maxBytes) {
      throw HttpException('Invalid live video size', uri: uri);
    }
    staging = await dir.createTemp('prism_live_');
    final File partial = File('${staging.path}/video.part');
    output = await partial.open(mode: FileMode.write);
    chunks = StreamIterator<List<int>>(response.stream);
    int length = 0;
    while (await chunks.moveNext().timeout(timeout - elapsed.elapsed)) {
      final List<int> chunk = chunks.current;
      length += chunk.length;
      if (length > LiveUploadLimits.maxBytes) throw HttpException('Live video is too large', uri: uri);
      await output.writeFrom(chunk);
    }
    if (length == 0 || (response.contentLength != null && length != response.contentLength)) {
      throw HttpException('Incomplete live video download', uri: uri);
    }
    await output.flush();
    await output.close();
    output = null;
    return await partial.rename(file.path);
  } finally {
    client.close();
    await chunks?.cancel();
    await output?.close();
    await staging?.delete(recursive: true);
  }
}

class LiveSetButton extends StatefulWidget {
  const LiveSetButton({
    required this.live,
    required this.wallId,
    this.download = downloadLiveVideo,
    this.apply,
    this.onSet,
    super.key,
  });

  final WallLive live;
  final String wallId;
  final LiveVideoDownloader download;

  final Future<LiveApplyOutcome> Function(String path)? apply;
  final Future<void> Function()? onSet;

  @override
  State<LiveSetButton> createState() => LiveSetButtonState();
}

class LiveSetButtonState extends State<LiveSetButton> {
  /// Starts the set flow, as a tap does. The detail header and the Preview pill call it.
  Future<void> run() => _run();

  bool _busy = false;
  int _request = 0;

  @override
  void didUpdateWidget(LiveSetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallId != widget.wallId || oldWidget.live.videoUrl != widget.live.videoUrl) {
      _request++;
      _busy = false;
    }
  }

  Future<void> _run() async {
    if (_busy) return;
    final int request = ++_request;
    final Future<LiveApplyOutcome> Function(String path)? apply = widget.apply;
    final Future<void> Function()? onSet = widget.onSet;
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    LiveApplyOutcome? outcome;
    try {
      final File file = await widget.download(widget.live.videoUrl);
      if (!mounted || request != _request) return;
      outcome = await (apply ?? getIt<LiveWallpaperRepository>().applyVideo)(file.path);
    } catch (_) {
      outcome = null;
    }
    if (outcome?.status == LiveApplyStatus.applied && onSet != null) {
      unawaited(
        Future<void>.sync(onSet).catchError((Object error, StackTrace stackTrace) {
          logger.w('Live wall set accounting failed', error: error, stackTrace: stackTrace);
        }),
      );
    }
    final String result = outcome == null ? 'failed' : _resultOf(outcome.status);
    unawaited(analytics.track(LiveWallSetEvent(platform: 'android', action: 'live', result: result)));
    if (!mounted || request != _request) return;
    setState(() => _busy = false);
    if (outcome == null) {
      _toast(l10n.liveWallSetFailed, PrismToastKind.error);
      return;
    }
    final bool perScreen = outcome.status == LiveApplyStatus.confirmInPreview && await _supportsPerScreen();
    if (!mounted || request != _request) return;
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
    // Disabled while busy, like Save video, so a tap or a screen reader does not report an action that does nothing.
    return PrismButton(
      label: _busy ? l10n.liveWallPreparing : l10n.liveWallSetLive,
      size: PrismButtonSize.compact,
      trailing: _busy
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      onPressed: _busy ? null : _run,
    );
  }
}

class LiveSaveVideoButton extends StatefulWidget {
  const LiveSaveVideoButton({required this.live, this.download = downloadLiveVideo, this.save, super.key});

  final WallLive live;
  final LiveVideoDownloader download;

  final Future<OperationResult> Function(String path)? save;

  @override
  State<LiveSaveVideoButton> createState() => _LiveSaveVideoButtonState();
}

class _LiveSaveVideoButtonState extends State<LiveSaveVideoButton> {
  bool _busy = false;
  int _request = 0;

  @override
  void didUpdateWidget(LiveSaveVideoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live.videoUrl != widget.live.videoUrl) {
      _request++;
      _busy = false;
    }
  }

  Future<void> _run() async {
    if (_busy) return;
    final int request = ++_request;
    final Future<OperationResult> Function(String path)? save = widget.save;
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    bool saved;
    try {
      final File file = await widget.download(widget.live.videoUrl);
      if (!mounted || request != _request) return;
      saved = (await (save ?? PrismMediaHostApi().saveVideo)(file.path)).success;
    } catch (_) {
      saved = false;
    }
    unawaited(analytics.track(LiveWallSetEvent(platform: 'ios', action: 'video', result: saved ? 'ok' : 'failed')));
    if (!mounted || request != _request) return;
    setState(() => _busy = false);
    if (saved) {
      toasts.success(l10n.liveWallSaveVideoDone);
    } else {
      toasts.error(l10n.liveWallSaveVideoFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A bare spinner would collapse the pill in the crowded action bar, so the busy state keeps a label.
    return PrismButton(
      label: _busy ? context.l10n.liveWallPreparing : context.l10n.liveWallSaveVideo,
      icon: Icons.video_file_outlined,
      variant: PrismButtonVariant.tonal,
      size: PrismButtonSize.compact,
      onPressed: _busy ? null : _run,
    );
  }
}

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
