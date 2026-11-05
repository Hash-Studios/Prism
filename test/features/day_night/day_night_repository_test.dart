import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/data/repositories/day_night_repository_impl.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:async_wallpaper/pigeon_impl_api.dart' as pigeon;
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

const String _snapshotKey = 'shortcuts.day_night';

const _codec = pigeon.WallpaperApi.pigeonChannelCodec;

/// Replaces the host handler for one WallpaperApi method and removes it after the test.
/// Same channel and teardown as async_wallpaper's daily_schedule_test.dart.
void _mockHostMethod(String method, Future<ByteData?> Function(ByteData? message) handler) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.$method';
  messenger.setMockMessageHandler(channel, handler);
  addTearDown(() => messenger.setMockMessageHandler(channel, null));
}

const DayNightWall _httpsDay = DayNightWall(
  id: 'day',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/day.jpg',
  thumbnailUrl: 'https://example.com/day-thumb.jpg',
);

const DayNightWall _httpsNight = DayNightWall(
  id: 'night',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/night.jpg',
  thumbnailUrl: 'https://example.com/night-thumb.jpg',
);

const DayNightWall _protected = DayNightWall(
  id: 'locked',
  source: WallpaperSource.prism,
  fullUrl: '',
  thumbnailUrl: 'https://example.com/locked-thumb.jpg',
);

/// Keeps each https source under the retained root as `copy-<n>.jpg` without touching the disk.
class _FakeOfflineStore extends OfflineAssetStore {
  _FakeOfflineStore(this.root, {this.delayedSource, this.releaseDelayedSource});

  final Directory root;
  final String? delayedSource;
  final Completer<void>? releaseDelayedSource;
  final Map<String, String> retained = <String, String>{};

  @override
  Future<File> retain(String source, {File? file}) async {
    if (source == delayedSource) await releaseDelayedSource!.future;
    final String absolute = path.join(root.path, 'prism', 'offline', 'assets', 'copy-${retained.length}.jpg');
    retained[source] = absolute;
    return File(absolute);
  }

  @override
  Future<Map<String, String>> localPaths() async => retained;
}

class _FailingDayNightPathStore extends InMemorySharedPreferencesStore {
  _FailingDayNightPathStore(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.offline.native_asset_paths.daynight') return Future<bool>.value(false);
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late InMemoryLocalStore store;
  late DayNightRepositoryImpl repository;

  setUp(() async {
    DayNightRepositoryImpl.runsOnDeviceOverride = false;
    app_state.prismUser = profileUser(id: 'owner-a');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('prism-day-night-test');
    NativeAssetPathsStore.supportDirectoryOverride = root;
    NativeAssetPathsStore.documentsDirectoryOverride = Directory(path.join(root.path, 'documents'));
    OfflineAssetStore.testOverride = _FakeOfflineStore(root);
    store = InMemoryLocalStore();
    repository = DayNightRepositoryImpl(SettingsLocalDataSource(store));
  });

  tearDown(() async {
    DayNightRepositoryImpl.runsOnDeviceOverride = null;
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    OfflineAssetStore.testOverride = null;
    NativeAssetPathsStore.supportDirectoryOverride = null;
    NativeAssetPathsStore.documentsDirectoryOverride = null;
    DayNightRepositoryImpl.downloadedOriginalOverride = null;
    if (await root.exists()) await root.delete(recursive: true);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });

  Future<String?> snapshot() async => (await SharedPreferences.getInstance()).getString(_snapshotKey);

  test('save then load returns the same pair for the same owner', () async {
    final DayNightPair pair = DayNightPair(
      day: _httpsDay,
      night: _httpsNight,
      times: DayNightTimes.tryCreate(DayTime.hm(6, 30), DayTime.hm(20, 15)),
      target: WallpaperTarget.lock,
      enabled: true,
      fromVariants: true,
      passUntil: DateTime.fromMillisecondsSinceEpoch(1793000000000),
    );

    await repository.save(pair, ownerId: 'u1');

    expect(await repository.load(ownerId: 'u1'), pair);
  });

  test('load for another owner returns the default pair', () async {
    await repository.save(
      DayNightPair(day: _httpsDay, night: _httpsNight, enabled: true),
      ownerId: 'u1',
    );

    expect(await repository.load(ownerId: 'u2'), DayNightPair());
  });

  test('corrupt JSON loads as the default pair', () async {
    await SettingsLocalDataSource(store).set('dayNight.pair', 'not json {');

    expect(await repository.load(ownerId: 'u1'), DayNightPair());
  });

  test('publish writes the snapshot for two https walls', () async {
    await repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));

    expect(
      await snapshot(),
      '{"dayStart":420,"nightStart":1140,'
      '"day":{"id":"day","url":"https://example.com/day.jpg"},'
      '"night":{"id":"night","url":"https://example.com/night.jpg"}}',
    );
    final String? paths = (await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight');
    expect(jsonDecode(paths!), <String, Object?>{
      'https://example.com/day.jpg': 'copy-0.jpg',
      'https://example.com/night.jpg': 'copy-1.jpg',
    });
  });

  test('a slower earlier publish cannot replace a later enabled edit', () async {
    final Completer<void> releaseFirst = Completer<void>();
    OfflineAssetStore.testOverride = _FakeOfflineStore(
      root,
      delayedSource: _httpsDay.fullUrl,
      releaseDelayedSource: releaseFirst,
    );
    const DayNightWall laterDay = DayNightWall(
      id: 'later-day',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/later-day.jpg',
      thumbnailUrl: 'https://example.com/later-day-thumb.jpg',
    );
    final Future<void> first = repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));
    await Future<void>.delayed(Duration.zero);

    await repository.publish(DayNightPair(day: laterDay, night: _httpsNight));
    releaseFirst.complete();
    await first;

    expect((jsonDecode((await snapshot())!) as Map<String, dynamic>)['day'], <String, Object?>{
      'id': 'later-day',
      'url': 'https://example.com/later-day.jpg',
    });
  });

  test('unpublish cancels a publish still preparing assets', () async {
    final Completer<void> releaseFirst = Completer<void>();
    OfflineAssetStore.testOverride = _FakeOfflineStore(
      root,
      delayedSource: _httpsDay.fullUrl,
      releaseDelayedSource: releaseFirst,
    );
    final Future<void> first = repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));
    await Future<void>.delayed(Duration.zero);

    await repository.unpublish();
    releaseFirst.complete();
    await first;

    expect(await snapshot(), isNull);
    expect((await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight'), '{}');
  });

  test('account change during preparation does not publish the old account snapshot', () async {
    final Completer<void> releaseFirst = Completer<void>();
    OfflineAssetStore.testOverride = _FakeOfflineStore(
      root,
      delayedSource: _httpsDay.fullUrl,
      releaseDelayedSource: releaseFirst,
    );
    final Future<void> first = repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));
    await Future<void>.delayed(Duration.zero);
    app_state.prismUser = profileUser(id: 'owner-b');
    releaseFirst.complete();
    await first;

    expect(await snapshot(), isNull);
    expect((await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight'), isNull);
  });

  test('native path invalidation before queued publish prevents an orphan snapshot', () async {
    final Completer<void> releaseQueue = Completer<void>();
    final Future<void> blocker = NativeAssetPathsStore.replaceGroup(
      'daynight',
      const <String, String>{},
      afterReplace: () => releaseQueue.future,
    );
    final Future<void> publish = repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));
    await Future<void>.delayed(Duration.zero);
    final Future<void> clear = NativeAssetPathsStore.clearForUser('owner-a');
    await Future<void>.delayed(Duration.zero);
    releaseQueue.complete();
    await Future.wait(<Future<void>>[blocker, publish, clear]);

    expect(await snapshot(), isNull);
    expect((await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight'), '{}');
  });

  test('guest publish does not write a shortcut snapshot', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);

    await repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));

    expect(await snapshot(), isNull);
    expect((await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight'), isNull);
  });

  test('unpublish removes the snapshot even when clearing native paths fails', () async {
    await repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));
    final Map<String, Object> stored = await SharedPreferencesStorePlatform.instance.getAll();
    SharedPreferencesStorePlatform.instance = _FailingDayNightPathStore(stored);
    SharedPreferences.resetStatic();
    await SharedPreferences.getInstance();

    await expectLater(repository.unpublish(), throwsStateError);

    expect(await snapshot(), isNull);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });

  test('publish uses the downloaded original for a protected wall', () async {
    final File original = File(path.join(root.path, 'documents', 'PrismDownloads', 'locked.jpg'));
    DayNightRepositoryImpl.downloadedOriginalOverride = (DayNightWall wall) async => original;

    await repository.publish(DayNightPair(day: _protected, night: _httpsNight));

    expect(
      await snapshot(),
      '{"dayStart":420,"nightStart":1140,'
      '"day":{"id":"locked","asset":"original:prism_locked"},'
      '"night":{"id":"night","url":"https://example.com/night.jpg"}}',
    );
    final String? paths = (await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight');
    expect(jsonDecode(paths!), <String, Object?>{
      'original:prism_locked': 'locked.jpg',
      'https://example.com/night.jpg': 'copy-0.jpg',
    });
  });

  test('publish with a protected wall and no downloaded original throws and writes no snapshot', () async {
    DayNightRepositoryImpl.downloadedOriginalOverride = (DayNightWall wall) async => null;

    await expectLater(
      repository.publish(DayNightPair(day: _httpsDay, night: _protected)),
      throwsA(
        isA<DayNightPrepareException>()
            .having((e) => e.failure, 'failure', DayNightPrepareFailure.needsDownload)
            .having((e) => e.slot, 'slot', DayNightSlot.night),
      ),
    );

    expect(await snapshot(), isNull);
  });

  test('unpublish removes the snapshot', () async {
    await repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));

    await repository.unpublish();

    expect(await snapshot(), isNull);
  });

  group('Android', () {
    late List<String> hostCalls;
    late List<pigeon.DailyScheduleRequestData> scheduleRequests;

    setUp(() {
      hostCalls = <String>[];
      scheduleRequests = <pigeon.DailyScheduleRequestData>[];
      DayNightRepositoryImpl.runsOnDeviceOverride = true;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      DayNightRepositoryImpl.runsOnDeviceOverride = null;
      debugDefaultTargetPlatformOverride = null;
    });

    void mockApply(pigeon.DailyScheduleApplyOutcomeData outcome, int? entryIndex) {
      _mockHostMethod('applyCurrentScheduleEntry', (ByteData? message) async {
        hostCalls.add('applyCurrentScheduleEntry');
        return _codec.encodeMessage(<Object?>[
          pigeon.DailyScheduleApplyResultData(outcome: outcome, entryIndex: entryIndex),
        ]);
      });
    }

    test('publish starts the device schedule with the day wall at 07:00 and the night wall at 19:00', () async {
      _mockHostMethod('startDailySchedule', (ByteData? message) async {
        hostCalls.add('startDailySchedule');
        scheduleRequests.add((_codec.decodeMessage(message)! as List).single as pigeon.DailyScheduleRequestData);
        return _codec.encodeMessage(<Object?>[true]);
      });

      await repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight));

      expect(hostCalls, <String>['startDailySchedule']);
      final pigeon.DailyScheduleRequestData request = scheduleRequests.single;
      expect(request.target, pigeon.WallpaperTargetData.both);
      expect(request.entries?.map((e) => e?.minuteOfDay).toList(), <int?>[420, 1140]);
      expect(request.entries?.map((e) => e?.source?.sourceType).toList(), <pigeon.RotationSourceTypeData?>[
        pigeon.RotationSourceTypeData.url,
        pigeon.RotationSourceTypeData.url,
      ]);
      expect(request.entries?.map((e) => e?.source?.source).toList(), <String?>[
        'https://example.com/day.jpg',
        'https://example.com/night.jpg',
      ]);
    });

    test('publish throws offlineCopyFailed when the host reports false', () async {
      _mockHostMethod('startDailySchedule', (ByteData? message) async {
        hostCalls.add('startDailySchedule');
        return _codec.encodeMessage(<Object?>[false]);
      });

      await expectLater(
        repository.publish(DayNightPair(day: _httpsDay, night: _httpsNight)),
        throwsA(
          isA<DayNightPrepareException>().having((e) => e.failure, 'failure', DayNightPrepareFailure.offlineCopyFailed),
        ),
      );
      expect(hostCalls, <String>['startDailySchedule']);
    });

    test('publish throws needsDownload for a protected wall with no original and starts no schedule', () async {
      DayNightRepositoryImpl.downloadedOriginalOverride = (DayNightWall wall) async => null;
      _mockHostMethod('startDailySchedule', (ByteData? message) async {
        hostCalls.add('startDailySchedule');
        return _codec.encodeMessage(<Object?>[true]);
      });

      await expectLater(
        repository.publish(DayNightPair(day: _httpsDay, night: _protected)),
        throwsA(
          isA<DayNightPrepareException>()
              .having((e) => e.failure, 'failure', DayNightPrepareFailure.needsDownload)
              .having((e) => e.slot, 'slot', DayNightSlot.night),
        ),
      );
      expect(hostCalls, isEmpty);
    });

    test('publish sends the downloaded original as a file source for a protected wall', () async {
      final File original = File(path.join(root.path, 'documents', 'PrismDownloads', 'locked.jpg'));
      DayNightRepositoryImpl.downloadedOriginalOverride = (DayNightWall wall) async => original;
      _mockHostMethod('startDailySchedule', (ByteData? message) async {
        hostCalls.add('startDailySchedule');
        scheduleRequests.add((_codec.decodeMessage(message)! as List).single as pigeon.DailyScheduleRequestData);
        return _codec.encodeMessage(<Object?>[true]);
      });

      await repository.publish(DayNightPair(day: _httpsDay, night: _protected));

      final pigeon.DailyScheduleRequestData request = scheduleRequests.single;
      expect(request.entries?.map((e) => e?.minuteOfDay).toList(), <int?>[420, 1140]);
      expect(request.entries?.last?.source?.sourceType, pigeon.RotationSourceTypeData.file);
      expect(request.entries?.last?.source?.source, original.path);
    });

    test('unpublish sends stopDailySchedule', () async {
      _mockHostMethod('stopDailySchedule', (ByteData? message) async {
        hostCalls.add('stopDailySchedule');
        return _codec.encodeMessage(<Object?>[true]);
      });

      await repository.unpublish();

      expect(hostCalls, <String>['stopDailySchedule']);
    });

    test('applyOnOpen reports an applied night wall as an app-open switch', () async {
      mockApply(pigeon.DailyScheduleApplyOutcomeData.applied, 1);

      expect(await repository.applyOnOpen(), (
        running: true,
        switched: (slot: DayNightSlot.night, source: DayNightSwitchSource.appOpen),
      ));
      expect(hostCalls, <String>['applyCurrentScheduleEntry']);
    });

    test('applyOnOpen reports an alarm switch to the day wall when the last seen slot was night', () async {
      await SettingsLocalDataSource(store).set('dayNight.lastSlot', 'night');
      mockApply(pigeon.DailyScheduleApplyOutcomeData.alreadyCurrent, 0);

      expect(await repository.applyOnOpen(), (
        running: true,
        switched: (slot: DayNightSlot.day, source: DayNightSwitchSource.alarm),
      ));
    });

    test('applyOnOpen reports no switch when already current and the last seen slot matches', () async {
      await SettingsLocalDataSource(store).set('dayNight.lastSlot', 'day');
      mockApply(pigeon.DailyScheduleApplyOutcomeData.alreadyCurrent, 0);

      expect(await repository.applyOnOpen(), (running: true, switched: null));
    });

    test('applyOnOpen reports not running when the device schedule is gone', () async {
      mockApply(pigeon.DailyScheduleApplyOutcomeData.notRunning, null);

      expect(await repository.applyOnOpen(), (running: false, switched: null));
    });

    test('applyOnOpen reports not running when the host fails to apply', () async {
      mockApply(pigeon.DailyScheduleApplyOutcomeData.failed, null);

      expect(await repository.applyOnOpen(), (running: false, switched: null));
    });
  });
}
