import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _Firestore extends Fake implements FirestoreClient {}

class _OfflineFirestore extends Fake implements FirestoreClient {
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) =>
      Future<List<T>>.error(StateError('offline'));

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) async {}
}

AppliedWallpaper _item(String id, DateTime at) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: '/t/$id.png',
  fullUrl: '/f/$id.png',
  target: 'home',
  appliedAt: at,
);

AppliedWallpaper _localSet(String id, DateTime at) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: 'https://example.com/$id-thumb.jpg',
  fullUrl: 'https://example.com/$id.jpg',
  target: 'home',
  appliedAt: at,
  wallpaperId: id,
);

HistoryWall _synced(WallpaperSource source, String id, DateTime at, {HistoryAction action = HistoryAction.download}) =>
    HistoryWall.tryCreate(
      id: id,
      source: source,
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
      action: action,
      at: at,
    )!;

void main() {
  late SettingsLocalDataSource settings;
  late WallpaperHistoryStore store;
  late SyncedHistoryStore synced;
  late RecentlyViewedStore viewed;

  WallpaperHistoryBloc build() => WallpaperHistoryBloc(store, synced, viewed);

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = WallpaperHistoryStore(settings);
    synced = SyncedHistoryStore(settings, _Firestore(), ownerId: () => '');
    viewed = RecentlyViewedStore(settings);
  });

  test('an offline clear keeps both lists and reports the failure', () async {
    final SyncedHistoryStore online = SyncedHistoryStore(settings, _OfflineFirestore(), ownerId: () => 'u1');
    await store.record(_localSet('p1', DateTime.utc(2026, 10, 20, 8)));
    await online.record(_synced(WallpaperSource.wallhaven, 'w1', DateTime.utc(2026, 10, 20, 9)));
    final WallpaperHistoryBloc bloc = WallpaperHistoryBloc(store, online, viewed);
    addTearDown(bloc.close);

    expect(await bloc.clearSetAndDownloaded(), isFalse);

    expect(store.items().map((item) => item.id), <String>['p1']);
    expect(online.items().map((wall) => wall.key), <String>['wallhaven_w1']);
  });

  test('starts with no items', () {
    expect(build().state.items, isEmpty);
  });

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'started loads the stored items, newest first',
    setUp: () async {
      await store.record(_item('a', DateTime(2026, 1, 1, 9)));
      await store.record(_item('b', DateTime(2026, 1, 2, 9)));
    },
    build: build,
    act: (bloc) => bloc.add(const WallpaperHistoryEvent.started()),
    verify: (bloc) => expect(bloc.state.items.map((item) => item.id), <String>['b', 'a']),
  );

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'started again picks up a wallpaper recorded since',
    build: build,
    act: (bloc) async {
      bloc.add(const WallpaperHistoryEvent.started());
      await store.record(_item('c', DateTime(2026, 1, 3, 9)));
      bloc.add(const WallpaperHistoryEvent.started());
    },
    verify: (bloc) => expect(bloc.state.items.map((item) => item.id), <String>['c']),
  );

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'cleared empties the store and the state',
    setUp: () => store.record(_item('a', DateTime(2026, 1, 1, 9))),
    build: build,
    act: (bloc) => bloc
      ..add(const WallpaperHistoryEvent.started())
      ..add(const WallpaperHistoryEvent.cleared()),
    verify: (bloc) {
      expect(bloc.state.items, isEmpty);
      expect(store.items(), isEmpty);
    },
  );

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'removed deletes one row and restored puts it back',
    setUp: () async {
      await store.record(_item('a', DateTime(2026, 1, 1, 9)));
      await store.record(_item('b', DateTime(2026, 1, 2, 9)));
    },
    build: build,
    act: (bloc) async {
      bloc.add(const WallpaperHistoryEvent.started());
      bloc.add(const WallpaperHistoryEvent.removed('b'));
      await Future<void>.delayed(Duration.zero);
      expect(store.items().map((item) => item.id), <String>['a']);
      bloc.add(WallpaperHistoryEvent.restored(_item('b', DateTime(2026, 1, 2, 9))));
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) => expect(bloc.state.items.map((item) => item.id), <String>['b', 'a']),
  );

  for (final String invalidation in ['clear', 'account session']) {
    test('Undo cannot restore a removed wallpaper after $invalidation', () async {
      final wall = _localSet('a', DateTime(2026));
      await store.record(wall);
      await synced.record(_synced(WallpaperSource.prism, 'a', wall.appliedAt));
      final bloc = build();
      addTearDown(bloc.close);
      bloc.add(const WallpaperHistoryEvent.started());
      await bloc.stream.first;
      bloc.add(const WallpaperHistoryEvent.removed('a'));
      await bloc.stream.first;
      if (invalidation == 'clear') {
        bloc.add(const WallpaperHistoryEvent.cleared());
        await pumpEventQueue();
      } else {
        await synced.clearLocal();
      }
      await bloc.restore(wall);
      await pumpEventQueue();
      expect(store.items(), isEmpty);
      expect(synced.items(), isEmpty);
      expect(bloc.state.items, isEmpty);
    });
  }

  group('synced history', () {
    final DateTime localAt = DateTime(2026, 1, 3, 9);
    final DateTime wallhavenAt = DateTime(2026, 1, 2, 9);

    Future<void> seed() async {
      await store.record(_localSet('p1', localAt));
      await synced.record(_synced(WallpaperSource.prism, 'p1', localAt));
      await synced.record(_synced(WallpaperSource.wallhaven, 'w1', wallhavenAt));
    }

    blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
      'started shows a synced wall with a local set once, and a synced-only download as a row',
      setUp: seed,
      build: build,
      act: (bloc) => bloc.add(const WallpaperHistoryEvent.started()),
      verify: (bloc) {
        expect(bloc.state.items.map((item) => item.id), <String>['p1', 'synced:wallhaven_w1']);
        final AppliedWallpaper download = bloc.state.items.last;
        expect(download.target, 'download');
        expect(download.fullUrl, isEmpty);
      },
    );

    blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
      'removed takes the local set and its synced entry away',
      setUp: seed,
      build: build,
      act: (bloc) => bloc
        ..add(const WallpaperHistoryEvent.started())
        ..add(const WallpaperHistoryEvent.removed('p1')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(store.items(), isEmpty);
        expect(synced.items().map((wall) => wall.key), <String>['wallhaven_w1']);
        expect(bloc.state.items.map((item) => item.id), <String>['synced:wallhaven_w1']);
      },
    );

    blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
      'restored after removed puts the local set and its synced entry back',
      setUp: seed,
      build: build,
      act: (bloc) async {
        bloc
          ..add(const WallpaperHistoryEvent.started())
          ..add(const WallpaperHistoryEvent.removed('p1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(WallpaperHistoryEvent.restored(_localSet('p1', localAt)));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(store.items().map((item) => item.id), <String>['p1']);
        expect(synced.items().map((wall) => wall.key), containsAll(<String>['prism_p1', 'wallhaven_w1']));
        expect(bloc.state.items.map((item) => item.id), <String>['p1', 'synced:wallhaven_w1']);
      },
    );
  });

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'viewedCleared empties the recently viewed list',
    setUp: () =>
        viewed.record(_synced(WallpaperSource.prism, 'v1', DateTime(2026, 1, 1, 9), action: HistoryAction.view)),
    build: build,
    act: (bloc) => bloc
      ..add(const WallpaperHistoryEvent.started())
      ..add(const WallpaperHistoryEvent.viewedCleared()),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.viewed, isEmpty);
      expect(viewed.items(), isEmpty);
    },
  );

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'viewingTurnedOn turns Save viewing history back on',
    setUp: () => viewed.setEnabled(false),
    build: build,
    act: (bloc) => bloc
      ..add(const WallpaperHistoryEvent.started())
      ..add(const WallpaperHistoryEvent.viewingTurnedOn()),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.viewingHistoryOn, isTrue);
      expect(viewed.enabled, isTrue);
    },
  );
}
