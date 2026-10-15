import 'dart:math' as math;

/// Where to crop a photo, and how large to render it, so one texture fills the screen.
///
/// The renderer limits are 4096 px per side, 4 million pixels and 8 MiB encoded.
class TextureGeometry {
  const TextureGeometry({
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
    required this.outputWidth,
    required this.outputHeight,
  });

  static const int maxOutputHeight = 2400;
  static const int maxOutputPixels = 3500000;
  static const int maxEncodedBytes = 8 * 1024 * 1024;

  final double cropLeft;
  final double cropTop;
  final double cropWidth;
  final double cropHeight;
  final int outputWidth;
  final int outputHeight;

  factory TextureGeometry.compute({
    required int sourceWidth,
    required int sourceHeight,
    required double screenAspectRatio,
  }) {
    final double aspect = screenAspectRatio.isFinite && screenAspectRatio > 0 ? screenAspectRatio : 9 / 19.5;
    final double sourceAspect = sourceWidth / sourceHeight;
    final double cropWidth = sourceAspect > aspect ? sourceHeight * aspect : sourceWidth.toDouble();
    final double cropHeight = sourceAspect > aspect ? sourceHeight.toDouble() : sourceWidth / aspect;
    final double pixelCapHeight = math.sqrt(maxOutputPixels / aspect);
    final int outputHeight = math.max(1, math.min(cropHeight, math.min(maxOutputHeight, pixelCapHeight)).floor());
    final int outputWidth = math.max(1, (outputHeight * aspect).round());
    return TextureGeometry(
      cropLeft: (sourceWidth - cropWidth) / 2,
      cropTop: (sourceHeight - cropHeight) / 2,
      cropWidth: cropWidth,
      cropHeight: cropHeight,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
    );
  }

  /// Scale from source pixels to output pixels.
  double get scale => outputHeight / cropHeight;
}
