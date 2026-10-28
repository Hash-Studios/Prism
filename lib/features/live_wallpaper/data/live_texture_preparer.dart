import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/data/texture_geometry.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LiveTextureException implements Exception {
  const LiveTextureException(this.failure);

  final LiveApplyFailure failure;

  @override
  String toString() => failure.name;
}

typedef _PreparedTexture = ({String path, TextureGeometry geometry, int sourceWidth, int sourceHeight});

/// Downloads a wallpaper and writes a screen-shaped JPEG that fits the renderer texture limits.
@lazySingleton
class LiveTexturePreparer {
  const LiveTexturePreparer();

  Future<String> prepare(String imageUrl, double screenAspectRatio) async => (await _prepare(
    imageUrl,
    'live_wallpaper_texture.jpg',
    (width, height) => _screenCrop(width, height, screenAspectRatio),
  )).path;

  /// The photo and its depth map, the map cropped with the photo's crop so near parts line up.
  Future<({String photo, String depth})> prepareWithDepth(
    String imageUrl,
    String depthMapUrl,
    double screenAspectRatio,
  ) async {
    final _PreparedTexture photo = await _prepare(
      imageUrl,
      'live_wallpaper_texture.jpg',
      (width, height) => _screenCrop(width, height, screenAspectRatio),
    );
    final _PreparedTexture depth = await _prepare(
      depthMapUrl,
      'live_wallpaper_depth.jpg',
      (width, height) => photo.geometry.scaledTo(
        fromWidth: photo.sourceWidth,
        fromHeight: photo.sourceHeight,
        toWidth: width,
        toHeight: height,
      ),
    );
    return (photo: photo.path, depth: depth.path);
  }

  static TextureGeometry _screenCrop(int width, int height, double screenAspectRatio) =>
      TextureGeometry.compute(sourceWidth: width, sourceHeight: height, screenAspectRatio: screenAspectRatio);

  Future<_PreparedTexture> _prepare(
    String url,
    String fileName,
    TextureGeometry Function(int sourceWidth, int sourceHeight) geometryFor,
  ) async {
    final File source;
    try {
      source = await WallpaperService.resolveToLocalFile(url).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const LiveTextureException(LiveApplyFailure.textureDownloadFailed);
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
      final int sourceWidth = descriptor.width;
      final int sourceHeight = descriptor.height;
      final TextureGeometry geometry = geometryFor(sourceWidth, sourceHeight);
      final double scale = geometry.scale;
      codec = await descriptor.instantiateCodec(targetWidth: scale < 1 ? (descriptor.width * scale).round() : null);
      decoded = (await codec.getNextFrame()).image;
      codec.dispose();
      codec = null;
      recorder = ui.PictureRecorder();
      final double decodedScaleX = decoded.width / descriptor.width;
      final double decodedScaleY = decoded.height / descriptor.height;
      ui.Canvas(recorder).drawImageRect(
        decoded,
        ui.Rect.fromLTWH(
          geometry.cropLeft * decodedScaleX,
          geometry.cropTop * decodedScaleY,
          geometry.cropWidth * decodedScaleX,
          geometry.cropHeight * decodedScaleY,
        ),
        ui.Rect.fromLTWH(0, 0, geometry.outputWidth.toDouble(), geometry.outputHeight.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      picture = recorder.endRecording();
      cropped = await picture.toImage(geometry.outputWidth, geometry.outputHeight);
      final ByteData? png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const LiveTextureException(LiveApplyFailure.texturePreparationFailed);
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
        throw const LiveTextureException(LiveApplyFailure.textureTooDetailed);
      }
      final Directory directory = await getTemporaryDirectory();
      final File target = File(p.join(directory.path, fileName));
      await target.writeAsBytes(jpeg, flush: true);
      return (path: target.path, geometry: geometry, sourceWidth: sourceWidth, sourceHeight: sourceHeight);
    } on LiveTextureException {
      rethrow;
    } catch (_) {
      throw const LiveTextureException(LiveApplyFailure.texturePreparationFailed);
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
