import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// The folder in the temporary directory that holds the tinted PNGs. Clear cache empties it.
const String tintedWallpaperFolder = 'prism_tint';

const int _maxRemembered = 6;

// Oldest first. Only renders that finished are in here.
final Map<String, String> _files = <String, String>{};
Future<void> _queue = Future<void>.value();
String? _sweptPath;
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

/// Decodes [bytes] at the size [exportSize] gives, so a large source never exists at full size in memory.
/// The caller disposes the image.
@visibleForTesting
Future<ui.Image> decodeForTint(Uint8List bytes, {double deviceLongSidePx = 0}) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final ({int width, int height}) size = exportSize(
        descriptor.width,
        descriptor.height,
        deviceLongSidePx: deviceLongSidePx,
      );
      final ui.Codec codec = await descriptor.instantiateCodec(targetWidth: size.width, targetHeight: size.height);
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

/// Renders the wallpaper at [source] (an http(s) URL or a local file path) with [tint] and returns the PNG path.
///
/// Renders run one at a time. The same [source] and [tint] give the same file again while it still exists. The last
/// 6 renders are kept and the file of the oldest one is deleted when a 7th is made, so a path stays valid for a few
/// renders and no longer.
Future<String> renderTintedWallpaper({required String source, required Color tint, double deviceLongSidePx = 0}) {
  return _inOrder(() async {
    final String key = '$source|${tint.toARGB32()}';
    final String? known = _files.remove(key);
    if (known != null && await File(known).exists()) {
      _files[key] = known;
      return known;
    }
    final String path = await _renderToFile(source, tint, deviceLongSidePx);
    _files[key] = path;
    while (_files.length > _maxRemembered) {
      await _deleteFile(_files.remove(_files.keys.first)!);
    }
    return path;
  });
}

/// Deletes every tinted wallpaper file and forgets them. Settings > Clear cache calls this.
Future<void> clearTintedWallpapers() {
  return _inOrder(() async {
    _files.clear();
    await _deleteDirectory(await _tintDirectory());
  });
}

Future<T> _inOrder<T>(Future<T> Function() task) {
  final Future<T> result = _queue.then((_) => task());
  _queue = result.then<void>((_) {}, onError: (Object _) {});
  return result;
}

Future<String> _renderToFile(String source, Color tint, double deviceLongSidePx) async {
  final Directory directory = await _sessionDirectory();
  final File input = source.startsWith('http://') || source.startsWith('https://')
      ? await PrismFullImageCache.instance.getSingleFile(source).timeout(const Duration(seconds: 30))
      : File(source);
  final ui.Image image = await decodeForTint(await input.readAsBytes(), deviceLongSidePx: deviceLongSidePx);
  final Uint8List png;
  try {
    png = await renderTintedPng(image, tint, deviceLongSidePx: deviceLongSidePx);
  } finally {
    image.dispose();
  }
  final File output = File('${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${_serial++}.png');
  try {
    await output.writeAsBytes(png);
  } catch (_) {
    await _deleteFile(output.path);
    rethrow;
  }
  return output.path;
}

Future<Directory> _tintDirectory() async => Directory('${(await getTemporaryDirectory()).path}/$tintedWallpaperFolder');

/// The folder, empty of files from earlier app runs the first time it is asked for.
Future<Directory> _sessionDirectory() async {
  final Directory directory = await _tintDirectory();
  if (_sweptPath != directory.path) {
    _sweptPath = directory.path;
    await _deleteDirectory(directory);
  }
  await directory.create(recursive: true);
  return directory;
}

Future<void> _deleteFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    return;
  }
}

Future<void> _deleteDirectory(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException catch (error, stackTrace) {
    logger.w('Could not delete tinted wallpapers', error: error, stackTrace: stackTrace);
  }
}
