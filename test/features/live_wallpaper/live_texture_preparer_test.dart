import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:flutter/services.dart';
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

  test('reports an empty source as a typed texture download failure', () async {
    final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    fixture.install();
    addTearDown(fixture.dispose);

    await expectLater(
      const LiveTexturePreparer().prepare('', 0.5),
      throwsA(
        isA<LiveTextureException>().having((error) => error.failure, 'failure', LiveApplyFailure.textureDownloadFailed),
      ),
    );
  });

  testWidgets('prepares bundled photo and depth assets through the normal crop and compression pipeline', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
      fixture.install();
      addTearDown(fixture.dispose);
      final Uint8List photoBytes = await _splitPng(width: 8, height: 4, whiteWidth: 4);
      final Uint8List depthBytes = await _splitPng(width: 16, height: 8, whiteWidth: 8);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
        ByteData? message,
      ) async {
        final String assetName = String.fromCharCodes(message!.buffer.asUint8List());
        final Uint8List? bytes = switch (assetName) {
          'assets/live-wallpaper.png' => photoBytes,
          'assets/live-depth.png' => depthBytes,
          _ => null,
        };
        return bytes == null ? null : ByteData.sublistView(bytes);
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        ),
      );
      final Uint8List compressed = Uint8List.fromList(<int>[255, 216, 255, 217]);
      final FlutterImageCompressPlatform originalCompress = FlutterImageCompressPlatform.instance;
      final compress = _MockImageCompress();
      FlutterImageCompressPlatform.instance = compress;
      addTearDown(() => FlutterImageCompressPlatform.instance = originalCompress);
      final List<Uint8List> preparedPngs = <Uint8List>[];
      when(() => compress.compressWithList(any(), minWidth: 2, minHeight: 4, quality: 90)).thenAnswer((call) async {
        preparedPngs.add(Uint8List.fromList(call.positionalArguments.first as Uint8List));
        return compressed;
      });

      final ({String photo, String depth}) paths = await const LiveTexturePreparer().prepareWithDepth(
        'assets/live-wallpaper.png',
        'assets/live-depth.png',
        0.5,
      );

      expect(paths.photo, '${fixture.directory.path}/live_wallpaper_texture.jpg');
      expect(paths.depth, '${fixture.directory.path}/live_wallpaper_depth.jpg');
      expect(await File(paths.photo).readAsBytes(), compressed);
      expect(await File(paths.depth).readAsBytes(), compressed);
      expect(preparedPngs, hasLength(2));
      for (final Uint8List png in preparedPngs) {
        final ui.Image prepared = await _decode(png);
        expect((prepared.width, prepared.height), (2, 4));
        expect(await _redAt(prepared, 0.1), 255);
        expect(await _redAt(prepared, 0.75), 0);
        prepared.dispose();
      }
      verifyNever(() => fixture.cacheManager.getSingleFile(any()));
    });
  });

  testWidgets('prepares local photo paths and file URIs without using the network cache', (tester) async {
    await tester.runAsync(() async {
      for (final bool usePhotoUri in <bool>[false, true]) {
        final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
        fixture.install();
        addTearDown(fixture.dispose);
        final File photo = await fixture.createImage('photo #1.png');
        await photo.writeAsBytes(await _splitPng(width: 8, height: 4, whiteWidth: 4));
        final File depth = await fixture.createImage('depth #1.png');
        await depth.writeAsBytes(await _splitPng(width: 16, height: 8, whiteWidth: 8));
        expect(photo.uri.toString(), contains('%20'));
        expect(photo.uri.toString(), contains('%23'));
        expect(depth.uri.toString(), contains('%20'));
        expect(depth.uri.toString(), contains('%23'));
        final FlutterImageCompressPlatform originalCompress = FlutterImageCompressPlatform.instance;
        final compress = _MockImageCompress();
        FlutterImageCompressPlatform.instance = compress;
        addTearDown(() => FlutterImageCompressPlatform.instance = originalCompress);
        final Uint8List compressed = Uint8List.fromList(<int>[255, 216, 255, 217]);
        final List<Uint8List> preparedPngs = <Uint8List>[];
        when(() => compress.compressWithList(any(), minWidth: 2, minHeight: 4, quality: 90)).thenAnswer((call) async {
          preparedPngs.add(Uint8List.fromList(call.positionalArguments.first as Uint8List));
          return compressed;
        });

        final ({String photo, String depth}) paths = await const LiveTexturePreparer().prepareWithDepth(
          usePhotoUri ? photo.uri.toString() : photo.path,
          depth.uri.toString(),
          0.5,
        );

        expect(paths.photo, '${fixture.directory.path}/live_wallpaper_texture.jpg');
        expect(paths.depth, '${fixture.directory.path}/live_wallpaper_depth.jpg');
        expect(await File(paths.photo).readAsBytes(), compressed);
        expect(await File(paths.depth).readAsBytes(), compressed);
        expect(preparedPngs, hasLength(2));
        for (final Uint8List png in preparedPngs) {
          final ui.Image prepared = await _decode(png);
          expect((prepared.width, prepared.height), (2, 4));
          expect(await _redAt(prepared, 0.1), 255);
          expect(await _redAt(prepared, 0.75), 0);
          prepared.dispose();
        }
        verifyNever(() => fixture.cacheManager.getSingleFile(any()));
      }
    });
  });

  test('reports an undecodable photo as a preparation failure', () async {
    final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    fixture.install(immediateResolver: true);
    addTearDown(fixture.dispose);
    final File source = await fixture.createImage('broken.png');
    await source.writeAsBytes(Uint8List.fromList(<int>[1, 2, 3]));
    fixture.mapSource('https://example.com/broken.png', source);

    await expectLater(
      const LiveTexturePreparer().prepare('https://example.com/broken.png', 0.5),
      throwsA(
        isA<LiveTextureException>().having(
          (error) => error.failure,
          'failure',
          LiveApplyFailure.texturePreparationFailed,
        ),
      ),
    );
  });

  test('reports an undecodable depth map as a preparation failure', () async {
    final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
    fixture.install(immediateResolver: true);
    addTearDown(fixture.dispose);
    final File photo = await fixture.createImage('photo.png');
    await photo.writeAsBytes(await _splitPng(width: 8, height: 4, whiteWidth: 4));
    fixture.mapSource('https://example.com/photo.png', photo);
    final File depth = await fixture.createImage('broken-depth.png');
    await depth.writeAsBytes(Uint8List.fromList(<int>[1, 2, 3]));
    fixture.mapSource('https://example.com/broken-depth.png', depth);
    final FlutterImageCompressPlatform originalCompress = FlutterImageCompressPlatform.instance;
    final compress = _MockImageCompress();
    FlutterImageCompressPlatform.instance = compress;
    addTearDown(() => FlutterImageCompressPlatform.instance = originalCompress);
    when(() => compress.compressWithList(any(), minWidth: 2, minHeight: 4, quality: 90)).thenAnswer((_) async {
      return Uint8List.fromList(<int>[255, 216, 255, 217]);
    });

    await expectLater(
      const LiveTexturePreparer().prepareWithDepth(
        'https://example.com/photo.png',
        'https://example.com/broken-depth.png',
        0.5,
      ),
      throwsA(
        isA<LiveTextureException>().having(
          (error) => error.failure,
          'failure',
          LiveApplyFailure.texturePreparationFailed,
        ),
      ),
    );
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

  testWidgets('crops the decoded image with its actual rounded Y scale', (tester) async {
    await tester.runAsync(() async {
      const int sourceWidth = 1201;
      const int sourceHeight = 5000;
      const double aspect = 0.5;
      final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
      fixture.install(immediateResolver: true);
      addTearDown(fixture.dispose);
      final File source = await fixture.createImage('odd-dimensions.png');
      await source.writeAsBytes(await _horizontalEdgePng(width: sourceWidth, height: sourceHeight, edgeY: 1299.5));
      fixture.mapSource('https://example.com/odd-dimensions.png', source);

      final Uint8List compressed = Uint8List.fromList(<int>[255, 216, 255, 217]);
      final compress = _MockImageCompress();
      final FlutterImageCompressPlatform originalCompress = FlutterImageCompressPlatform.instance;
      FlutterImageCompressPlatform.instance = compress;
      addTearDown(() => FlutterImageCompressPlatform.instance = originalCompress);
      Uint8List? preparedPng;
      when(() => compress.compressWithList(any(), minWidth: 1200, minHeight: 2400, quality: 90)).thenAnswer((
        call,
      ) async {
        preparedPng = Uint8List.fromList(call.positionalArguments.first as Uint8List);
        return compressed;
      });

      await const LiveTexturePreparer().prepare('https://example.com/odd-dimensions.png', aspect);

      final ui.Image actual = await _decode(preparedPng!);
      final ByteData actualPixel = (await actual.toByteData())!;
      expect(actualPixel.getUint8(600 * 4), 127);
      actual.dispose();
    });
  });

  testWidgets('the photo and its depth map keep the same crop', (tester) async {
    await tester.runAsync(() async {
      final OfflineAssetFixture fixture = await OfflineAssetFixture.create(cacheMissByDefault: true);
      fixture.install(immediateResolver: true);
      addTearDown(fixture.dispose);
      final originalCompress = FlutterImageCompressPlatform.instance;
      addTearDown(() => FlutterImageCompressPlatform.instance = originalCompress);
      final File photo = await fixture.createImage('photo.png');
      await photo.writeAsBytes(await _splitPng(width: 300, height: 200, whiteWidth: 120));
      fixture.mapSource('https://example.com/photo.png', photo);
      final File depth = await fixture.createImage('depth.png');
      await depth.writeAsBytes(await _splitPng(width: 150, height: 100, whiteWidth: 60));
      fixture.mapSource('https://example.com/depth.png', depth);
      final compressed = Uint8List.fromList(<int>[255, 216, 255, 217]);
      final List<Uint8List> compressInputs = <Uint8List>[];
      final compress = _MockImageCompress();
      FlutterImageCompressPlatform.instance = compress;
      when(() => compress.compressWithList(any(), minWidth: 100, minHeight: 200, quality: 90)).thenAnswer((call) async {
        compressInputs.add(call.positionalArguments.first as Uint8List);
        return compressed;
      });
      when(() => compress.compressWithList(any(), minWidth: 50, minHeight: 100, quality: 90)).thenAnswer((call) async {
        compressInputs.add(call.positionalArguments.first as Uint8List);
        return compressed;
      });

      final ({String photo, String depth}) paths = await const LiveTexturePreparer().prepareWithDepth(
        'https://example.com/photo.png',
        'https://example.com/depth.png',
        0.5,
      );

      expect(paths.photo, isNot(paths.depth));
      expect(compressInputs, hasLength(2));
      final ui.Image photoImage = await _decode(compressInputs[0]);
      final ui.Image depthImage = await _decode(compressInputs[1]);
      expect((photoImage.width, photoImage.height), (100, 200));
      expect((depthImage.width, depthImage.height), (50, 100));
      expect(await _redAt(photoImage, 0.1), 255);
      expect(await _redAt(photoImage, 0.3), 0);
      expect(await _redAt(depthImage, 0.1), 255);
      expect(await _redAt(depthImage, 0.3), 0);
    });
  });
}

Future<Uint8List> _horizontalEdgePng({required int width, required int height, required double edgeY}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawPaint(ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.drawRect(
    ui.Rect.fromLTWH(0, edgeY, width.toDouble(), height - edgeY),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  picture.dispose();
  return data.buffer.asUint8List();
}

Future<Uint8List> _splitPng({required int width, required int height, required int whiteWidth}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, whiteWidth.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  picture.dispose();
  return data.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  codec.dispose();
  return image;
}

Future<int> _redAt(ui.Image image, double normalizedX) async {
  final ByteData rgba = (await image.toByteData())!;
  final int x = (normalizedX * image.width).floor();
  return rgba.getUint8(((image.height ~/ 2) * image.width + x) * 4);
}
