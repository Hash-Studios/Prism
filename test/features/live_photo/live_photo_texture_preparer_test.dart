import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/offline_asset_fixture.dart';

class _MockImageCompress extends Mock implements FlutterImageCompressPlatform {}

class _MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  Future<OfflineAssetFixture> fixtureWithPhoto() async {
    final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    fixture.install(immediateResolver: true);
    addTearDown(fixture.dispose);
    final File photo = await fixture.createImage('photo.png');
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawPaint(ui.Paint());
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(8, 4);
    final ByteData png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await photo.writeAsBytes(png.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    fixture.mapSource('https://example.com/photo.png', photo);
    final FlutterImageCompressPlatform original = FlutterImageCompressPlatform.instance;
    addTearDown(() => FlutterImageCompressPlatform.instance = original);
    final _MockImageCompress compress = _MockImageCompress();
    FlutterImageCompressPlatform.instance = compress;
    when(
      () => compress.compressWithList(any(), minWidth: 2, minHeight: 4, quality: 90),
    ).thenAnswer((_) async => Uint8List.fromList(<int>[255, 216, 255, 217]));
    return fixture;
  }

  testWidgets('overlapping Live Photo preparations own different texture files', (tester) async {
    await tester.runAsync(() async {
      await fixtureWithPhoto();
      const LiveTexturePreparer preparer = LiveTexturePreparer();
      final List<String> paths = await Future.wait(<Future<String>>[
        preparer.prepare('https://example.com/photo.png', 0.5, uniquePaths: true),
        preparer.prepare('https://example.com/photo.png', 0.5, uniquePaths: true),
      ]);

      expect(paths[0], isNot(paths[1]));
      expect(await File(paths[0]).exists(), isTrue);
      await File(paths[0]).delete();
      expect(await File(paths[1]).exists(), isTrue);
    });
  });

  testWidgets('a failed texture write deletes its partial JPEG', (tester) async {
    await tester.runAsync(() async {
      await fixtureWithPhoto();
      final _MockFile target = _MockFile();
      when(() => target.writeAsBytes(any(), flush: true)).thenThrow(const FileSystemException('disk full'));
      when(() => target.delete()).thenAnswer((_) async => target);

      await expectLater(
        IOOverrides.runZoned(
          () => const LiveTexturePreparer().prepare('https://example.com/photo.png', 0.5, uniquePaths: true),
          createFile: (_) => target,
        ),
        throwsA(isA<LiveTextureException>()),
      );
      verify(() => target.delete()).called(1);
    });
  });

  testWidgets('a failed depth preparation removes its already prepared photo', (tester) async {
    await tester.runAsync(() async {
      final OfflineAssetFixture fixture = await fixtureWithPhoto();
      final File depth = await fixture.createImage('broken-depth.png');
      await depth.writeAsBytes(<int>[1, 2, 3]);
      fixture.mapSource('https://example.com/depth.png', depth);

      await expectLater(
        const LiveTexturePreparer().prepareWithDepth(
          'https://example.com/photo.png',
          'https://example.com/depth.png',
          0.5,
          uniquePaths: true,
        ),
        throwsA(isA<LiveTextureException>()),
      );
      expect(fixture.directory.listSync().where((entry) => entry.path.contains('live_wallpaper_texture')), isEmpty);
    });
  });
}
