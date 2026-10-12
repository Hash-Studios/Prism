import 'dart:async';
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

class _PartialWriteFile extends Fake implements File {
  _PartialWriteFile(this._real);

  final File _real;

  @override
  String get path => _real.path;

  @override
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async {
    await _real.writeAsBytes(<int>[1, 2, 3]);
    throw const FileSystemException('No space left on device');
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) => _real.delete(recursive: recursive);
}

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

Future<Uint8List> _solidPng(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF3366CC));
  final ui.Image image = await rasterizePicture(recorder.endRecording(), width, height);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<({int width, int height})> _sizeOf(Uint8List png) async {
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

Color _tint(int index) => Color(0xFF000000 | (index * 0x2A0B13 & 0xFFFFFF));

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

    setUp(() async {
      directory = Directory.systemTemp.createTempSync('tint_renderer_test_');
      source = File('${directory.path}/wall.png');
      messenger.setMockMethodCallHandler(pathChannel, (_) async => directory.path);
      await clearTintedWallpapers();
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

    testWidgets('the first render of a run deletes files an earlier run left and later renders keep theirs', (
      tester,
    ) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final File stale = File('${directory.path}/prism_tint/stale.png')..createSync(recursive: true);
        stale.writeAsBytesSync(<int>[1, 2, 3]);

        final String first = await renderTintedWallpaper(source: source.path, tint: _green);

        expect(stale.existsSync(), isFalse);
        expect(File(first).existsSync(), isTrue);

        final String second = await renderTintedWallpaper(source: source.path, tint: _magenta);

        expect(File(first).existsSync(), isTrue);
        expect(File(second).existsSync(), isTrue);
      });
    });

    testWidgets('keeps the last 6 renders and deletes the file of the oldest when a 7th is made', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final List<String> paths = <String>[];
        for (int i = 0; i < 7; i++) {
          paths.add(await renderTintedWallpaper(source: source.path, tint: _tint(i)));
        }

        expect(File(paths[0]).existsSync(), isFalse);
        expect(paths.skip(1).map((String path) => File(path).existsSync()), everyElement(isTrue));
        expect(Directory('${directory.path}/prism_tint').listSync(), hasLength(6));
      });
    });

    testWidgets('a render used again is kept past newer ones and the least recent one goes', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final List<String> paths = <String>[
          for (int i = 0; i < 6; i++) await renderTintedWallpaper(source: source.path, tint: _tint(i)),
        ];

        final String again = await renderTintedWallpaper(source: source.path, tint: _tint(0));
        await renderTintedWallpaper(source: source.path, tint: _tint(6));

        expect(again, paths[0]);
        expect(File(paths[0]).existsSync(), isTrue);
        expect(File(paths[1]).existsSync(), isFalse);
        expect(File(paths[2]).existsSync(), isTrue);
      });
    });

    testWidgets('an evicted tint renders again into a new file', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final String first = await renderTintedWallpaper(source: source.path, tint: _tint(0));
        for (int i = 1; i < 7; i++) {
          await renderTintedWallpaper(source: source.path, tint: _tint(i));
        }

        final String again = await renderTintedWallpaper(source: source.path, tint: _tint(0));

        expect(again, isNot(first));
        expect(File(again).existsSync(), isTrue);
      });
    });

    testWidgets('clearTintedWallpapers deletes the files and the next render makes a new one', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final String first = await renderTintedWallpaper(source: source.path, tint: _green);

        await clearTintedWallpapers();

        expect(File(first).existsSync(), isFalse);
        expect(Directory('${directory.path}/prism_tint').existsSync(), isFalse);
        final String again = await renderTintedWallpaper(source: source.path, tint: _green);
        expect(File(again).existsSync(), isTrue);
      });
    });

    testWidgets('a write that fails leaves no partial file and the next render works', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final Zone realIo = Zone.current;

        await IOOverrides.runZoned(
          () async {
            await expectLater(
              renderTintedWallpaper(source: source.path, tint: _green),
              throwsA(isA<FileSystemException>()),
            );
          },
          createFile: (String path) {
            final File real = realIo.run(() => File(path));
            return path.contains('/prism_tint/') ? _PartialWriteFile(real) : real;
          },
        );

        expect(Directory('${directory.path}/prism_tint').listSync(), isEmpty);
        final String path = await renderTintedWallpaper(source: source.path, tint: _green);
        expect(File(path).existsSync(), isTrue);
      });
    });

    testWidgets('a source above the cap is decoded at the capped size', (tester) async {
      await tester.runAsync(() async {
        final Uint8List wide = await _solidPng(5000, 2);

        final ui.Image capped = await decodeForTint(wide);
        final ui.Image roomy = await decodeForTint(wide, deviceLongSidePx: 6000);

        expect((width: capped.width, height: capped.height), (width: 4096, height: 2));
        expect((width: roomy.width, height: roomy.height), (width: 5000, height: 2));
        capped.dispose();
        roomy.dispose();
      });
    });

    testWidgets('a source above the cap is written at the capped size', (tester) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _solidPng(5000, 2));

        final String path = await renderTintedWallpaper(source: source.path, tint: _green);

        expect(await _sizeOf(await File(path).readAsBytes()), (width: 4096, height: 2));
      });
    });

    testWidgets('two tints render one after the other, the second source is not fetched before the first is done', (
      tester,
    ) async {
      await tester.runAsync(() async {
        source.writeAsBytesSync(await _redAndBluePng());
        final _MockCacheManager cache = _MockCacheManager();
        final Completer<void> firstFetched = Completer<void>();
        when(() => cache.getSingleFile(any())).thenAnswer((Invocation call) async {
          if (call.positionalArguments.single == 'https://img.test/a.png') await firstFetched.future;
          return const LocalFileSystem().file(source.path);
        });
        PrismFullImageCache.testOverride = cache;

        final Future<String> first = renderTintedWallpaper(source: 'https://img.test/a.png', tint: _green);
        final Future<String> second = renderTintedWallpaper(source: 'https://img.test/b.png', tint: _magenta);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(() => cache.getSingleFile('https://img.test/a.png')).called(1);
        verifyNever(() => cache.getSingleFile('https://img.test/b.png'));

        firstFetched.complete();
        await Future.wait(<Future<String>>[first, second]);

        verify(() => cache.getSingleFile('https://img.test/b.png')).called(1);
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
