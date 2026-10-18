import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:lottie/lottie.dart';

/// Where a marker sits in the Lottie file, as the file's own progress (0 to 1), and how long it plays.
class ChestSpan {
  const ChestSpan(this.from, this.to, this.duration);

  /// The span of [marker] as [composition] draws it. Before the file has loaded, or when a replacement file lacks the
  /// marker, the contract's frame numbers stand in, so the page never waits on the art.
  factory ChestSpan.of(ChestMarker marker, LottieComposition? composition) {
    final Marker? found = composition?.getMarker(marker.name);
    if (composition != null && found != null) {
      return ChestSpan(found.start, found.end, composition.duration * (found.end - found.start));
    }
    return ChestSpan(
      marker.startFrame / chestTotalFrames,
      marker.endFrame / chestTotalFrames,
      Duration(microseconds: (marker.frames * Duration.microsecondsPerSecond / chestFrameRate).round()),
    );
  }

  final double from;
  final double to;
  final Duration duration;

  /// The progress of [frame], a frame of [marker], inside this span.
  double at(ChestMarker marker, int frame) => from + (to - from) * (frame - marker.startFrame) / marker.frames;
}
