import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// The folder in the temporary directory that holds watch images until they are saved.
const String watchSetFolder = 'prism_watch_set';

final Map<String, Future<void>> _sessionSweeps = <String, Future<void>>{};
int _serial = 0;

/// Renders [crop] of the wall at [source] (an http(s) URL or a local path) at exactly [format]'s pixel size and returns
/// the PNG path. [crop] may be on a smaller copy of the wall: it is scaled to the decoded file first. The caller
/// deletes the file with [deleteWatchImage].
Future<String> renderWatchImage({
  required String source,
  required CropSpec crop,
  required WatchFormat format,
  String? wallpaperId,
  WallpaperSource? wallpaperSource,
}) async {
  final Directory directory = await _sessionDirectory();
  final File input = await WallpaperService.resolveToLocalFile(
    source,
    wallpaperId: wallpaperId,
    wallpaperSource: wallpaperSource,
  );
  final Uint8List png = await withExportTimeLimit(_render(input.path, crop, format));
  final File output = File('${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${_serial++}.png');
  try {
    await output.writeAsBytes(png, flush: true);
  } catch (_) {
    await deleteWatchImage(output.path);
    rethrow;
  }
  return output.path;
}

Future<Uint8List> _render(String path, CropSpec crop, WatchFormat format) async {
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(await ui.ImmutableBuffer.fromFilePath(path));
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      return await renderEditedPng(
        image,
        const <WallpaperFilter>[],
        WallpaperAdjustments.none,
        crop: crop.scaledTo(sourceWidth: image.width, sourceHeight: image.height),
        outputSize: (width: format.width, height: format.height),
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<void> deleteWatchImage(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    return;
  }
}

/// The folder, empty of files from earlier app runs the first time it is asked for.
Future<Directory> _sessionDirectory() async {
  final Directory directory = Directory('${(await getTemporaryDirectory()).path}/$watchSetFolder');
  final Future<void> ready = _sessionSweeps.putIfAbsent(directory.path, () => _sweepDirectory(directory));
  try {
    await ready;
  } catch (_) {
    if (identical(_sessionSweeps[directory.path], ready)) _sessionSweeps.remove(directory.path);
    rethrow;
  }
  await directory.create(recursive: true);
  return directory;
}

Future<void> _sweepDirectory(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException catch (error, stackTrace) {
    logger.w('Could not delete old watch images', error: error, stackTrace: stackTrace);
  }
}
