import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';

/// The math the position preview and the final render share, so what you see is what gets set.
///
/// The wall is first laid out as "content". For [PlacementFit.fill] the content is the wall scaled to cover the frame.
/// For the fit modes the content is the frame itself, with the wall in the middle. The content is then scaled by the
/// zoom and moved inside the frame.
// ignore: avoid_classes_with_only_static_members
abstract final class PlacementGeometry {
  /// Blur sigma of the [PlacementFit.fitBlur] background, as a fraction of the frame's short side.
  static const double blurFraction = 0.03;

  /// Size of the content before zoom.
  static Size contentSize(Size image, Size frame, PlacementFit fit) {
    if (fit != PlacementFit.fill) return frame;
    final double scale = coverScale(image, frame);
    return Size(image.width * scale, image.height * scale);
  }

  /// Scale that makes [image] cover [frame].
  static double coverScale(Size image, Size frame) => math.max(frame.width / image.width, frame.height / image.height);

  /// Rect of the whole wall inside the frame for the fit modes.
  static Rect containRect(Size image, Size frame) {
    final double scale = math.min(frame.width / image.width, frame.height / image.height);
    final Size size = Size(image.width * scale, image.height * scale);
    return Rect.fromLTWH((frame.width - size.width) / 2, (frame.height - size.height) / 2, size.width, size.height);
  }

  /// Where the top left corner of the zoomed content sits in the frame. Never positive, so the content covers the frame.
  static Offset translation(Size content, Size frame, WallpaperPlacement placement) {
    final double rangeX = math.max(0, content.width * placement.zoom - frame.width);
    final double rangeY = math.max(0, content.height * placement.zoom - frame.height);
    return Offset(-rangeX * (1 + placement.dx) / 2, -rangeY * (1 + placement.dy) / 2);
  }

  /// The [WallpaperPlacement.dx] and [WallpaperPlacement.dy] that put the content at [translation].
  static ({double dx, double dy}) focus(Offset translation, Size content, Size frame, double zoom) {
    final double rangeX = content.width * zoom - frame.width;
    final double rangeY = content.height * zoom - frame.height;
    double axis(double offset, double range) => range <= 0.5 ? 0 : (-2 * offset / range - 1).clamp(-1.0, 1.0);
    return (dx: axis(translation.dx, rangeX), dy: axis(translation.dy, rangeY));
  }
}
