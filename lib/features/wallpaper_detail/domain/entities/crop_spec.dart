import 'dart:math' as math;

/// The frame shapes the crop step offers.
enum CropPreset {
  free,

  /// The aspect of this device's screen in portrait.
  phone,

  /// 9:16.
  portrait,

  /// 1:1.
  square,

  /// 16:9, a desktop screen.
  landscape,

  /// The aspect of the whole image as it is turned now.
  original,
}

/// A corner of the crop frame, as the user sees it.
enum CropCorner {
  topLeft(-1, -1),
  topRight(1, -1),
  bottomLeft(-1, 1),
  bottomRight(1, 1);

  const CropCorner(this.sx, this.sy);

  /// -1 when the corner is on the left or top edge, 1 on the right or bottom edge.
  final int sx;
  final int sy;
}

/// An area of whole pixels.
class PixelRect {
  const PixelRect(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is PixelRect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PixelRect($left, $top, ${width}x$height)';
}

/// One crop of one source image.
///
/// The source is the decoded image, with any EXIF orientation already applied. The view is the source turned
/// [quarterTurns] times clockwise: it is what the user sees and what the export writes. [rect] is the kept area in
/// view pixels, and [sourceRect] is the same area in source pixels. Every operation returns a new spec whose rect is
/// inside the image, at least [minSide] pixels on each side, and on the preset's aspect when the preset has one.
class CropSpec {
  const CropSpec._({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.phoneAspect,
    required this.quarterTurns,
    required this.preset,
    required this.rect,
    required this.adjusted,
  });

  /// The whole image, not turned. [phoneAspect] is the screen's width over its height in portrait.
  factory CropSpec.initial({required int sourceWidth, required int sourceHeight, required double phoneAspect}) {
    if (sourceWidth < 1 || sourceHeight < 1) throw ArgumentError('Empty source: ${sourceWidth}x$sourceHeight');
    return CropSpec._(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      phoneAspect: phoneAspect > 0 ? math.min(phoneAspect, 1 / phoneAspect) : 9 / 16,
      quarterTurns: 0,
      preset: CropPreset.original,
      rect: PixelRect(0, 0, sourceWidth, sourceHeight),
      adjusted: false,
    );
  }

  final int sourceWidth;
  final int sourceHeight;
  final double phoneAspect;

  /// 0 to 3 clockwise turns of 90 degrees.
  final int quarterTurns;
  final CropPreset preset;

  /// The kept area in view pixels.
  final PixelRect rect;

  /// True when the user moved or resized the frame by hand since the last preset or reset.
  final bool adjusted;

  bool get _turned => quarterTurns.isOdd;
  int get viewWidth => _turned ? sourceHeight : sourceWidth;
  int get viewHeight => _turned ? sourceWidth : sourceHeight;

  /// Width over height of the frame the preset asks for, in view pixels. Null for [CropPreset.free].
  double? get aspect => aspectOf(preset);

  double? aspectOf(CropPreset preset) => switch (preset) {
    CropPreset.free => null,
    CropPreset.phone => phoneAspect,
    CropPreset.portrait => 9 / 16,
    CropPreset.square => 1,
    CropPreset.landscape => 16 / 9,
    CropPreset.original => viewWidth / viewHeight,
  };

  /// The smallest side the frame may have: a tenth of the image's short side, and at least one pixel.
  int get minSide => math.max(1, (math.min(sourceWidth, sourceHeight) / 10).round());

  /// True when the export would be the source as it is.
  bool get isIdentity =>
      quarterTurns == 0 && rect.left == 0 && rect.top == 0 && rect.width == sourceWidth && rect.height == sourceHeight;

  /// Size of the exported image: the kept area at full resolution.
  int get outputWidth => rect.width;
  int get outputHeight => rect.height;

  /// [rect] in source pixels, before the turn.
  PixelRect get sourceRect {
    final PixelRect r = rect;
    return switch (quarterTurns) {
      0 => r,
      1 => PixelRect(r.top, sourceHeight - r.right, r.height, r.width),
      2 => PixelRect(sourceWidth - r.right, sourceHeight - r.bottom, r.width, r.height),
      _ => PixelRect(sourceWidth - r.bottom, r.left, r.height, r.width),
    };
  }

  /// The largest frame of [preset]'s aspect inside the image, centred on the current frame, then kept inside.
  CropSpec withPreset(CropPreset preset) {
    final double? target = aspectOf(preset);
    if (target == null) return _copy(preset: preset, adjusted: false);
    return _copy(preset: preset, rect: _fit(target), adjusted: false);
  }

  /// Turns the image 90 degrees clockwise. The frame turns with it. A preset with a fixed aspect then fits a new
  /// frame of that aspect, so 9:16 stays 9:16.
  CropSpec rotated() {
    final PixelRect r = rect;
    final CropSpec turned = _copy(
      quarterTurns: (quarterTurns + 1) % 4,
      rect: PixelRect(viewHeight - r.bottom, r.left, r.height, r.width),
    );
    final double? target = turned.aspect;
    if (target == null || preset == CropPreset.original || preset == CropPreset.square) return turned;
    return turned._copy(rect: turned._fit(target));
  }

  /// The whole image, not turned, with [CropPreset.original].
  CropSpec reset() => CropSpec.initial(sourceWidth: sourceWidth, sourceHeight: sourceHeight, phoneAspect: phoneAspect);

  /// The frame moved by [dx], [dy] view pixels and kept inside the image.
  CropSpec moved(double dx, double dy) {
    final int left = (rect.left + dx).round().clamp(0, viewWidth - rect.width);
    final int top = (rect.top + dy).round().clamp(0, viewHeight - rect.height);
    return _copy(rect: PixelRect(left, top, rect.width, rect.height), adjusted: true);
  }

  /// The frame scaled by [factor] about its centre, on the same aspect, and kept inside the image.
  CropSpec scaled(double factor) {
    final double ratio = aspect ?? rect.width / rect.height;
    final double maxWidth = math.min(viewWidth.toDouble(), viewHeight * ratio);
    final double minWidth = math.min(maxWidth, math.max(minSide.toDouble(), minSide * ratio));
    final double width = (rect.width * factor).clamp(minWidth, maxWidth);
    return _copy(rect: _centred(width, width / ratio, _centreX, _centreY), adjusted: true);
  }

  /// The frame with [corner] moved by [dx], [dy] view pixels. The opposite corner stays where it is. A preset with an
  /// aspect keeps it: the drag is projected on the frame's diagonal.
  CropSpec resized(CropCorner corner, double dx, double dy) {
    final double anchorX = corner.sx < 0 ? rect.right.toDouble() : rect.left.toDouble();
    final double anchorY = corner.sy < 0 ? rect.bottom.toDouble() : rect.top.toDouble();
    final double roomX = corner.sx < 0 ? anchorX : viewWidth - anchorX;
    final double roomY = corner.sy < 0 ? anchorY : viewHeight - anchorY;
    final double grownX = rect.width + corner.sx * dx;
    final double grownY = rect.height + corner.sy * dy;
    final double? target = aspect;
    double width;
    double height;
    if (target == null) {
      width = grownX.clamp(math.min(minSide.toDouble(), roomX), roomX);
      height = grownY.clamp(math.min(minSide.toDouble(), roomY), roomY);
    } else {
      final double w = rect.width.toDouble();
      final double h = rect.height.toDouble();
      final double t = ((grownX - w) * w + (grownY - h) * h) / (w * w + h * h);
      final double maxWidth = math.min(roomX, roomY * target);
      final double minWidth = math.min(maxWidth, math.max(minSide.toDouble(), minSide * target));
      width = (w * (1 + t)).clamp(minWidth, maxWidth);
      height = width / target;
    }
    final int intWidth = math.max(1, width.round());
    final int intHeight = math.max(1, height.round());
    final int left = corner.sx < 0 ? anchorX.round() - intWidth : anchorX.round();
    final int top = corner.sy < 0 ? anchorY.round() - intHeight : anchorY.round();
    return _copy(rect: _inside(left, top, intWidth, intHeight), adjusted: true);
  }

  double get _centreX => rect.left + rect.width / 2;
  double get _centreY => rect.top + rect.height / 2;

  PixelRect _fit(double target) {
    final double width = math.min(viewWidth.toDouble(), viewHeight * target);
    return _centred(width, width / target, _centreX, _centreY);
  }

  PixelRect _centred(double width, double height, double centreX, double centreY) {
    final int w = width.round().clamp(1, viewWidth);
    final int h = height.round().clamp(1, viewHeight);
    return _inside((centreX - w / 2).round(), (centreY - h / 2).round(), w, h);
  }

  PixelRect _inside(int left, int top, int width, int height) {
    final int w = width.clamp(1, viewWidth);
    final int h = height.clamp(1, viewHeight);
    return PixelRect(left.clamp(0, viewWidth - w), top.clamp(0, viewHeight - h), w, h);
  }

  CropSpec _copy({int? quarterTurns, CropPreset? preset, PixelRect? rect, bool? adjusted}) => CropSpec._(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    phoneAspect: phoneAspect,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    preset: preset ?? this.preset,
    rect: rect ?? this.rect,
    adjusted: adjusted ?? this.adjusted,
  );

  @override
  bool operator ==(Object other) =>
      other is CropSpec &&
      other.sourceWidth == sourceWidth &&
      other.sourceHeight == sourceHeight &&
      other.phoneAspect == phoneAspect &&
      other.quarterTurns == quarterTurns &&
      other.preset == preset &&
      other.rect == rect &&
      other.adjusted == adjusted;

  @override
  int get hashCode => Object.hash(sourceWidth, sourceHeight, phoneAspect, quarterTurns, preset, rect, adjusted);

  @override
  String toString() => 'CropSpec(${sourceWidth}x$sourceHeight, turns $quarterTurns, $preset, $rect)';
}
