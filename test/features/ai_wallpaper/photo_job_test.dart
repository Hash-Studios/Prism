import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

const PhotoSize _phone = PhotoSize(1080, 2340);

const Map<String, Object?> _successMap = <String, Object?>{
  'jobId': 'pj_2',
  'state': 'succeeded',
  'imageUrl': 'https://x/a.jpg',
  'width': 1080,
  'height': 2340,
  'watermarked': false,
};

PhotoJob _job({required PhotoJobMode mode, PhotoJobTarget target = PhotoJobTarget.phone}) => PhotoJob(
  source: PhotoSource(bytes: Uint8List(4), size: const PhotoSize(4000, 3000)),
  mode: mode,
  target: target,
  cost: mode == PhotoJobMode.extend ? 75 : 10,
);

void main() {
  for (final PhotoSize size in <PhotoSize>[const PhotoSize(4096, 300), const PhotoSize(300, 4096)]) {
    test('picking a real $size PNG preserves exact dimensions for the panorama upload bound', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const ui.Color(0xFF000000), ui.BlendMode.src);
      final ui.Picture picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final ui.Image image = await picture.toImage(size.width, size.height);
      addTearDown(image.dispose);
      final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = png!.buffer.asUint8List();
      final List<int> sides = <int>[];
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(() async => bytes, null, (
        Uint8List bytes,
        int side,
      ) async {
        sides.add(side);
        return Uint8List.fromList(<int>[1, 2, 3]);
      }, (Map<String, Object?> payload) async => _successMap);

      final PhotoSource? source = await repo.pick();
      expect(source?.size, size);
      await repo.run(
        PhotoJob(source: source!, mode: PhotoJobMode.extend, target: PhotoJobTarget.desktop, cost: 75),
        requestId: 'req-real-panorama',
        targetSize: photoDesktopSize,
      );
      expect(sides, <int>[3496]);
    });
  }

  test('picker cache copies are removed after reading, but paths outside temp are not', () async {
    final Directory temp = await Directory.systemTemp.createTemp('photo-wallpaper-');
    addTearDown(() => temp.delete(recursive: true));
    final File cachedCopy = File(p.join(temp.path, 'picked.jpg'))..writeAsBytesSync(<int>[1, 2, 3]);

    expect(await readAndCleanupPickedPhoto(XFile(cachedCopy.path), temporaryDirectory: temp), <int>[1, 2, 3]);
    expect(await cachedCopy.exists(), isFalse);

    final File outside = File(p.join(temp.parent.path, 'outside-photo-${temp.hashCode}.jpg'))
      ..writeAsBytesSync(<int>[4, 5, 6]);
    addTearDown(() => outside.delete());
    await readAndCleanupPickedPhoto(XFile(outside.path), temporaryDirectory: temp);
    expect(await outside.exists(), isTrue);

    final Link link = Link(p.join(temp.path, 'outside-link.jpg'))..createSync(outside.path);
    addTearDown(() => link.delete());
    await readAndCleanupPickedPhoto(XFile(link.path), temporaryDirectory: temp);
    expect(await outside.exists(), isTrue);
  });

  test('a failed picker cleanup still returns the photo it read', () async {
    final Directory temp = await Directory.systemTemp.createTemp('photo-wallpaper-');
    addTearDown(() => temp.delete(recursive: true));
    final File cachedCopy = File(p.join(temp.path, 'picked.jpg'))..writeAsBytesSync(<int>[1, 2, 3]);
    final Directory missing = Directory(p.join(temp.path, 'gone'));

    expect(await readAndCleanupPickedPhoto(XFile(cachedCopy.path), temporaryDirectory: missing), <int>[1, 2, 3]);
  });

  test('picker cleanup resolves a temporary directory alias before checking containment', () async {
    final Directory fixture = await Directory.systemTemp.createTemp('photo-wallpaper-alias-');
    addTearDown(() => fixture.delete(recursive: true));
    final Directory temp = await Directory(p.join(fixture.path, 'cache')).create();
    final Link alias = await Link(p.join(fixture.path, 'cache-alias')).create(temp.path);
    final File cachedCopy = File(p.join(temp.path, 'picked.jpg'))..writeAsBytesSync(<int>[1, 2, 3]);

    expect(await readAndCleanupPickedPhoto(XFile(cachedCopy.path), temporaryDirectory: Directory(alias.path)), <int>[
      1,
      2,
      3,
    ]);
    expect(await cachedCopy.exists(), isFalse);
    expect(await alias.exists(), isTrue);
  });

  test('picker cleanup preserves a source outside temp reached through a directory link', () async {
    final Directory fixture = await Directory.systemTemp.createTemp('photo-wallpaper-outside-');
    addTearDown(() => fixture.delete(recursive: true));
    final Directory temp = await Directory(p.join(fixture.path, 'cache')).create();
    final Directory outside = await Directory(p.join(fixture.path, 'source')).create();
    final File source = File(p.join(outside.path, 'picked.jpg'))..writeAsBytesSync(<int>[4, 5, 6]);
    final Link alias = await Link(p.join(temp.path, 'source-alias')).create(outside.path);

    expect(await readAndCleanupPickedPhoto(XFile(p.join(alias.path, 'picked.jpg')), temporaryDirectory: temp), <int>[
      4,
      5,
      6,
    ]);
    expect(await source.exists(), isTrue);
    expect(await alias.exists(), isTrue);
  });

  group('planPhotoJob', () {
    test('wide landscape photo needs Extend on the phone target', () {
      expect(planPhotoJob(const PhotoSize(4000, 3000), _phone), PhotoJobMode.extend);
    });

    test('3:4 portrait photo needs Extend on the phone target', () {
      expect(planPhotoJob(const PhotoSize(3000, 4000), _phone), PhotoJobMode.extend);
    });

    test('small phone-shaped photo needs Upscale', () {
      expect(planPhotoJob(const PhotoSize(540, 1170), _phone), PhotoJobMode.upscale);
    });

    test('exact phone size fits, so no job', () {
      expect(planPhotoJob(const PhotoSize(1080, 2340), _phone), isNull);
    });

    test('larger phone-shaped photo fits, so no job', () {
      expect(planPhotoJob(const PhotoSize(1290, 2796), _phone), isNull);
    });

    test('small landscape photo needs Upscale on the desktop target', () {
      expect(planPhotoJob(const PhotoSize(1280, 800), photoDesktopSize), PhotoJobMode.upscale);
    });

    test('large 16:10 photo fits the desktop target, so no job', () {
      expect(planPhotoJob(const PhotoSize(3840, 2400), photoDesktopSize), isNull);
    });

    test('portrait photo needs Extend on the desktop target', () {
      expect(planPhotoJob(const PhotoSize(1200, 1600), photoDesktopSize), PhotoJobMode.extend);
    });

    test('shape 4% off the target is inside the 5% tolerance, so no Extend', () {
      // 1080x2250 is 0.48; the target is 0.4615. The ratio is 1.04.
      expect(planPhotoJob(const PhotoSize(1080, 2250), _phone), isNull);
    });
  });

  group('phoneTargetSize', () {
    test('keeps a portrait phone size as it is', () {
      expect(phoneTargetSize(width: 1179, height: 2556), const PhotoSize(1179, 2556));
    });

    test('turns a landscape input into portrait', () {
      expect(phoneTargetSize(width: 2556, height: 1179), const PhotoSize(1179, 2556));
    });

    test('clamps the width to 720 and floors the height', () {
      expect(phoneTargetSize(width: 600, height: 1300), const PhotoSize(720, 1560));
    });

    test('never drops below the 1.6 ratio the server accepts when the width is not a multiple of 5', () {
      expect(phoneTargetSize(width: 723, height: 1000), const PhotoSize(723, 1157));
      expect(1157 / 723, greaterThanOrEqualTo(1.6));
    });

    test('clamps the ratio to 2.4', () {
      expect(phoneTargetSize(width: 1440, height: 4000), const PhotoSize(1440, 3456));
    });
  });

  group('photoJobCost', () {
    test('Extend costs 75 coins for a free user', () {
      expect(photoJobCost(PhotoJobMode.extend, isPro: false, config: EconomyConfig.defaults), 75);
    });

    test('Extend costs 38 coins for Pro', () {
      expect(photoJobCost(PhotoJobMode.extend, isPro: true, config: EconomyConfig.defaults), 38);
    });

    test('Upscale costs 10 coins for a free user', () {
      expect(photoJobCost(PhotoJobMode.upscale, isPro: false, config: EconomyConfig.defaults), 10);
    });

    test('Upscale costs 5 coins for Pro', () {
      expect(photoJobCost(PhotoJobMode.upscale, isPro: true, config: EconomyConfig.defaults), 5);
    });

    test('Pro pays full price when the config has no photoWallpaper discount', () {
      const EconomyConfig config = EconomyConfig(proDiscountActions: <String>['aiGeneration']);
      expect(photoJobCost(PhotoJobMode.extend, isPro: true, config: config), 75);
    });

    test('photo prices and discount action use the server defaults for malformed remote values', () {
      final EconomyConfig config = EconomyConfig.fromMap(<String, Object?>{
        'spend': <String, Object?>{'photoExtend': 99.5, 'photoUpscale': 12.5},
        'proDiscountActions': <Object?>['aiGeneration', 7],
      });
      expect(config.spend.photoExtend, 75);
      expect(config.spend.photoUpscale, 10);
      expect(config.proDiscountActions, <String>['aiGeneration']);
      expect(photoJobCost(PhotoJobMode.extend, isPro: true, config: config), 75);

      final EconomyConfig decimalPrice = EconomyConfig.fromMap(<String, Object?>{
        'spend': <String, Object?>{'photoExtend': 99.0},
      });
      expect(decimalPrice.spend.photoExtend, 99);
    });

    test('photo discount parsing does not change malformed bypass-list fallback', () {
      final EconomyConfig config = EconomyConfig.fromMap(<String, Object?>{
        'proDiscountActions': <Object?>['aiGeneration', 7],
        'proBypassActions': <Object?>['wallpaperDownload', 7],
      });

      expect(config.proDiscountActions, <String>['aiGeneration']);
      expect(config.proBypassActions, EconomyConfig.defaults.proBypassActions);
    });
  });

  group('PhotoPlacement', () {
    final PhotoPlacement fit = PhotoPlacement.fit(canvas: _phone, photo: const PhotoSize(4000, 3000));

    test('fit centres the photo at full canvas width', () {
      expect(fit.left, 0);
      expect(fit.top, 765);
      expect(fit.width, 1080);
      expect(fit.height, 810);
      expect(fit.scale, 1.0);
      expect(fit.isFit, isTrue);
    });

    test('moving up is clamped to the top edge', () {
      expect(fit.moved(0, -10000).top, 0);
    });

    test('moving down is clamped to the bottom edge', () {
      expect(fit.moved(0, 10000).top, 1530);
    });

    test('scaling below the minimum clamps to 0.6', () {
      final PhotoPlacement small = fit.scaled(0.1);
      expect(small.width, 648);
      expect(small.height, 486);
    });

    test('clamps the minimum size so it still meets the server canvas-share limit', () {
      final PhotoPlacement panoramic = PhotoPlacement.fit(canvas: _phone, photo: const PhotoSize(4096, 1000));
      expect(panoramic.validForServer, isTrue);
      expect(panoramic.scaled(0.1).validForServer, isTrue);
    });

    test('rejects a photo whose largest fitting placement is below the server canvas-share limit', () {
      final PhotoPlacement narrow = PhotoPlacement.fit(canvas: _phone, photo: const PhotoSize(4096, 256));
      expect(narrow.validForServer, isFalse);
    });

    test('scaling above the maximum clamps back to the fit size', () {
      final PhotoPlacement small = fit.scaled(0.1);
      expect(small.scaled(10).width, 1080);
    });

    test('alignedTo the end moves the photo to the bottom', () {
      final PhotoPlacement end = fit.alignedTo(1);
      expect(end.left, 0);
      expect(end.top, 1530);
    });

    test('toJson gives left, top, width and height', () {
      expect(fit.toJson(), <String, int>{'left': 0, 'top': 765, 'width': 1080, 'height': 810});
    });
  });

  group('parsePhotoJobResult', () {
    test('an unrecognized response is an ambiguous network outcome', () {
      final PhotoJobFailed failed = parsePhotoJobResult(<String, Object?>{'state': 'running'}) as PhotoJobFailed;
      expect(failed.reason, PhotoJobFailure.network);
      expect(failed.charged, isFalse);
    });

    test('succeeded map gives a PhotoJobSucceeded', () {
      final PhotoJobState result = parsePhotoJobResult(<String, dynamic>{
        'jobId': 'pj_1',
        'state': 'succeeded',
        'imageUrl': 'https://x/a.jpg',
        'width': 1080,
        'height': 2340,
        'watermarked': true,
      });
      expect(result, isA<PhotoJobSucceeded>());
      final PhotoJobSucceeded ok = result as PhotoJobSucceeded;
      expect(ok.jobId, 'pj_1');
      expect(ok.imageUrl, 'https://x/a.jpg');
      expect(ok.size, const PhotoSize(1080, 2340));
      expect(ok.watermarked, isTrue);
    });

    test('failed map gives a charged and refunded PhotoJobFailed', () {
      final PhotoJobState result = parsePhotoJobResult(<String, dynamic>{
        'state': 'failed',
        'reason': 'unsafe_output',
        'refunded': true,
      });
      expect(result, isA<PhotoJobFailed>());
      final PhotoJobFailed failed = result as PhotoJobFailed;
      expect(failed.reason, PhotoJobFailure.unsafeOutput);
      expect(failed.charged, isTrue);
      expect(failed.refunded, isTrue);
    });

    test('null is an ambiguous network outcome', () {
      final PhotoJobState result = parsePhotoJobResult(null);
      expect(result, isA<PhotoJobFailed>());
      final PhotoJobFailed failed = result as PhotoJobFailed;
      expect(failed.reason, PhotoJobFailure.network);
      expect(failed.charged, isFalse);
    });
  });

  group('photoJobFailureFor', () {
    void expectRefusal(String code, String? message, PhotoJobFailure reason) {
      final PhotoJobFailed failed = photoJobFailureFor(code, message);
      expect(failed.reason, reason, reason: '$code/$message');
      expect(failed.charged, isFalse, reason: '$code/$message');
    }

    test('resource-exhausted with busy is busy', () {
      expectRefusal('resource-exhausted', 'busy', PhotoJobFailure.busy);
    });

    test('resource-exhausted with daily_limit is dailyLimit', () {
      expectRefusal('resource-exhausted', 'daily_limit', PhotoJobFailure.dailyLimit);
    });

    test('failed-precondition with insufficient_coins is insufficientCoins', () {
      expectRefusal('failed-precondition', 'insufficient_coins', PhotoJobFailure.insufficientCoins);
    });

    test('aborted with in_progress is inProgress', () {
      expectRefusal('aborted', 'in_progress', PhotoJobFailure.inProgress);
    });

    test('unauthenticated is signIn', () {
      expectRefusal('unauthenticated', null, PhotoJobFailure.signIn);
    });

    test('invalid-argument is unreadable', () {
      expectRefusal('invalid-argument', 'x', PhotoJobFailure.unreadable);
    });
  });

  group('PhotoWallpaperRepository.run', () {
    test('extend upload preserves the server minimum short side for a supported desktop panorama', () async {
      final List<int> sides = <int>[];
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(null, null, (Uint8List bytes, int side) async {
        sides.add(side);
        return Uint8List.fromList(<int>[1, 2, 3]);
      }, (Map<String, Object?> payload) async => _successMap);

      await repo.run(
        PhotoJob(
          source: PhotoSource(bytes: Uint8List(4), size: const PhotoSize(4096, 300)),
          mode: PhotoJobMode.extend,
          target: PhotoJobTarget.desktop,
          cost: 75,
        ),
        requestId: 'req-panorama',
        targetSize: photoDesktopSize,
      );

      expect(sides, <int>[3496]);
    });

    test('extend job sends the phone target, placement and image, and uploads at side 2560', () async {
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      final List<int> sides = <int>[];
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(
        null,
        null,
        (Uint8List bytes, int side) async {
          sides.add(side);
          return Uint8List.fromList(<int>[1, 2, 3]);
        },
        (Map<String, Object?> payload) async {
          payloads.add(payload);
          return _successMap;
        },
      );

      final PhotoJobState result = await repo.run(
        _job(mode: PhotoJobMode.extend),
        requestId: 'req-00000001',
        targetSize: _phone,
        placement: PhotoPlacement.fit(canvas: _phone, photo: const PhotoSize(4000, 3000)),
      );

      expect(result, isA<PhotoJobSucceeded>());
      expect(sides, <int>[2560]);
      expect(payloads, hasLength(1));
      final Map<String, Object?> payload = payloads.single;
      expect(payload['requestId'], 'req-00000001');
      expect(payload['mode'], 'extend');
      expect(payload['target'], 'phone');
      expect(payload['targetWidth'], 1080);
      expect(payload['targetHeight'], 2340);
      expect(payload['placement'], <String, int>{'left': 0, 'top': 765, 'width': 1080, 'height': 810});
      expect(payload['image'], 'AQID');
    });

    test('upscale job has no placement and uploads at side 4096', () async {
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      final List<int> sides = <int>[];
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(
        null,
        null,
        (Uint8List bytes, int side) async {
          sides.add(side);
          return Uint8List.fromList(<int>[1, 2, 3]);
        },
        (Map<String, Object?> payload) async {
          payloads.add(payload);
          return _successMap;
        },
      );

      await repo.run(
        _job(mode: PhotoJobMode.upscale),
        requestId: 'req-00000002',
        targetSize: _phone,
      );

      expect(sides, <int>[4096]);
      expect(payloads.single.containsKey('placement'), isFalse);
      expect(payloads.single['mode'], 'upscale');
    });

    test('desktop target sends no targetWidth or targetHeight', () async {
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(
        null,
        null,
        (Uint8List bytes, int side) async => Uint8List.fromList(<int>[1, 2, 3]),
        (Map<String, Object?> payload) async {
          payloads.add(payload);
          return _successMap;
        },
      );

      await repo.run(
        _job(mode: PhotoJobMode.extend, target: PhotoJobTarget.desktop),
        requestId: 'req-00000003',
        targetSize: photoDesktopSize,
        placement: PhotoPlacement.fit(canvas: photoDesktopSize, photo: const PhotoSize(4000, 3000)),
      );

      expect(payloads.single['target'], 'desktop');
      expect(payloads.single.containsKey('targetWidth'), isFalse);
      expect(payloads.single.containsKey('targetHeight'), isFalse);
    });

    test('a dropped connection retries once with the same requestId', () async {
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(
        null,
        null,
        (Uint8List bytes, int side) async => Uint8List.fromList(<int>[1, 2, 3]),
        (Map<String, Object?> payload) async {
          payloads.add(payload);
          if (payloads.length == 1) {
            throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'x');
          }
          return _successMap;
        },
      );

      final PhotoJobState result = await repo.run(
        _job(mode: PhotoJobMode.upscale),
        requestId: 'req-00000001',
        targetSize: _phone,
      );

      expect(result, isA<PhotoJobSucceeded>());
      expect(payloads, hasLength(2));
      expect(payloads[0]['requestId'], 'req-00000001');
      expect(payloads[1]['requestId'], 'req-00000001');
    });

    test('a refusal is not retried', () async {
      int calls = 0;
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(
        null,
        null,
        (Uint8List bytes, int side) async => Uint8List.fromList(<int>[1, 2, 3]),
        (Map<String, Object?> payload) {
          calls++;
          throw FirebaseFunctionsException(code: 'resource-exhausted', message: 'daily_limit');
        },
      );

      final PhotoJobState result = await repo.run(
        _job(mode: PhotoJobMode.upscale),
        requestId: 'req-00000001',
        targetSize: _phone,
      );

      expect(calls, 1);
      expect(result, isA<PhotoJobFailed>());
      final PhotoJobFailed failed = result as PhotoJobFailed;
      expect(failed.reason, PhotoJobFailure.dailyLimit);
      expect(failed.charged, isFalse);
    });

    test('an upload failure is unreadable and never calls the server', () async {
      int calls = 0;
      final PhotoWallpaperRepository repo = PhotoWallpaperRepository(
        null,
        null,
        (Uint8List bytes, int side) async => throw const FormatException('bad'),
        (Map<String, Object?> payload) async {
          calls++;
          return _successMap;
        },
      );

      final PhotoJobState result = await repo.run(
        _job(mode: PhotoJobMode.upscale),
        requestId: 'req-00000001',
        targetSize: _phone,
      );

      expect(calls, 0);
      expect(result, isA<PhotoJobFailed>());
      final PhotoJobFailed failed = result as PhotoJobFailed;
      expect(failed.reason, PhotoJobFailure.unreadable);
      expect(failed.charged, isFalse);
    });
  });
}
