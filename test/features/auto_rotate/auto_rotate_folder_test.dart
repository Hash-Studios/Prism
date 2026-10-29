import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

const String _wallhaven = 'https://w.wallhaven.cc/full/ab/wallhaven-ab12cd.jpg';
const String _pexels = 'https://images.pexels.com/photos/1/x.jpeg';
const String _prism = 'https://cdn.prismwalls.com/originals/p1.jpg';

const List<String> _folderUrls = <String>[
  'https://w.wallhaven.cc/full/aa/wallhaven-aa1.jpg',
  'https://w.wallhaven.cc/full/bb/wallhaven-bb2.jpg',
  'https://w.wallhaven.cc/full/cc/wallhaven-cc3.jpg',
];

const AutoRotateConfig _folderConfig = AutoRotateConfig(
  enabled: true,
  source: AutoRotateSource.folder,
  folderId: 'f1',
  folderName: 'Calm',
  intervalMinutes: 60,
);

class _MockWalls extends Mock implements PrismWallpaperRepository {}

class _MockWotd extends Mock implements WallOfTheDayRepository {}

class _MockFolders extends Mock implements FoldersRepository {}

class _FakeFolderRepository implements AutoRotateRepository {
  AutoRotateConfig config = const AutoRotateConfig();
  AutoRotateStatus statusValue = const AutoRotateStatus();
  List<String>? applied;
  ({bool found, List<String> urls})? folder;
  int folderLoads = 0;
  int stops = 0;
  final List<(AutoRotateConfig, List<String>)> starts = <(AutoRotateConfig, List<String>)>[];

  @override
  Future<AutoRotateConfig> loadConfig({String? ownerId}) async => config;

  @override
  Future<void> saveConfig(AutoRotateConfig config, {String? ownerId}) async => this.config = config;

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    starts.add((config, imageUrls));
    applied = imageUrls;
    statusValue = AutoRotateStatus(
      isRunning: true,
      nextRunEpochMs: 1,
      cachedCount: imageUrls.length,
      totalCount: imageUrls.length,
    );
    return true;
  }

  @override
  Future<bool> stop() async {
    stops++;
    applied = null;
    statusValue = const AutoRotateStatus();
    return true;
  }

  @override
  Future<AutoRotateStatus> status() async => statusValue;

  @override
  Future<bool> rotateNow() async => true;

  @override
  Future<List<String>?> loadAppliedSources() async => applied;

  @override
  Future<List<String>> listDownloads() async => const <String>[];

  @override
  Future<List<String>?> loadRemoteUrls(AutoRotateSource source, {String? category}) async => const <String>[];

  @override
  Future<({bool found, List<String> urls})?> loadFolderUrls(String folderId, {required String userId}) async {
    folderLoads++;
    return folder;
  }

  @override
  Future<Set<WallpaperTarget>> supportedTargets() async => WallpaperTarget.values.toSet();

  @override
  Future<bool> consumeBatteryTip() async => false;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  group('repository loadFolderUrls', () {
    late _MockFolders folders;
    late AutoRotateRepositoryImpl repository;

    setUp(() {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      folders = _MockFolders();
      repository = AutoRotateRepositoryImpl(
        settings,
        _MockWalls(),
        _MockWotd(),
        WallpaperHistoryStore(settings),
        folders,
      );
    });

    test('keeps the safe walls in order and drops the Prism original', () async {
      when(() => folders.fetchItems('f1', userId: 'u1', limit: 100)).thenAnswer(
        (_) async => Result.success<List<FavouriteWallEntity>?>(<FavouriteWallEntity>[
          WallhavenFavouriteWall(
            id: 'wh1',
            wallpaper: WallhavenWallpaper(
              core: WallpaperCore(id: 'wh1', source: WallpaperSource.wallhaven, fullUrl: _wallhaven, thumbnailUrl: ''),
            ),
          ),
          PexelsFavouriteWall(
            id: 'px1',
            wallpaper: PexelsWallpaper(
              core: WallpaperCore(id: 'px1', source: WallpaperSource.pexels, fullUrl: _pexels, thumbnailUrl: ''),
            ),
          ),
          PrismFavouriteWall(
            id: 'p1',
            wallpaper: PrismWallpaper(
              core: WallpaperCore(id: 'p1', source: WallpaperSource.prism, fullUrl: _prism, thumbnailUrl: ''),
            ),
          ),
        ]),
      );

      final result = await repository.loadFolderUrls('f1', userId: 'u1');

      expect(result?.found, isTrue);
      expect(result?.urls, <String>[_wallhaven, _pexels]);
    });

    test('a folder that is gone is found false with no walls', () async {
      when(
        () => folders.fetchItems('f1', userId: 'u1', limit: 100),
      ).thenAnswer((_) async => Result.success<List<FavouriteWallEntity>?>(null));

      final result = await repository.loadFolderUrls('f1', userId: 'u1');

      expect(result?.found, isFalse);
      expect(result?.urls, isEmpty);
    });

    test('a failed read returns null', () async {
      when(
        () => folders.fetchItems('f1', userId: 'u1', limit: 100),
      ).thenAnswer((_) async => Result.error<List<FavouriteWallEntity>?>(const NetworkFailure('offline')));

      expect(await repository.loadFolderUrls('f1', userId: 'u1'), isNull);
    });

    test('an empty folder is found with no walls', () async {
      when(
        () => folders.fetchItems('f1', userId: 'u1', limit: 100),
      ).thenAnswer((_) async => Result.success<List<FavouriteWallEntity>?>(<FavouriteWallEntity>[]));

      final result = await repository.loadFolderUrls('f1', userId: 'u1');

      expect(result?.found, isTrue);
      expect(result?.urls, isEmpty);
    });
  });

  group('config folder keys', () {
    late AutoRotateRepositoryImpl repository;
    late SettingsLocalDataSource settings;

    setUp(() {
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      repository = AutoRotateRepositoryImpl(
        settings,
        _MockWalls(),
        _MockWotd(),
        WallpaperHistoryStore(settings),
        _MockFolders(),
      );
    });

    test('a saved folder config loads back with its id and name', () async {
      await repository.saveConfig(
        const AutoRotateConfig(enabled: true, source: AutoRotateSource.folder, folderId: 'f1', folderName: 'Calm'),
      );

      final AutoRotateConfig loaded = await repository.loadConfig();

      expect(loaded.source, AutoRotateSource.folder);
      expect(loaded.folderId, 'f1');
      expect(loaded.folderName, 'Calm');
    });

    test('an old store with no folder keys loads with no folder', () async {
      final AutoRotateConfig loaded = await repository.loadConfig();

      expect(loaded.folderId, isNull);
      expect(loaded.folderName, '');
    });

    test('a folder source with no folder id loads as favourites', () async {
      await settings.set('autoRotate.source', 'folder');

      final AutoRotateConfig loaded = await repository.loadConfig();

      expect(loaded.source, AutoRotateSource.favourites);
      expect(loaded.folderId, isNull);
    });
  });

  group('bloc folder source', () {
    late _FakeFolderRepository repository;
    late AutoRotateBloc bloc;

    setUp(() {
      AnalyticsRuntime.instance = FakeAppAnalytics();
      repository = _FakeFolderRepository();
      bloc = AutoRotateBloc(repository);
      bloc.favouritesDebounce = Duration.zero;
    });

    tearDown(() async {
      await bloc.close();
      AnalyticsRuntime.reset();
    });

    Future<void> openAsPro({List<String> favourites = const <String>[]}) async {
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'u1'));
      bloc.add(AutoRotateEvent.started(favouriteUrls: favourites, isPro: true));
      await _settle();
    }

    test('choosing a folder saves it and starts the rotation with its walls', () async {
      repository.config = const AutoRotateConfig(enabled: true);
      repository.folder = (found: true, urls: _folderUrls);
      await openAsPro(favourites: <String>['https://example.com/fav0.jpg', 'https://example.com/fav1.jpg']);

      bloc.add(const AutoRotateEvent.folderChosen(folderId: 'f1', name: 'Calm'));
      await _settle();

      expect(repository.starts, hasLength(2));
      expect(repository.starts.last.$2, _folderUrls);
      expect(repository.config.source, AutoRotateSource.folder);
      expect(repository.config.folderId, 'f1');
    });

    test('a folder change with the same walls does not restart the rotation', () async {
      repository.config = _folderConfig;
      repository.applied = _folderUrls;
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);
      repository.folder = (found: true, urls: _folderUrls);
      await openAsPro();
      expect(repository.starts, isEmpty);

      bloc.add(const AutoRotateEvent.folderChanged(folderId: 'f1', name: 'Calm'));
      await _settle();
      expect(repository.starts, isEmpty);

      repository.folder = (
        found: true,
        urls: <String>[..._folderUrls, 'https://w.wallhaven.cc/full/dd/wallhaven-dd4.jpg'],
      );
      bloc.add(const AutoRotateEvent.folderChanged(folderId: 'f1', name: 'Calm'));
      await _settle();
      expect(repository.starts, hasLength(1));
      expect(repository.starts.single.$2, <String>[..._folderUrls, 'https://w.wallhaven.cc/full/dd/wallhaven-dd4.jpg']);

      bloc.add(const AutoRotateEvent.folderChanged(folderId: 'f1', name: 'Calm'));
      await _settle();
      expect(repository.starts, hasLength(1));
    });

    test('a deleted folder turns the rotation off and says why until acknowledged', () async {
      repository.config = _folderConfig;
      repository.applied = _folderUrls;
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);
      repository.folder = (found: true, urls: _folderUrls);
      await openAsPro();

      repository.folder = (found: false, urls: const <String>[]);
      bloc.add(const AutoRotateEvent.folderChanged(folderId: 'f1'));
      await _settle();

      expect(repository.stops, 1);
      expect(bloc.state.config.enabled, isFalse);
      expect(bloc.state.config.source, AutoRotateSource.favourites);
      expect(bloc.state.config.folderId, isNull);
      expect(bloc.state.config.intervalMinutes, 60);
      expect(bloc.state.folderStop, (reason: AutoRotateStopReason.folderDeleted, folderName: 'Calm'));

      bloc.add(const AutoRotateEvent.folderStopAcknowledged());
      await _settle();

      expect(bloc.state.folderStop, isNull);
    });

    test('a folder emptied to one wall turns the rotation off and keeps the folder', () async {
      repository.config = _folderConfig;
      repository.applied = _folderUrls;
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);
      repository.folder = (found: true, urls: _folderUrls);
      await openAsPro();

      repository.folder = (found: true, urls: const <String>['https://w.wallhaven.cc/full/aa/wallhaven-aa1.jpg']);
      bloc.add(const AutoRotateEvent.folderChanged(folderId: 'f1', name: 'Calm'));
      await _settle();

      expect(repository.stops, 1);
      expect(bloc.state.folderStop?.reason, AutoRotateStopReason.folderEmpty);
      expect(bloc.state.config.source, AutoRotateSource.folder);
      expect(bloc.state.config.folderId, 'f1');
    });

    test('a failed folder load keeps the running rotation', () async {
      repository.config = _folderConfig;
      repository.applied = _folderUrls;
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);
      repository.folder = (found: true, urls: _folderUrls);
      await openAsPro();

      repository.folder = null;
      bloc.add(const AutoRotateEvent.folderChanged(folderId: 'f1', name: 'Calm'));
      await _settle();

      expect(repository.folderLoads, greaterThan(1));
      expect(repository.stops, 0);
      expect(repository.starts, isEmpty);
      expect(bloc.state.status.isRunning, isTrue);
    });
  });
}
