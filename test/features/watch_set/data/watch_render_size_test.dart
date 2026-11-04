import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/features/watch_set/data/watch_image_renderer.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/features/watch_set/domain/smart_watch_crop.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SweepingDirectory extends Fake implements Directory {
  _SweepingDirectory(this.real);

  final Directory real;
  final Completer<void> deleting = Completer<void>();
  final Completer<void> release = Completer<void>();
  final Completer<void> deleted = Completer<void>();
  int createsDuringSweep = 0;

  @override
  String get path => real.path;

  @override
  Future<bool> exists() => real.exists();

  @override
  Future<Directory> delete({bool recursive = false}) async {
    deleting.complete();
    await release.future;
    await real.delete(recursive: recursive);
    deleted.complete();
    return this;
  }

  @override
  Future<Directory> create({bool recursive = false}) async {
    if (!deleted.isCompleted) createsDuringSweep++;
    await deleted.future;
    await real.create(recursive: recursive);
    return this;
  }
}

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

  testWidgets('concurrent renders wait for the session sweep before using its directory', (tester) async {
    await tester.runAsync(() async {
      final Directory root = await Directory.systemTemp.createTemp('watch_render_sweep_');
      final Directory output = await Directory('${root.path}/$watchSetFolder').create();
      final File stale = await File('${output.path}/old.png').writeAsString('old session');
      final ui.Image image = await solidImage(40, 80, const Color(0xFF336699));
      final File input = File('${root.path}/source.png');
      try {
        await input.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      final _SweepingDirectory sweeping = _SweepingDirectory(output);
      final Completer<void> secondDirectoryRequest = Completer<void>();
      int requests = 0;
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
        if (++requests == 2) secondDirectoryRequest.complete();
        return root.path;
      });
      final Zone realIo = Zone.current;
      try {
        await IOOverrides.runZoned(() async {
          Future<String> render() => renderWatchImage(
            source: input.path,
            crop: smartWatchCrop(sourceWidth: 40, sourceHeight: 80, format: WatchFormat.apple46),
            format: WatchFormat.apple46,
          );
          final Future<String> first = render();
          await sweeping.deleting.future;
          final Future<String> second = render();
          await secondDirectoryRequest.future;
          await Future<void>.delayed(Duration.zero);
          sweeping.release.complete();
          final List<String> paths = await Future.wait([first, second]);
          expect(sweeping.createsDuringSweep, 0);
          expect(paths.toSet(), hasLength(2));
          for (final String path in paths) {
            expect(await decodedSize(await File(path).readAsBytes()), (width: 416, height: 496));
          }
          expect(await stale.exists(), isFalse);
        }, createDirectory: (path) => path == output.path ? sweeping : realIo.run(() => Directory(path)));
        await output.delete(recursive: true);
        final String recreated = await renderWatchImage(
          source: input.path,
          crop: smartWatchCrop(sourceWidth: 40, sourceHeight: 80, format: WatchFormat.apple46),
          format: WatchFormat.apple46,
        );
        expect(await decodedSize(await File(recreated).readAsBytes()), (width: 416, height: 496));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await root.delete(recursive: true);
      }
    });
  });

  testWidgets('a smart watch crop renders at each watch format size', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await solidImage(1080, 1920, const Color(0xFF336699));
      try {
        final List<(WatchFormat, int, int)> cases = [
          (WatchFormat.apple40, 324, 394),
          (WatchFormat.apple44, 368, 448),
          (WatchFormat.apple41, 352, 430),
          (WatchFormat.apple45, 396, 484),
          (WatchFormat.apple42, 374, 446),
          (WatchFormat.apple46, 416, 496),
          (WatchFormat.appleUltra, 410, 502),
          (WatchFormat.appleUltra3, 422, 514),
          (WatchFormat.pixelWatch, 456, 456),
          (WatchFormat.galaxySmall, 438, 438),
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

  testWidgets('renderer applies a moved preview crop to an odd-sized full source', (tester) async {
    await tester.runAsync(() async {
      final Directory root = await Directory.systemTemp.createTemp('watch_render_crop_');
      String? outputPath;
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => root.path,
      );
      try {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        Canvas(recorder)
          ..drawRect(const Rect.fromLTWH(0, 0, 3001, 790), Paint()..color = const Color(0xFFFF0000))
          ..drawRect(const Rect.fromLTWH(0, 790, 3001, 1210), Paint()..color = const Color(0xFF0000FF))
          ..drawRect(const Rect.fromLTWH(0, 2000, 3001, 1000), Paint()..color = const Color(0xFF00FF00))
          ..drawRect(const Rect.fromLTWH(0, 3000, 3001, 1000), Paint()..color = const Color(0xFFFFFF00));
        final ui.Image source = await rasterizePicture(recorder.endRecording(), 3001, 4000);
        final File input = File('${root.path}/source.png');
        try {
          await input.writeAsBytes(
            (await source.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
            flush: true,
          );
        } finally {
          source.dispose();
        }

        final CropSpec previewCrop = smartWatchCrop(
          sourceWidth: 1201,
          sourceHeight: 1600,
          format: WatchFormat.apple46,
        ).moved(0, -60);
        final String renderedPath = await renderWatchImage(
          source: input.path,
          crop: previewCrop,
          format: WatchFormat.apple46,
        );
        outputPath = renderedPath;
        final ui.Codec codec = await ui.instantiateImageCodec(await File(renderedPath).readAsBytes());
        try {
          final ui.Image image = (await codec.getNextFrame()).image;
          try {
            expect((image.width, image.height), (416, 496));
            final ByteData rgba = (await image.toByteData())!;
            final List<(int, List<int>)> samples = [
              (60, [255, 0, 0, 255]),
              (99, [255, 0, 0, 255]),
              (120, [0, 0, 255, 255]),
              (200, [0, 0, 255, 255]),
              (260, [0, 0, 255, 255]),
              (338, [0, 255, 0, 255]),
              (477, [255, 255, 0, 255]),
            ];
            for (final (int y, List<int> expected) in samples) {
              final int offset = (y * image.width + image.width ~/ 2) * 4;
              expect(
                [for (int i = 0; i < 4; i++) rgba.getUint8(offset + i)],
                expected,
                reason: 'source band at output y=$y',
              );
            }
          } finally {
            image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        if (outputPath != null) await deleteWatchImage(outputPath);
        await root.delete(recursive: true);
      }
    });
  });
}
