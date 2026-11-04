import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/features/watch_set/domain/smart_watch_crop.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> solidImage(int width, int height, Color color) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  return rasterizePicture(recorder.endRecording(), width, height);
}

Future<({int width, int height})> decodedSize(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      return (width: image.width, height: image.height);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a smart watch crop renders at each watch format size', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(1080, 1920, const Color(0xFF336699));
      try {
        final List<(WatchFormat, int, int)> cases = [
          (WatchFormat.apple46, 416, 496),
          (WatchFormat.appleUltra3, 422, 514),
          (WatchFormat.galaxyLarge, 480, 480),
        ];
        for (final (WatchFormat format, int width, int height) in cases) {
          final CropSpec crop = smartWatchCrop(sourceWidth: 1080, sourceHeight: 1920, format: format);
          final Uint8List png = await renderEditedPng(
            source,
            const <WallpaperFilter>[],
            WallpaperAdjustments.none,
            crop: crop,
            outputSize: (width: format.width, height: format.height),
          );
          final size = await decodedSize(png);
          expect((size.width, size.height), (width, height), reason: format.id);
        }
      } finally {
        source.dispose();
      }
    });
  });

  testWidgets('a crop made on a half size preview renders at the watch size', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(1080, 1920, const Color(0xFF336699));
      try {
        final CropSpec crop = smartWatchCrop(
          sourceWidth: 540,
          sourceHeight: 960,
          format: WatchFormat.apple42,
        ).scaledTo(sourceWidth: 1080, sourceHeight: 1920);
        final Uint8List png = await renderEditedPng(
          source,
          const <WallpaperFilter>[],
          WallpaperAdjustments.none,
          crop: crop,
          outputSize: (width: 374, height: 446),
        );
        final size = await decodedSize(png);
        expect((size.width, size.height), (374, 446));
      } finally {
        source.dispose();
      }
    });
  });
}
