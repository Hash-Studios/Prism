import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/pigeon_impl_api.dart' as wallpaper_api;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

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
  tearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));

  for (final source in <String, String>{
    'file:///tmp/filtered%20wall%23one.png': '/tmp/filtered wall#one.png',
    '/storage/emulated/0//wall.png': '/storage/emulated/0/wall.png',
  }.entries) {
    test('applies ${source.key} as its decoded local path', () async {
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

      expect(await WallpaperService.setWallpaperFromSource(source.key, WallpaperTarget.home), isTrue);
      expect(request?.source?.filePath, source.value);
      expect(request?.source?.kind, wallpaper_api.WallpaperSourceKindData.filePath);
      expect(request?.target, wallpaper_api.WallpaperTargetData.home);
    });
  }

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
      expect(result.message, "This device can't set that screen.");
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
      messenger.setMockMethodCallHandler(cropChannel, (MethodCall call) async {
        cropArguments.add(call.arguments);
        return 'content://com.hash.prism.wallpaper_crop/wallpaper_crop/wallpaper.png';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(cropChannel, null));
      final _FakeClient client = _FakeClient([aw.WallpaperOperationStatus.failed]);
      aw.AsyncWallpaper.debugSetClient(client);
      await WallpaperService.setWallpaper(
        '/tmp/wall.png',
        WallpaperTarget.home,
        useSystemCropper: true,
        recordHistory: false,
      );
      expect(cropArguments, ['/tmp/wall.png']);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.strategy, aw.WallpaperApplyStrategy.systemCropper);
      // The plugin refuses the cropper for a file path, so every crop failed before.
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
      expect(result.message, 'This image is too large for your device to set.');
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
      expect(result.message, 'Your device or work profile does not allow wallpaper changes.');
      expect(result.canRetry, isFalse);
      expect(result.isFailure, isTrue);
      expect(client.requests, hasLength(1));
    });

    test('unsupported without a code keeps the screen message', () async {
      final WallpaperSetResult result = await set(_ResultClient([_result(aw.WallpaperOperationStatus.unsupported)]));
      expect(result.message, "This device can't set that screen.");
    });

    test('out-of-memory is retryable with its own message', () async {
      final _ResultClient client = _ResultClient([_result(aw.WallpaperOperationStatus.failed, code: 'out-of-memory')]);
      final WallpaperSetResult result = await set(client);
      expect(result.message, 'Not enough memory. Close other apps and try again.');
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
      expect(result.message, 'Home screen set. Lock screen failed.');
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
      expect(result.message, 'Lock screen set. Home screen failed.');
      expect(result.failedTarget, WallpaperTarget.home);
    });
  });

  group('history recording', () {
    late WallpaperHistoryStore store;

    setUp(() {
      store = WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore()));
      getIt.registerSingleton<WallpaperHistoryStore>(store);
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => call.method == 'getTemporaryDirectory' ? '/scratch/temp' : '/scratch/cache',
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

      await WallpaperService.setWallpaper('/scratch/temp/ai_1.png', WallpaperTarget.home);
      await WallpaperService.setWallpaper('/scratch/cache/libCachedImageData/x.png', WallpaperTarget.home);
      expect(store.items(), isEmpty);

      await WallpaperService.setWallpaper('/storage/emulated/0/Pictures/Prism/saved.png', WallpaperTarget.home);
      expect(store.items().single.fullUrl, '/storage/emulated/0/Pictures/Prism/saved.png');
    });

    test('history keeps the original wall when a rendered copy is set', () async {
      aw.AsyncWallpaper.debugSetClient(_FakeClient([aw.WallpaperOperationStatus.applied]));
      await WallpaperService.setWallpaper(
        '/scratch/temp/prism_edit/position_1/placement.png',
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
