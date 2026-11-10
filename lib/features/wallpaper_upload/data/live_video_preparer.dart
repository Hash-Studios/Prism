import 'dart:io';

import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/features/wallpaper_upload/biz/live_upload_input.dart';
import 'package:Prism/features/wallpaper_upload/biz/live_upload_limits.dart';
import 'package:Prism/l10n/l10n.dart';

sealed class LivePrepResult {
  const LivePrepResult();
}

final class LivePrepReady extends LivePrepResult {
  const LivePrepReady({required this.poster, required this.input});

  /// The still image of the wall: the first frame, uploaded as the normal wall image.
  final File poster;
  final LiveUploadInput input;
}

final class LivePrepRefused extends LivePrepResult {
  const LivePrepRefused(this.error);

  final LiveVideoError error;
}

/// Checks [video] and makes its poster and 3 moderation frames. Never reads a file over [LiveUploadLimits.maxBytes].
Future<LivePrepResult> prepareLiveVideo(File video, {PrismMediaHostApi? media}) async {
  if (await video.length() > LiveUploadLimits.maxBytes) return const LivePrepRefused(LiveVideoError.tooLarge);
  final LiveVideoCheck check = inspectLiveVideo(await video.readAsBytes());
  return switch (check) {
    LiveVideoRefused(:final error) => LivePrepRefused(error),
    LiveVideoOk(:final info) => await _extractFrames(video, info, media ?? PrismMediaHostApi()),
  };
}

Future<LivePrepResult> _extractFrames(File video, LiveVideoInfo info, PrismMediaHostApi host) async {
  try {
    final String poster = (await host.extractVideoFrames(video.path, const <int>[0], 3200, 92)).single;
    final List<String> frames = await host.extractVideoFrames(video.path, liveFrameTimesMs(info.durationMs), 1024, 80);
    if (frames.length != 3) return const LivePrepRefused(LiveVideoError.malformed);
    return LivePrepReady(
      poster: File(poster),
      input: LiveUploadInput(video: video, info: info, framePaths: frames),
    );
  } catch (_) {
    return const LivePrepRefused(LiveVideoError.malformed);
  }
}

/// The message for a refused [error], in the app language.
String liveVideoErrorMessage(AppLocalizations l10n, LiveVideoError error) => switch (error) {
  LiveVideoError.notMp4 => l10n.liveUploadErrorFormat,
  LiveVideoError.codec => l10n.liveUploadErrorCodec,
  LiveVideoError.tooLong => l10n.liveUploadErrorTooLong,
  LiveVideoError.tooLarge => l10n.liveUploadErrorTooLarge,
  LiveVideoError.landscape => l10n.liveUploadErrorLandscape,
  LiveVideoError.tooBigFrame => l10n.liveUploadErrorFrameSize,
  LiveVideoError.malformed || LiveVideoError.noVideoTrack => l10n.liveUploadErrorUnreadable,
};
