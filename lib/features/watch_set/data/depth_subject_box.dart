import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/logger/logger.dart';

/// Below this spread of grey levels the map is flat and has no subject.
const int _minDepthSpread = 24;

/// The map is decoded at most this wide, which is enough to place a frame.
const int _decodeWidth = 128;

/// The box around the nearest quarter of the depth range in a grey depth map (bright is near), in source pixels. Null
/// when the map is flat. [rgba] is [width] x [height] pixels, 4 bytes each; the red channel is the depth.
PixelRect? subjectBoxFromDepth(
  Uint8List rgba,
  int width,
  int height, {
  required int sourceWidth,
  required int sourceHeight,
}) {
  if (width < 1 || height < 1 || rgba.length < width * height * 4) return null;
  int lowest = 255;
  int highest = 0;
  for (int i = 0; i < width * height; i++) {
    final int value = rgba[i * 4];
    lowest = math.min(lowest, value);
    highest = math.max(highest, value);
  }
  if (highest - lowest < _minDepthSpread) return null;
  final int threshold = highest - (highest - lowest) ~/ 4;
  int left = width;
  int top = height;
  int right = -1;
  int bottom = -1;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4] < threshold) continue;
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }
  }
  final double sx = sourceWidth / width;
  final double sy = sourceHeight / height;
  final int boxLeft = (left * sx).floor();
  final int boxTop = (top * sy).floor();
  return PixelRect(
    boxLeft,
    boxTop,
    math.max(1, ((right + 1) * sx).ceil() - boxLeft),
    math.max(1, ((bottom + 1) * sy).ceil() - boxTop),
  );
}

/// [subjectBoxFromDepth] for the depth map at [mapUrl]. Null when the map does not load in time or is flat.
Future<PixelRect?> loadDepthSubjectBox(String mapUrl, {required int sourceWidth, required int sourceHeight}) async {
  try {
    final file = await WallpaperService.resolveToLocalFile(mapUrl).timeout(const Duration(seconds: 8));
    final ui.Codec codec = await ui.instantiateImageCodec(await file.readAsBytes(), targetWidth: _decodeWidth);
    try {
      final ui.Image image = (await codec.getNextFrame()).image;
      try {
        final ByteData? data = await image.toByteData();
        if (data == null) return null;
        return subjectBoxFromDepth(
          data.buffer.asUint8List(),
          image.width,
          image.height,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (error, stackTrace) {
    logger.w('Could not read the depth map for the watch crop', error: error, stackTrace: stackTrace);
    return null;
  }
}
