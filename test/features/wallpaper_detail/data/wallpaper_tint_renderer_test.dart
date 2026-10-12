import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
// ignore: depend_on_referenced_packages
import 'package:file/local.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

const Color _green = Color(0xFF00FF00);
const Color _magenta = Color(0xFFFF00FF);

Future<ui.Image> _redAndBlue() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(1, 0, 1, 1), Paint()..color = const Color(0xFF0000FF));
  return rasterizePicture(recorder.endRecording(), 2, 1);
}

Future<Uint8List> _redAndBluePng() async {
  final ui.Image image = await _redAndBlue();
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<List<Color>> _pixels(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    try {
      final ByteData data = (await image.toByteData())!;
      return <Color>[
        for (int x = 0; x < image.width; x++)
          Color.fromARGB(
            data.getUint8(x * 4 + 3),
            data.getUint8(x * 4),
            data.getUint8(x * 4 + 1),
            data.getUint8(x * 4 + 2),
          ),
      ];
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

double _hue(Color color) => HSVColor.fromColor(color).hue;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a green tint turns red and blue pixels green and keeps the brighter one brighter', (tester) async {
    await tester.runAsync(() async {
      final ui.Image source = await _redAndBlue();
      final List<Color> pixels;
      try {
        pixels = await _pixels(await renderTintedPng(source, _green));
      } finally {
        source.dispose();
      }

      final Color fromRed = pixels[0];
      final Color fromBlue = pixels[1];
      expect(_hue(fromRed), closeTo(120, 10));
      expect(_hue(fromBlue), closeTo(120, 10));
      expect(fromRed.a, 1.0);
      expect(fromBlue.a, 1.0);
      expect(fromRed.g, greaterThan(fromBlue.g + 20 / 255));
    });
  });

  group('renderTintedWallpaper', () {
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory directory;
    late File source;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('tint_renderer_test_');
      source = File('${directory.path}/wall.png');
      messenger.setMockMethodCallHandler(pathChannel, (_) async => directory.path);
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      PrismFullImageCache.testOverride = null;
      directory.deleteSync(recursive: true);
    });

    testWidgets('writes the tinted PNG under prism_tint', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());

        final String path = await renderTintedWallpaper(source: source.path, tint: _green);

        expect(File(path).parent.path, '${directory.path}/prism_tint');
        final List<Color> pixels = await _pixels(await File(path).readAsBytes());
        expect(pixels.map(_hue), everyElement(closeTo(120, 10)));
      });
    });

    testWidgets('the same source and tint reuse the file, another tint makes a new one', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());

        final String first = await renderTintedWallpaper(source: source.path, tint: _green);
        final String again = await renderTintedWallpaper(source: source.path, tint: _green);
        final String other = await renderTintedWallpaper(source: source.path, tint: _magenta);

        expect(again, first);
        expect(other, isNot(first));
        expect(Directory('${directory.path}/prism_tint').listSync(), hasLength(2));
      });
    });

    testWidgets('two calls at once render once', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());

        final List<String> paths = await Future.wait(<Future<String>>[
          renderTintedWallpaper(source: source.path, tint: _green),
          renderTintedWallpaper(source: source.path, tint: _green),
        ]);

        expect(paths[1], paths[0]);
        expect(Directory('${directory.path}/prism_tint').listSync(), hasLength(1));
      });
    });

    testWidgets('renders again when the earlier file is gone', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final String first = await renderTintedWallpaper(source: source.path, tint: _green);
        File(first).deleteSync();

        final String again = await renderTintedWallpaper(source: source.path, tint: _green);

        expect(again, isNot(first));
        expect(File(again).existsSync(), isTrue);
      });
    });

    testWidgets('a failure throws and is not remembered', (tester) async {
      await tester.runAsync(() async {
        await expectLater(
          renderTintedWallpaper(source: source.path, tint: _green),
          throwsA(isA<FileSystemException>()),
        );

        source.writeAsBytesSync(await _redAndBluePng());
        final String path = await renderTintedWallpaper(source: source.path, tint: _green);

        expect(File(path).existsSync(), isTrue);
      });
    });

    testWidgets('a URL loads through the full image cache and is fetched once per tint', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final _MockCacheManager cache = _MockCacheManager();
        when(() => cache.getSingleFile(any())).thenAnswer((_) async => const LocalFileSystem().file(source.path));
        PrismFullImageCache.testOverride = cache;

        final String first = await renderTintedWallpaper(source: 'https://img.test/wall.png', tint: _green);
        final String again = await renderTintedWallpaper(source: 'https://img.test/wall.png', tint: _green);

        expect(again, first);
        verify(() => cache.getSingleFile('https://img.test/wall.png')).called(1);
        final List<Color> pixels = await _pixels(await File(first).readAsBytes());
        expect(pixels.map(_hue), everyElement(closeTo(120, 10)));
      });
    });
  });
}
