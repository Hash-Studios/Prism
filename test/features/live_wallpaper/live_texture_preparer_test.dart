import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockImageCompress extends Mock implements FlutterImageCompressPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  late _MockCacheManager cache;

  setUp(() {
    cache = _MockCacheManager();
    PrismFullImageCache.testOverride = cache;
  });

  tearDown(() => PrismFullImageCache.testOverride = null);

  test('downloads the wallpaper through the full-size image cache', () async {
    when(() => cache.getSingleFile(any())).thenThrow(Exception('offline'));

    await expectLater(
      const LiveTexturePreparer().prepare('https://example.com/a.jpg', 0.45),
      throwsA(
        isA<LiveTextureException>().having(
          (error) => error.message,
          'message',
          "Couldn't download the wallpaper. Check your connection and try again.",
        ),
      ),
    );
    verify(() => cache.getSingleFile('https://example.com/a.jpg')).called(1);
  });

  testWidgets('decodes and crops a small image before writing compressed bytes', (tester) async {
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('live_texture_test_');
      addTearDown(() => directory.delete(recursive: true));
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      final originalCompress = FlutterImageCompressPlatform.instance;
      addTearDown(() {
        FlutterImageCompressPlatform.instance = originalCompress;
        messenger.setMockMethodCallHandler(paths, null);
      });
      messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawPaint(ui.Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 4);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      image.dispose();
      picture.dispose();
      final source = await IOFileSystem('test_source').createFile('source.png');
      await source.writeAsBytes(data.buffer.asUint8List());
      when(() => cache.getSingleFile(any())).thenAnswer((_) async => source);
      final compressed = Uint8List.fromList(<int>[255, 216, 255, 217]);
      final compress = _MockImageCompress();
      FlutterImageCompressPlatform.instance = compress;
      when(() => compress.compressWithList(any(), minWidth: 2, minHeight: 4, quality: 90)).thenAnswer((call) async {
        final codec = await ui.instantiateImageCodec(call.positionalArguments.first as Uint8List);
        final cropped = (await codec.getNextFrame()).image;
        expect((cropped.width, cropped.height), (2, 4));
        cropped.dispose();
        codec.dispose();
        return compressed;
      });

      final path = await const LiveTexturePreparer().prepare('https://example.com/a.png', 0.5);

      expect(path, '${directory.path}/live_wallpaper_texture.jpg');
      expect(await File(path).readAsBytes(), compressed);
    });
  });
}
