import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

AppliedWallpaper _item(String id, DateTime at) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: '/t/$id.png',
  fullUrl: '/f/$id.png',
  target: 'home',
  appliedAt: at,
);

void main() {
  late WallpaperHistoryStore store;

  setUp(() => store = WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore())));

  test('starts with no items', () {
    expect(WallpaperHistoryBloc(store).state.items, isEmpty);
  });

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'started loads the stored items, newest first',
    setUp: () async {
      await store.record(_item('a', DateTime(2026, 1, 1, 9)));
      await store.record(_item('b', DateTime(2026, 1, 2, 9)));
    },
    build: () => WallpaperHistoryBloc(store),
    act: (bloc) => bloc.add(const WallpaperHistoryEvent.started()),
    verify: (bloc) => expect(bloc.state.items.map((item) => item.id), <String>['b', 'a']),
  );

  blocTest<WallpaperHistoryBloc, WallpaperHistoryState>(
    'started again picks up a wallpaper recorded since',
    build: () => WallpaperHistoryBloc(store),
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
    build: () => WallpaperHistoryBloc(store),
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
    build: () => WallpaperHistoryBloc(store),
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
}
