import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/live_wallpaper/data/texture_geometry.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LiveTextureException implements Exception {
  const LiveTextureException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a wallpaper and writes a screen-shaped JPEG that fits the renderer texture limits.
@lazySingleton
class LiveTexturePreparer {
  const LiveTexturePreparer();

  Future<String> prepare(String imageUrl, double screenAspectRatio) async {
    final File source;
    try {
      source = await PrismFullImageCache.instance.getSingleFile(imageUrl).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const LiveTextureException("Couldn't download the wallpaper. Check your connection and try again.");
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    ui.PictureRecorder? recorder;
    ui.Picture? picture;
    ui.Image? cropped;
    try {
      final Uint8List bytes = await source.readAsBytes();
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final TextureGeometry geometry = TextureGeometry.compute(
        sourceWidth: descriptor.width,
        sourceHeight: descriptor.height,
        screenAspectRatio: screenAspectRatio,
      );
      final double scale = geometry.scale;
      codec = await descriptor.instantiateCodec(targetWidth: scale < 1 ? (descriptor.width * scale).round() : null);
      decoded = (await codec.getNextFrame()).image;
      codec.dispose();
      codec = null;
      recorder = ui.PictureRecorder();
      final double decodedScale = decoded.width / descriptor.width;
      ui.Canvas(recorder).drawImageRect(
        decoded,
        ui.Rect.fromLTWH(
          geometry.cropLeft * decodedScale,
          geometry.cropTop * decodedScale,
          geometry.cropWidth * decodedScale,
          geometry.cropHeight * decodedScale,
        ),
        ui.Rect.fromLTWH(0, 0, geometry.outputWidth.toDouble(), geometry.outputHeight.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      picture = recorder.endRecording();
      cropped = await picture.toImage(geometry.outputWidth, geometry.outputHeight);
      final ByteData? png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const LiveTextureException("Couldn't prepare the wallpaper.");
      cropped.dispose();
      cropped = null;
      picture.dispose();
      picture = null;
      decoded.dispose();
      decoded = null;
      descriptor.dispose();
      descriptor = null;
      buffer.dispose();
      buffer = null;
      final Uint8List jpeg = await FlutterImageCompress.compressWithList(
        png.buffer.asUint8List(),
        minWidth: geometry.outputWidth,
        minHeight: geometry.outputHeight,
        quality: 90,
      );
      if (jpeg.isEmpty || jpeg.length > TextureGeometry.maxEncodedBytes) {
        throw const LiveTextureException('That wallpaper is too detailed to animate.');
      }
      final Directory directory = await getTemporaryDirectory();
      final File target = File(p.join(directory.path, 'live_wallpaper_texture.jpg'));
      await target.writeAsBytes(jpeg, flush: true);
      return target.path;
    } on LiveTextureException {
      rethrow;
    } catch (_) {
      throw const LiveTextureException("Couldn't prepare the wallpaper.");
    } finally {
      if (recorder?.isRecording ?? false) recorder!.endRecording().dispose();
      cropped?.dispose();
      picture?.dispose();
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
