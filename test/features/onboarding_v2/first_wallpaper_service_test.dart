import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCategoryFeedRepository extends Mock implements CategoryFeedRepository {}

class _MockWallOfTheDayRepository extends Mock implements WallOfTheDayRepository {}

void main() {
  late _MockWallOfTheDayRepository wotdRepository;
  late FirstWallpaperService service;

  setUp(() {
    wotdRepository = _MockWallOfTheDayRepository();
    service = FirstWallpaperService(_MockCategoryFeedRepository(), wotdRepository);
  });

  void stubWotd(Result<WallOfTheDayEntity?> result) =>
      when(() => wotdRepository.fetchToday()).thenAnswer((_) async => result);

  test('without interests the wall of the day is the recommendation', () async {
    stubWotd(
      Result.success(
        const WallOfTheDayEntity(
          wallId: 'w1',
          url: 'https://example.com/full.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          photographer: 'Ana',
        ),
      ),
    );

    final vm = await service.recommendForOnboarding(const <String>[]);

    expect(vm?.fullUrl, 'https://example.com/full.jpg');
    expect(vm?.thumbnailUrl, 'https://example.com/thumb.jpg');
  });

  test('protected WOTD is recommended using canonical identity and thumbnail', () async {
    stubWotd(
      Result.success(
        const WallOfTheDayEntity(
          wallId: 'protected',
          url: '',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          photographer: 'Ana',
        ),
      ),
    );
    final vm = await service.recommendForOnboarding(const <String>[]);
    expect(vm?.wallpaperId, 'protected');
    expect(vm?.wallpaperSource, WallpaperSource.prism);
    expect(vm?.fullUrl, isEmpty);
    expect(vm?.thumbnailUrl, 'https://example.com/thumb.jpg');
  });

  test('a missing Prism thumbnail never falls back to the original', () async {
    stubWotd(
      Result.success(
        const WallOfTheDayEntity(wallId: 'w1', url: 'https://example.com/full.jpg', thumbnailUrl: '', photographer: ''),
      ),
    );

    final vm = await service.recommendForOnboarding(const <String>[]);

    expect(vm?.thumbnailUrl, isEmpty);
  });

  test('no pick, an empty url or a failed fetch all mean no recommendation', () async {
    stubWotd(Result.success(null));
    expect(await service.recommendForOnboarding(const <String>[]), isNull);

    stubWotd(Result.success(const WallOfTheDayEntity(wallId: 'w1', url: '', thumbnailUrl: '', photographer: '')));
    expect(await service.recommendForOnboarding(const <String>[]), isNull);

    stubWotd(Result.error(const ServerFailure('offline')));
    expect(await service.recommendForOnboarding(const <String>[]), isNull);
  });

  group('performAction', () {
    late List<WallpaperTarget> appliedTargets;
    late List<String> appliedUrls;
    late List<SaveMediaRequest> savedRequests;

    FirstWallpaperService build({
      required aw.WallpaperCapabilities capabilities,
      WallpaperSetResult? setResult,
      OperationResult? saveResult,
      bool capabilitiesThrow = false,
      bool setThrows = false,
      OriginalAccessService? originalAccess,
    }) => FirstWallpaperService(
      _MockCategoryFeedRepository(),
      wotdRepository,
      originalAccess: originalAccess,
      getCapabilities: () async => capabilitiesThrow ? throw StateError('no channel') : capabilities,
      setWallpaper: (url, target) async {
        appliedUrls.add(url);
        appliedTargets.add(target);
        if (setThrows) throw StateError('boom');
        return setResult ?? const WallpaperSetResult(WallpaperSetStatus.applied, WallpaperService.appliedMessage);
      },
      saveMedia: (request) async {
        savedRequests.add(request);
        return saveResult ?? OperationResult(success: true);
      },
    );

    setUp(() {
      appliedTargets = <WallpaperTarget>[];
      appliedUrls = <String>[];
      savedRequests = <SaveMediaRequest>[];
    });

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    const bothSupported = aw.WallpaperCapabilities(
      supportsStaticWallpaper: true,
      supportsHomeWallpaper: true,
      supportsLockWallpaper: true,
      supportsBothWallpapers: true,
    );

    test('denied Prism access never invokes native set or save', () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final result = await build(
          capabilities: bothSupported,
          originalAccess: OriginalAccessService(owner: () => 'user', call: (_) async => {'status': 'denied'}),
        ).performAction('', wallpaperId: 'protected', wallpaperSource: WallpaperSource.prism);
        expect(result.success, isFalse);
        expect(appliedTargets, isEmpty);
        expect(savedRequests, isEmpty);
      }
    });

    test('granted canonical original, not the public URL, reaches the native operation', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final result =
          await build(
            capabilities: bothSupported,
            originalAccess: OriginalAccessService(
              owner: () => 'user',
              call: (request) async {
                expect(request['assetId'], 'protected');
                expect(request['action'], 'set');
                return {
                  'status': 'granted',
                  'currentBalance': 100,
                  'url': 'https://signed.example/original.jpg',
                  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
                };
              },
            ),
          ).performAction(
            'https://public.example/full.jpg',
            wallpaperId: 'protected',
            wallpaperSource: WallpaperSource.prism,
          );
      expect(result.success, isTrue);
      expect(appliedUrls, ['https://signed.example/original.jpg']);
      expect(appliedTargets, <WallpaperTarget>[WallpaperTarget.both]);
      expect(savedRequests, isEmpty);
    });

    test('unknown remote access never invokes native operations', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final result = await build(capabilities: bothSupported).performAction('https://example.com/full.jpg');
      expect(result.success, isFalse);
      expect(appliedTargets, isEmpty);
      expect(savedRequests, isEmpty);
    });

    test('Android sets the home and lock screens when the device supports both', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final result = await build(capabilities: bothSupported).performAction('/tmp/full.jpg');

      expect(result.success, isTrue);
      expect(result.target, WallpaperTarget.both);
      expect(appliedTargets, <WallpaperTarget>[WallpaperTarget.both]);
    });

    test('Android falls back to the home screen when both is not supported', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const homeOnly = aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true);

      final result = await build(capabilities: homeOnly).performAction('/tmp/full.jpg');

      expect(result.success, isTrue);
      expect(result.target, WallpaperTarget.home);
      expect(appliedTargets, <WallpaperTarget>[WallpaperTarget.home]);
    });

    test('Android reports unsupported without applying when no screen can be set', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const none = aw.WallpaperCapabilities(supportsStaticWallpaper: true);

      final result = await build(capabilities: none).performAction('/tmp/full.jpg');

      expect(result.success, isFalse);
      expect(result.errorCode, 'unsupported');
      expect(appliedTargets, isEmpty);
    });

    test('Android still tries both when the capability check fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final result = await build(capabilities: bothSupported, capabilitiesThrow: true).performAction('/tmp/full.jpg');

      expect(result.success, isTrue);
      expect(appliedTargets, <WallpaperTarget>[WallpaperTarget.both]);
    });

    test('Android passes the plugin error code through on failure', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final result = await build(
        capabilities: bothSupported,
        setResult: const WallpaperSetResult(WallpaperSetStatus.failed, 'x', errorCode: 'image-too-large'),
      ).performAction('/tmp/full.jpg');

      expect(result.success, isFalse);
      expect(result.errorCode, 'image-too-large');
    });

    test('a thrown error becomes a failure instead of an exception', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final result = await build(capabilities: bothSupported, setThrows: true).performAction('/tmp/full.jpg');

      expect(result.success, isFalse);
      expect(result.errorCode, 'exception');
    });

    test('iOS saves the wallpaper to Photos', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final result = await build(capabilities: bothSupported).performAction('/tmp/full.jpg');

      expect(result.success, isTrue);
      expect(result.target, isNull);
      expect(savedRequests.single.link, '/tmp/full.jpg');
      expect(savedRequests.single.isLocalFile, isTrue);
      expect(savedRequests.single.kind, SaveMediaKind.wallpaper);
      expect(appliedTargets, isEmpty);
    });

    test('iOS keeps the Photos permission error code', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final result = await build(
        capabilities: bothSupported,
        saveResult: OperationResult(success: false, errorCode: 'PHOTO_PERMISSION_DENIED'),
      ).performAction('/tmp/full.jpg');

      expect(result.success, isFalse);
      expect(result.errorCode, 'PHOTO_PERMISSION_DENIED');
    });
  });
}
