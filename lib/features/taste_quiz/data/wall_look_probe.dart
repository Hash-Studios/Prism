import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';

Future<Uint8List?> _cachedBytes(String url) async {
  final file = await PrismImageCache.instance.getFileFromCache(url);
  return file?.file.readAsBytes();
}

/// Measures a wall from its cached image. It never uses the network. Returns null when the image is missing or bad.
Future<WallLook?> measureWallLook(String url, {Future<Uint8List?> Function(String url)? bytesOf}) async {
  try {
    final Uint8List? bytes = await (bytesOf ?? _cachedBytes)(url);
    if (bytes == null || bytes.isEmpty) return null;
    final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 48);
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      try {
        final ByteData? data = await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        if (data == null) return null;
        return wallLookOf(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          frame.image.width,
          frame.image.height,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}
