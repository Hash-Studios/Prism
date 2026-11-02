import 'dart:ui' show Size;

import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';

/// The live styles that read well as a short Live Photo. Ripple needs a touch, and the gradients do not use the wall.
const List<MotionStyle> livePhotoStyles = <MotionStyle>[
  MotionStyle.drift,
  MotionStyle.breathe,
  MotionStyle.shimmer,
  MotionStyle.depth,
];

/// The Live Photo styles for one wall. 3D needs the wall's depth map.
List<MotionStyle> livePhotoStylesFor({required bool hasDepthMap}) => <MotionStyle>[
  for (final MotionStyle style in livePhotoStyles)
    if (!style.needsDepthMap || hasDepthMap) style,
];

enum LiveExportFailure {
  sourceUnavailable,
  invalidRequest,
  renderFailed,
  encodeFailed,
  saveFailed,
  notLive,
  unavailable,
}

/// How one export ended.
sealed class LiveExportOutcome {
  const LiveExportOutcome();
}

final class LiveExportSaved extends LiveExportOutcome {
  const LiveExportSaved({required this.assetId, required this.verified});

  final String assetId;

  /// True when Photos read the asset back as a Live Photo. Null with add-only access, which cannot read it back.
  final bool? verified;
}

final class LiveExportCancelled extends LiveExportOutcome {
  const LiveExportCancelled();
}

/// The user refused Photos access, or a device policy blocks it ([restricted]).
final class LiveExportRefused extends LiveExportOutcome {
  const LiveExportRefused({required this.restricted});

  final bool restricted;
}

final class LiveExportTimedOut extends LiveExportOutcome {
  const LiveExportTimedOut();
}

final class LiveExportFailed extends LiveExportOutcome {
  const LiveExportFailed(this.reason);

  final LiveExportFailure reason;
}

/// One Live Photo export: the wall, how it moves, how long the clip is and its size in pixels.
class LiveExport {
  const LiveExport({required this.wallId, required this.style, required this.sizePx, this.duration = maxDuration});

  /// Camera Live Photos are about 3 seconds long, with the key photo in the middle.
  static const Duration maxDuration = Duration(seconds: 3);

  /// Camera Live Photos use up to 30 frames per second.
  static const int framesPerSecond = 30;

  /// The render and the encode stop after this. Saving to Photos is not inside it.
  static const Duration timeLimit = Duration(seconds: 45);

  final String wallId;
  final MotionStyle style;
  final Size sizePx;
  final Duration duration;
}
