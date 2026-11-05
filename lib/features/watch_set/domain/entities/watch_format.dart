import 'dart:math' as math;
import 'dart:ui' show Offset, RRect, Radius, Rect, Size;

enum WatchPlatform { appleWatch, wearOs }

enum WatchShape { roundedRect, round }

/// One watch screen: the watch image is saved at exactly [width] x [height] pixels. Sources are in
/// `docs/features/watch-sets.md`.
enum WatchFormat {
  apple40('apple_40', WatchPlatform.appleWatch, 324, 394, WatchShape.roundedRect),
  apple44('apple_44', WatchPlatform.appleWatch, 368, 448, WatchShape.roundedRect),
  apple41('apple_41', WatchPlatform.appleWatch, 352, 430, WatchShape.roundedRect),
  apple45('apple_45', WatchPlatform.appleWatch, 396, 484, WatchShape.roundedRect),
  apple42('apple_42', WatchPlatform.appleWatch, 374, 446, WatchShape.roundedRect),
  apple46('apple_46', WatchPlatform.appleWatch, 416, 496, WatchShape.roundedRect),
  appleUltra('apple_ultra', WatchPlatform.appleWatch, 410, 502, WatchShape.roundedRect),
  appleUltra3('apple_ultra_3', WatchPlatform.appleWatch, 422, 514, WatchShape.roundedRect),
  pixelWatch('pixel_watch', WatchPlatform.wearOs, 456, 456, WatchShape.round),
  galaxySmall('galaxy_small', WatchPlatform.wearOs, 438, 438, WatchShape.round),
  galaxyLarge('galaxy_large', WatchPlatform.wearOs, 480, 480, WatchShape.round);

  const WatchFormat(this.id, this.platform, this.width, this.height, this.shape);

  /// Stored as the remembered watch type and sent in analytics.
  final String id;
  final WatchPlatform platform;
  final int width;
  final int height;
  final WatchShape shape;

  double get aspect => width / height;

  static WatchFormat? fromId(String? id) {
    for (final WatchFormat format in values) {
      if (format.id == id) return format;
    }
    return null;
  }
}

/// The screen outline of a watch inside a frame of any size. The preview dims what is outside it. The saved image is
/// the whole frame: the watch masks it.
class WatchMask {
  const WatchMask(this.shape);

  /// Apple does not publish the corner radius. This is a guide for the preview only.
  static const double roundedCornerFraction = 0.22;

  final WatchShape shape;

  double cornerRadius(Size frame) {
    final double shortSide = math.min(frame.width, frame.height);
    return switch (shape) {
      WatchShape.round => shortSide / 2,
      WatchShape.roundedRect => shortSide * roundedCornerFraction,
    };
  }

  /// A round mask is the largest circle in the frame, centred.
  RRect outline(Rect frame) {
    if (shape == WatchShape.round) {
      final double side = math.min(frame.width, frame.height);
      return RRect.fromRectAndRadius(
        Rect.fromCenter(center: frame.center, width: side, height: side),
        Radius.circular(side / 2),
      );
    }
    return RRect.fromRectAndRadius(frame, Radius.circular(cornerRadius(frame.size)));
  }

  bool shows(Rect frame, Offset point) => outline(frame).contains(point);
}
