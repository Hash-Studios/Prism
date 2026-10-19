import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/offline_asset_fixture.dart';

class _MockImageCompress extends Mock implements FlutterImageCompressPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  test('downloads the wallpaper through the full-size image cache', () async {
    final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    fixture.install();
    addTearDown(fixture.dispose);

    await expectLater(
      const LiveTexturePreparer().prepare('https://example.com/a.jpg', 0.45),
      throwsA(
        isA<LiveTextureException>().having((error) => error.failure, 'failure', LiveApplyFailure.textureDownloadFailed),
      ),
    );
    verify(() => fixture.cacheManager.getSingleFile('https://example.com/a.jpg')).called(1);
  });

  testWidgets('decodes and crops a small image before writing compressed bytes', (tester) async {
    await tester.runAsync(() async {
      final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
      fixture.install(immediateResolver: true);
      addTearDown(fixture.dispose);
      final originalCompress = FlutterImageCompressPlatform.instance;
      addTearDown(() => FlutterImageCompressPlatform.instance = originalCompress);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawPaint(ui.Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 4);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      image.dispose();
      picture.dispose();
      final File source = await fixture.createImage('source.png');
      await source.writeAsBytes(data.buffer.asUint8List());
      fixture.mapSource('https://example.com/a.png', source);
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

      final String path = await const LiveTexturePreparer().prepare('https://example.com/a.png', 0.5);

      expect(path, '${fixture.directory.path}/live_wallpaper_texture.jpg');
      expect(await File(path).readAsBytes(), compressed);
    });
  });
}
