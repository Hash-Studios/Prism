import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_position/data/placement_renderer.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

const Duration _loadTimeout = Duration(seconds: 30);

@LazySingleton(as: WallpaperPositionRepository)
class WallpaperPositionRepositoryImpl implements WallpaperPositionRepository {
  @override
  Future<PlacementSource> load(String url) async {
    final bool remote = url.startsWith('http://') || url.startsWith('https://');
    final File file = remote ? await PrismFullImageCache.instance.getSingleFile(url).timeout(_loadTimeout) : File(url);
    final ui.Image image = await decodeCapped(await file.readAsBytes());
    try {
      return PlacementSource(image: image, dominantColor: await dominantColorOf(image));
    } catch (_) {
      image.dispose();
      rethrow;
    }
  }

  @override
  Future<File> render(PlacementSource source, WallpaperPlacement placement, ui.Size outputSize) async {
    final ({int width, int height}) size = exportSize(
      outputSize.width.round(),
      outputSize.height.round(),
      deviceLongSidePx: math.max(outputSize.width, outputSize.height),
    );
    final Uint8List png = await renderPlacementPng(
      source.image,
      placement,
      width: size.width,
      height: size.height,
      fillColor: source.dominantColor,
    );
    final Directory base = Directory('${(await getTemporaryDirectory()).path}/prism_edit');
    await base.create(recursive: true);
    final Directory directory = await base.createTemp('position_');
    final File file = File('${directory.path}/placement.png');
    try {
      await file.writeAsBytes(png);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
    return file;
  }

  @override
  Future<void> discard(File file) async {
    try {
      await file.parent.delete(recursive: true);
    } catch (_) {}
  }
}

/// Decodes [bytes] so the long side is at most [maxExportLongSide], which keeps a 4K wall cheap to hold.
Future<ui.Image> decodeCapped(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final int longSide = math.max(descriptor.width, descriptor.height);
      final double scale = longSide > maxExportLongSide ? maxExportLongSide / longSide : 1;
      final ui.Codec codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
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
