import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/data/repositories/day_night_repository_impl.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

const String _snapshotKey = 'shortcuts.day_night';

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
  _FakeOfflineStore(this.root);

  final Directory root;
  final Map<String, String> retained = <String, String>{};

  @override
  Future<File> retain(String source, {File? file}) async {
    final String absolute = path.join(root.path, 'prism', 'offline', 'assets', 'copy-${retained.length}.jpg');
    retained[source] = absolute;
    return File(absolute);
  }

  @override
  Future<Map<String, String>> localPaths() async => retained;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late InMemoryLocalStore store;
  late DayNightRepositoryImpl repository;

  setUp(() async {
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
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    OfflineAssetStore.testOverride = null;
    NativeAssetPathsStore.supportDirectoryOverride = null;
    NativeAssetPathsStore.documentsDirectoryOverride = null;
    DayNightRepositoryImpl.downloadedOriginalOverride = null;
    if (await root.exists()) await root.delete(recursive: true);
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
}
