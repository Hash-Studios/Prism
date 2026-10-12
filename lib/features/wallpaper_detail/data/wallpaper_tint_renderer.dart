import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

final Map<String, Future<String>> _renders = <String, Future<String>>{};
int _serial = 0;

/// Draws [source] under a hue blend of [tint] and returns PNG bytes. The long side is capped, see [exportSize].
Future<Uint8List> renderTintedPng(ui.Image source, Color tint, {double deviceLongSidePx = 0}) async {
  final ({int width, int height}) size = exportSize(source.width, source.height, deviceLongSidePx: deviceLongSidePx);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()),
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.mode(tint, BlendMode.hue),
  );
  final ui.Image rendered = await rasterizePicture(recorder.endRecording(), size.width, size.height);
  try {
    final ByteData? data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encode returned null');
    return data.buffer.asUint8List();
  } finally {
    rendered.dispose();
  }
}

/// Renders the wallpaper at [source] (an http(s) URL or a local file path) with [tint] and returns the PNG path.
///
/// The same [source] and [tint] give the same file again while it still exists.
Future<String> renderTintedWallpaper({required String source, required Color tint, double deviceLongSidePx = 0}) async {
  final String key = '$source|${tint.toARGB32()}';
  final Future<String>? known = _renders[key];
  if (known != null) {
    final String path = await known;
    if (await File(path).exists()) return path;
  }
  final Future<String> render = _renderToFile(source, tint, deviceLongSidePx);
  _renders[key] = render;
  try {
    return await render;
  } catch (_) {
    if (identical(_renders[key], render)) _renders.remove(key);
    rethrow;
  }
}

Future<String> _renderToFile(String source, Color tint, double deviceLongSidePx) async {
  final File input = source.startsWith('http://') || source.startsWith('https://')
      ? await PrismFullImageCache.instance.getSingleFile(source).timeout(const Duration(seconds: 30))
      : File(source);
  final ui.Codec codec = await ui.instantiateImageCodec(await input.readAsBytes());
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    try {
      final Uint8List png = await renderTintedPng(frame.image, tint, deviceLongSidePx: deviceLongSidePx);
      final Directory directory = Directory('${(await getTemporaryDirectory()).path}/prism_tint');
      await directory.create(recursive: true);
      final File output = File('${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${_serial++}.png');
      await output.writeAsBytes(png);
      return output.path;
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
