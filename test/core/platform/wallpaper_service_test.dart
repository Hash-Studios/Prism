import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/pigeon_impl_api.dart' as wallpaper_api;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/offline_asset_fixture.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

class _MockCacheManager extends Mock implements BaseCacheManager {}

aw.WallpaperOperationResult _result(
  aw.WallpaperOperationStatus status, {
  String? code,
  aw.WallpaperTargetStatus? home,
  aw.WallpaperTargetStatus? lock,
  aw.WallpaperTarget target = aw.WallpaperTarget.home,
}) => aw.WallpaperOperationResult(
  status: status,
  requestedTarget: target,
  errorCode: code,
  home: home == null ? null : aw.WallpaperTargetResult(status: home),
  lock: lock == null ? null : aw.WallpaperTargetResult(status: lock),
);

/// Answers each apply call with the next prepared result.
class _ResultClient extends _FakeClient {
  _ResultClient(this.prepared) : super(const <aw.WallpaperOperationStatus>[]);

  final List<aw.WallpaperOperationResult> prepared;

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    return prepared[(requests.length - 1).clamp(0, prepared.length - 1)];
  }
}

class _FakeClient implements WallpaperClient {
  _FakeClient(this.results);

  final List<aw.WallpaperOperationStatus> results;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => const aw.WallpaperCapabilities();

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    final aw.WallpaperOperationStatus status = results[(requests.length - 1).clamp(0, results.length - 1)];
    return aw.WallpaperOperationResult(
      status: status,
      requestedTarget: request.target,
      errorCode: status == aw.WallpaperOperationStatus.failed ? 'boom' : null,
    );
  }

  @override
  Future<aw.WallpaperOperationResult> prepareVideoWallpaper(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> openLiveWallpaperPreview(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> applyOpenGlWallpaper(aw.OpenGlLiveWallpaperRequest request) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.async_wallpaper.WallpaperApi.applyWallpaper',
    wallpaper_api.WallpaperApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late OfflineAssetFixture assets;

  setUp(() async {
    assets = await OfflineAssetFixture.create();
    assets.install();
  });

  tearDown(() => assets.dispose());
  tearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));

  test('a local-only cache miss reports unavailable without a network request', () async {
    const String source = 'https://example.test/not-saved.jpg';
    when(() => assets.cacheManager.getFileFromCache(source)).thenAnswer((_) async => null);

    await expectLater(
      WallpaperService.resolveToLocalFile(source, allowNetwork: false),
      throwsA(isA<OfflineAssetUnavailableException>()),
    );

    verifyNever(() => assets.cacheManager.getSingleFile(any()));
  });

  test('an unavailable original fails before any native wallpaper action', () async {
    const String source = 'https://example.test/not-saved.jpg';
    when(() => assets.cacheManager.getFileFromCache(source)).thenAnswer((_) async => null);
    when(() => assets.cacheManager.getSingleFile(source)).thenAnswer((_) async {
      throw const OfflineAssetUnavailableException(source);
    });
    final _FakeClient client = _FakeClient(<aw.WallpaperOperationStatus>[aw.WallpaperOperationStatus.applied]);
    aw.AsyncWallpaper.debugSetClient(client);
    addTearDown(aw.AsyncWallpaper.debugResetClient);

    final WallpaperSetResult result = await WallpaperService.setWallpaper(
      source,
      WallpaperTarget.home,
      recordHistory: false,
    );

    expect(result.isFailure, isTrue);
    expect(result.localizedMessage(_l10n), _l10n.coreWallpaperOfflineUnavailable);
    expect(result.errorCode, 'offline_unavailable');
    expect(client.requests, isEmpty);
  });

  test('a network socket failure reports offline availability before any native action', () async {
    const String source = 'https://example.test/socket-failure.jpg';
    when(() => assets.cacheManager.getFileFromCache(source)).thenAnswer((_) async => null);
    when(() => assets.cacheManager.getSingleFile(source)).thenThrow(const SocketException('Network is unreachable'));
    final _FakeClient client = _FakeClient(<aw.WallpaperOperationStatus>[aw.WallpaperOperationStatus.applied]);
    aw.AsyncWallpaper.debugSetClient(client);
    addTearDown(aw.AsyncWallpaper.debugResetClient);

    final WallpaperSetResult result = await WallpaperService.setWallpaper(
      source,
      WallpaperTarget.home,
      recordHistory: false,
    );

    expect(result.localizedMessage(_l10n), _l10n.coreWallpaperOfflineUnavailable);
    expect(result.errorCode, 'offline_unavailable');
    expect(client.requests, isEmpty);
  });

  test('a corrupt original is not reported as an offline availability failure', () async {
    const String source = 'https://example.test/corrupt.jpg';
    when(() => assets.cacheManager.getFileFromCache(source)).thenAnswer((_) async => null);
    when(() => assets.cacheManager.getSingleFile(source)).thenThrow(const FormatException('Invalid image'));
    final _FakeClient client = _FakeClient(<aw.WallpaperOperationStatus>[aw.WallpaperOperationStatus.applied]);
    aw.AsyncWallpaper.debugSetClient(client);
    addTearDown(aw.AsyncWallpaper.debugResetClient);

    final WallpaperSetResult result = await WallpaperService.setWallpaper(
      source,
      WallpaperTarget.home,
      recordHistory: false,
    );

    expect(result.localizedMessage(_l10n), _l10n.coreWallpaperErrorGeneric);
    expect(result.errorCode, 'load_failed');
    expect(client.requests, isEmpty);
  });

  test('resolves stale cached originals locally without requesting the network', () async {
    final Directory root = Directory.systemTemp.createTempSync('wallpaper-resolver-test-');
    const MethodChannel pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      (_) async => root.path,
    );
    late String cachedPath;
    addTearDown(() async {
      await root.delete(recursive: true);
      OfflineAssetStore.testOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathProvider, null);
    });
    const String source = 'https://example.test/stale-wallpaper.jpg';
    final File stale = File('${root.path}/stale.jpg');
    await stale.writeAsBytes(await (await assets.createImage('stale.jpg')).readAsBytes());
    final _MockCacheManager cache = _MockCacheManager();
    when(() => cache.getFileFromCache(source)).thenAnswer((_) async {
      final cacheFile = await IOFileSystem('wallpaper-resolver-test').createFile('stale-cache.jpg');
      await cacheFile.writeAsBytes(await stale.readAsBytes());
      cachedPath = cacheFile.path;
      return FileInfo(cacheFile, FileSource.Cache, DateTime(2000), source);
    });
    OfflineAssetStore.testOverride = OfflineAssetStore(
      directory: Directory('${root.path}/retained'),
      cacheManager: cache,
    );

    final File resolved = await WallpaperService.resolveToLocalFile(source, allowNetwork: false);

    expect(resolved.path, cachedPath);
    verifyNever(() => cache.getSingleFile(any()));
  });

  test('decodes a file URI before passing the local image path to the platform', () async {
    final File image = await assets.createImage('filtered wall#one.png');
    final String source = image.uri.toString();
    final String expectedPath = image.path;
    wallpaper_api.StaticWallpaperRequestData? request;
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      request = (message! as List<Object?>).single! as wallpaper_api.StaticWallpaperRequestData;
      return <Object?>[
        wallpaper_api.OperationResultData(
          status: wallpaper_api.OperationStatusData.applied,
          requestedTarget: wallpaper_api.WallpaperTargetData.home,
          home: wallpaper_api.TargetResultData(status: wallpaper_api.TargetStatusData.applied),
        ),
      ];
    });

    expect(await WallpaperService.setWallpaperFromSource(source, WallpaperTarget.home), isTrue);
    expect(request?.source?.filePath, expectedPath);
    expect(request?.source?.kind, wallpaper_api.WallpaperSourceKindData.filePath);
    expect(request?.target, wallpaper_api.WallpaperTargetData.home);
  });

  test('normalizes a repeated separator in a local image path', () async {
    final File image = await assets.createImage('wall.png');
    final String source = image.path.replaceFirst('/images/', '/images/0//');
    final String expectedPath = image.path.replaceFirst('/images/', '/images/0/');
    await Directory('${assets.directory.path}/images/0').create(recursive: true);
    await image.copy(expectedPath);
    wallpaper_api.StaticWallpaperRequestData? request;
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      request = (message! as List<Object?>).single! as wallpaper_api.StaticWallpaperRequestData;
      return <Object?>[
        wallpaper_api.OperationResultData(
          status: wallpaper_api.OperationStatusData.applied,
          requestedTarget: wallpaper_api.WallpaperTargetData.home,
          home: wallpaper_api.TargetResultData(status: wallpaper_api.TargetStatusData.applied),
        ),
      ];
    });

    expect(await WallpaperService.setWallpaperFromSource(source, WallpaperTarget.home), isTrue);
    expect(request?.source?.filePath, expectedPath);
    expect(request?.source?.kind, wallpaper_api.WallpaperSourceKindData.filePath);
    expect(request?.target, wallpaper_api.WallpaperTargetData.home);
  });

  group('status mapping', () {
    tearDown(aw.AsyncWallpaper.debugResetClient);

    Future<WallpaperSetResult> run(List<aw.WallpaperOperationStatus> statuses) {
      aw.AsyncWallpaper.debugSetClient(_FakeClient(statuses));
      return WallpaperService.setWallpaper('/tmp/wall.png', WallpaperTarget.both, recordHistory: false);
    }

    test('applied is success', () async {
      final WallpaperSetResult result = await run([aw.WallpaperOperationStatus.applied]);
      expect(result.status, WallpaperSetStatus.applied);
      expect(result.isSuccess, isTrue);
    });

    test('cancelled is silent', () async {
      final WallpaperSetResult result = await run([aw.WallpaperOperationStatus.cancelled]);
      expect(result.status, WallpaperSetStatus.cancelled);
      expect(result.isSilent, isTrue);
      expect(result.isFailure, isFalse);
    });

    for (final status in <aw.WallpaperOperationStatus>[
      aw.WallpaperOperationStatus.previewOpened,
      aw.WallpaperOperationStatus.awaitingUserConfirmation,
    ]) {
      test('$status is an info result', () async {
        final WallpaperSetResult result = await run([status]);
        expect(result.status, WallpaperSetStatus.pending);
        expect(result.isInfo, isTrue);
        expect(result.isSuccess, isFalse);
      });
    }

    test('unsupported says the device cannot set that screen', () async {
      final WallpaperSetResult result = await run([aw.WallpaperOperationStatus.unsupported]);
      expect(result.status, WallpaperSetStatus.unsupported);
      expect(result.localizedMessage(_l10n), _l10n.coreDeviceCannotSetScreen);
      expect(result.canRetry, isFalse);
    });

    test('foregroundRequired can be retried', () async {
      final WallpaperSetResult result = await run([aw.WallpaperOperationStatus.foregroundRequired]);
      expect(result.status, WallpaperSetStatus.foregroundRequired);
      expect(result.canRetry, isTrue);
    });

    test('a failed direct apply is retried once with the automatic strategy', () async {
      final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.failed, aw.WallpaperOperationStatus.applied]);
      aw.AsyncWallpaper.debugSetClient(client);
      final WallpaperSetResult result = await WallpaperService.setWallpaper(
        '/tmp/wall.png',
        WallpaperTarget.home,
        recordHistory: false,
      );
      expect(result.isSuccess, isTrue);
      expect(client.requests.map((r) => r.strategy), [
        aw.WallpaperApplyStrategy.direct,
        aw.WallpaperApplyStrategy.automatic,
      ]);
    });

    test('a second failure is reported as failed and retryable', () async {
      final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.failed]);
      aw.AsyncWallpaper.debugSetClient(client);
      final WallpaperSetResult result = await WallpaperService.setWallpaper(
        '/tmp/wall.png',
        WallpaperTarget.home,
        recordHistory: false,
      );
      expect(client.requests, hasLength(2));
      expect(result.status, WallpaperSetStatus.failed);
      expect(result.canRetry, isTrue);
      expect(result.errorCode, 'boom');
    });

    test(
      'every apply goes out as a file path with the direct strategy first unless the cropper is asked for',
      () async {
        final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.failed]);
        aw.AsyncWallpaper.debugSetClient(client);
        await WallpaperService.setWallpaper('/tmp/wall.png', WallpaperTarget.home, recordHistory: false);
        expect(client.requests.first.strategy, aw.WallpaperApplyStrategy.direct);
        expect(client.requests.map((r) => r.strategy), isNot(contains(aw.WallpaperApplyStrategy.systemCropper)));
      },
    );

    test('the system cropper gets a content URI and is not retried', () async {
      const MethodChannel cropChannel = MethodChannel('prism/wallpaper_crop');
      final List<Object?> cropArguments = <Object?>[];
      final File image = await assets.createImage('crop-wall.png');
      messenger.setMockMethodCallHandler(cropChannel, (MethodCall call) async {
        cropArguments.add(call.arguments);
        return 'content://com.hash.prism.wallpaper_crop/wallpaper_crop/wallpaper.png';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(cropChannel, null));
      final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.failed]);
      aw.AsyncWallpaper.debugSetClient(client);
      await WallpaperService.setWallpaper(
        image.path,
        WallpaperTarget.home,
        useSystemCropper: true,
        recordHistory: false,
      );
      expect(cropArguments, [image.path]);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.strategy, aw.WallpaperApplyStrategy.systemCropper);
      expect(
        client.requests.single.source.contentUri,
        'content://com.hash.prism.wallpaper_crop/wallpaper_crop/wallpaper.png',
      );
      expect(client.requests.single.source.filePath, isNull);
    });

    test('a missing or null crop URI becomes a retryable failure', () async {
      const MethodChannel cropChannel = MethodChannel('prism/wallpaper_crop');
      addTearDown(() => messenger.setMockMethodCallHandler(cropChannel, null));
      final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.applied]);
      aw.AsyncWallpaper.debugSetClient(client);

      messenger.setMockMethodCallHandler(cropChannel, null);
      final WallpaperSetResult missingPlugin = await WallpaperService.setWallpaper(
        '/tmp/wall.png',
        WallpaperTarget.home,
        useSystemCropper: true,
        recordHistory: false,
      );
      expect(missingPlugin.status, WallpaperSetStatus.failed);
      expect(missingPlugin.canRetry, isTrue);
      expect(client.requests, isEmpty);

      messenger.setMockMethodCallHandler(cropChannel, (_) async => null);
      final WallpaperSetResult nullUri = await WallpaperService.setWallpaper(
        '/tmp/wall.png',
        WallpaperTarget.home,
        useSystemCropper: true,
        recordHistory: false,
      );
      expect(nullUri.status, WallpaperSetStatus.failed);
      expect(nullUri.canRetry, isTrue);
      expect(client.requests, isEmpty);
    });

    test('fit maps to the plugin scale mode', () async {
      final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.applied]);
      aw.AsyncWallpaper.debugSetClient(client);
      await WallpaperService.setWallpaper('/tmp/a.png', WallpaperTarget.home, recordHistory: false);
      await WallpaperService.setWallpaper(
        '/tmp/a.png',
        WallpaperTarget.home,
        fit: WallpaperFit.whole,
        recordHistory: false,
      );
      expect(client.requests.map((r) => r.scaleMode), [
        aw.WallpaperScaleMode.centerCrop,
        aw.WallpaperScaleMode.fitCenter,
      ]);
    });

    test('a plugin exception is a retryable failure', () async {
      aw.AsyncWallpaper.debugSetClient(_ThrowingClient());
      final WallpaperSetResult result = await WallpaperService.setWallpaper(
        '/tmp/wall.png',
        WallpaperTarget.home,
        recordHistory: false,
      );
      expect(result.status, WallpaperSetStatus.failed);
      expect(result.canRetry, isTrue);
    });
  });

  group('error codes', () {
    tearDown(aw.AsyncWallpaper.debugResetClient);

    Future<WallpaperSetResult> set(_FakeClient client, {WallpaperTarget target = WallpaperTarget.home}) {
      aw.AsyncWallpaper.debugSetClient(client);
      return WallpaperService.setWallpaper('/tmp/wall.png', target, recordHistory: false);
    }

    test('image-too-large explains the problem, offers no retry and skips the second attempt', () async {
      final _ResultClient client = _ResultClient([
        _result(aw.WallpaperOperationStatus.failed, code: 'image-too-large'),
      ]);
      final WallpaperSetResult result = await set(client);
      expect(result.localizedMessage(_l10n), _l10n.coreWallpaperErrorImageTooLarge);
      expect(result.canRetry, isFalse);
      expect(result.isFailure, isTrue);
      expect(client.requests, hasLength(1));
    });

    test('wallpaper-not-allowed arrives as unsupported and names the work profile', () async {
      final _ResultClient client = _ResultClient([
        _result(aw.WallpaperOperationStatus.unsupported, code: 'wallpaper-not-allowed'),
      ]);
      final WallpaperSetResult result = await set(client);
      expect(result.status, WallpaperSetStatus.unsupported);
      expect(result.localizedMessage(_l10n), _l10n.coreWallpaperErrorNotAllowed);
      expect(result.canRetry, isFalse);
      expect(result.isFailure, isTrue);
      expect(client.requests, hasLength(1));
    });

    test('unsupported without a code keeps the screen message', () async {
      final WallpaperSetResult result = await set(_ResultClient([_result(aw.WallpaperOperationStatus.unsupported)]));
      expect(result.localizedMessage(_l10n), _l10n.coreDeviceCannotSetScreen);
    });

    test('out-of-memory is retryable with its own message', () async {
      final _ResultClient client = _ResultClient([_result(aw.WallpaperOperationStatus.failed, code: 'out-of-memory')]);
      final WallpaperSetResult result = await set(client);
      expect(result.localizedMessage(_l10n), _l10n.coreWallpaperErrorMemory);
      expect(result.canRetry, isTrue);
      expect(client.requests, hasLength(2));
    });

    test('partial-apply names the screen that worked and the one that failed', () async {
      final _ResultClient client = _ResultClient([
        _result(
          aw.WallpaperOperationStatus.failed,
          code: 'partial-apply',
          home: aw.WallpaperTargetStatus.applied,
          lock: aw.WallpaperTargetStatus.failed,
          target: aw.WallpaperTarget.both,
        ),
      ]);
      final WallpaperSetResult result = await set(client, target: WallpaperTarget.both);
      expect(
        result.localizedMessage(_l10n),
        _l10n.coreWallpaperPartialSet(_l10n.coreWallpaperHomeScreen, _l10n.coreWallpaperLockScreen),
      );
      expect(result.isPartial, isTrue);
      expect(result.appliedTarget, WallpaperTarget.home);
      expect(result.failedTarget, WallpaperTarget.lock);
      expect(result.canRetry, isTrue);
    });

    test('partial-apply with only the lock screen changed says so', () async {
      final WallpaperSetResult result = await set(
        _ResultClient([
          _result(
            aw.WallpaperOperationStatus.failed,
            code: 'partial-apply',
            home: aw.WallpaperTargetStatus.failed,
            lock: aw.WallpaperTargetStatus.applied,
            target: aw.WallpaperTarget.both,
          ),
        ]),
        target: WallpaperTarget.both,
      );
      expect(
        result.localizedMessage(_l10n),
        _l10n.coreWallpaperPartialSet(_l10n.coreWallpaperLockScreen, _l10n.coreWallpaperHomeScreen),
      );
      expect(result.failedTarget, WallpaperTarget.home);
    });
  });

  group('history recording', () {
    late WallpaperHistoryStore store;
    late Directory temporaryDirectory;
    late Directory cacheDirectory;

    setUp(() async {
      store = WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore()));
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      temporaryDirectory = Directory('${assets.directory.path}/temporary');
      cacheDirectory = Directory('${assets.directory.path}/cache');
      await temporaryDirectory.create(recursive: true);
      await cacheDirectory.create(recursive: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => call.method == 'getTemporaryDirectory' ? temporaryDirectory.path : cacheDirectory.path,
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      await getIt.reset();
      aw.AsyncWallpaper.debugResetClient();
    });

    Future<File> createHistoryImage(String path) async {
      final File source = await assets.createImage('history-source.png');
      final File image = File(path);
      await image.parent.create(recursive: true);
      return source.copy(image.path);
    }

    test('a success is recorded once with its target', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      await WallpaperService.setWallpaper('/tmp/wall.png', WallpaperTarget.lock, thumbnailUrl: '/tmp/thumb.png');
      expect(store.items(), hasLength(1));
      expect(store.items().single.target, 'lock');
      expect(store.items().single.fullUrl, '/tmp/wall.png');
      expect(store.items().single.thumbnailUrl, '/tmp/thumb.png');
    });

    test('a file in the temp or cache directory is not recorded, other local files are', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));

      final File temporaryImage = await createHistoryImage('${temporaryDirectory.path}/ai_1.png');
      final File cachedImage = await createHistoryImage('${cacheDirectory.path}/libCachedImageData/x.png');
      await WallpaperService.setWallpaper(temporaryImage.path, WallpaperTarget.home);
      await WallpaperService.setWallpaper(cachedImage.path, WallpaperTarget.home);
      expect(store.items(), isEmpty);

      await WallpaperService.setWallpaper('/storage/emulated/0/Pictures/Prism/saved.png', WallpaperTarget.home);
      expect(store.items().single.fullUrl, '/storage/emulated/0/Pictures/Prism/saved.png');
    });

    test('history keeps the original wall when a rendered copy is set', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      final File renderedImage = await createHistoryImage(
        '${temporaryDirectory.path}/prism_edit/position_1/placement.png',
      );
      await WallpaperService.setWallpaper(
        renderedImage.path,
        WallpaperTarget.home,
        historySource: 'https://img.prismwalls.com/full.jpg',
        historyThumbnail: 'https://img.prismwalls.com/thumb.jpg',
      );
      expect(store.items().single.fullUrl, 'https://img.prismwalls.com/full.jpg');
      expect(store.items().single.thumbnailUrl, 'https://img.prismwalls.com/thumb.jpg');
      expect(store.items().single.source, 'prism');
    });

    test('a success returns the previous wall of each affected screen and the new history row', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      await WallpaperService.setWallpaper('/storage/a.jpg', WallpaperTarget.home);
      await WallpaperService.setWallpaper('/storage/b.jpg', WallpaperTarget.lock);

      final WallpaperSetResult result = await WallpaperService.setWallpaper('/storage/c.jpg', WallpaperTarget.both);

      expect(result.restore.map((r) => (r.target, r.previous.fullUrl)), [
        (WallpaperTarget.home, '/storage/a.jpg'),
        (WallpaperTarget.lock, '/storage/b.jpg'),
      ]);
      expect(result.historyIds, [store.items().first.id]);
    });

    test('one previous wall on both screens becomes one both entry', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      await WallpaperService.setWallpaper('/storage/a.jpg', WallpaperTarget.both);

      final WallpaperSetResult result = await WallpaperService.setWallpaper('/storage/c.jpg', WallpaperTarget.home);

      expect(result.restore.single.target, WallpaperTarget.home);
      final WallpaperSetResult both = await WallpaperService.setWallpaper('/storage/d.jpg', WallpaperTarget.both);
      expect(both.restore.map((r) => (r.target, r.previous.fullUrl)), [
        (WallpaperTarget.home, '/storage/c.jpg'),
        (WallpaperTarget.lock, '/storage/a.jpg'),
      ]);
    });

    test('setting the wall that is already there offers no undo', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      await WallpaperService.setWallpaper('/storage/a.jpg', WallpaperTarget.home);
      final WallpaperSetResult result = await WallpaperService.setWallpaper('/storage/a.jpg', WallpaperTarget.home);
      expect(result.restore, isEmpty);
    });

    test('the first set has nothing to restore and recordHistory false returns no row', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      final WallpaperSetResult first = await WallpaperService.setWallpaper('/storage/a.jpg', WallpaperTarget.home);
      expect(first.restore, isEmpty);
      expect(first.historyIds, hasLength(1));
      final WallpaperSetResult silent = await WallpaperService.setWallpaper(
        '/storage/b.jpg',
        WallpaperTarget.home,
        recordHistory: false,
      );
      expect(silent.restore, isEmpty);
      expect(silent.historyIds, isEmpty);
    });

    test('a partial apply records only the screen that changed', () async {
      aw.AsyncWallpaper.debugSetClient(
        _ResultClient([
          _result(
            aw.WallpaperOperationStatus.failed,
            code: 'partial-apply',
            home: aw.WallpaperTargetStatus.applied,
            lock: aw.WallpaperTargetStatus.failed,
            target: aw.WallpaperTarget.both,
          ),
        ]),
      );
      final WallpaperSetResult result = await WallpaperService.setWallpaper('/storage/a.jpg', WallpaperTarget.both);
      expect(result.isPartial, isTrue);
      expect(store.items().single.target, 'home');
      expect(result.historyIds, [store.items().single.id]);
    });

    test('failures, pending results and opt-outs are not recorded', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.unsupported]));
      await WallpaperService.setWallpaper('/tmp/wall.png', WallpaperTarget.lock);
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.previewOpened]));
      await WallpaperService.setWallpaper('/tmp/wall.png', WallpaperTarget.lock);
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      await WallpaperService.setWallpaper('/tmp/wall.png', WallpaperTarget.lock, recordHistory: false);
      expect(store.items(), isEmpty);
    });
  });
}

class _ThrowingClient extends _FakeClient {
  _ThrowingClient() : super(const <aw.WallpaperOperationStatus>[]);

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) =>
      throw PlatformException(code: 'boom');
}
