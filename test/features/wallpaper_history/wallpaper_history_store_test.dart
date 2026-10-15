import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

AppliedWallpaper _item(String url, {String target = 'home', required DateTime at}) => AppliedWallpaper(
  id: '${at.microsecondsSinceEpoch}',
  source: 'prism',
  thumbnailUrl: url,
  fullUrl: url,
  target: target,
  appliedAt: at,
);

void main() {
  late InMemoryLocalStore backing;
  late WallpaperHistoryStore store;
  final DateTime t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    backing = InMemoryLocalStore();
    store = WallpaperHistoryStore(SettingsLocalDataSource(backing));
  });

  test('starts empty', () {
    expect(store.items(), isEmpty);
  });

  test('keeps newest first', () async {
    await store.record(_item('a', at: t0));
    await store.record(_item('b', at: t0.add(const Duration(minutes: 5))));
    await store.record(_item('c', at: t0.add(const Duration(minutes: 10))));
    expect(store.items().map((i) => i.fullUrl), ['c', 'b', 'a']);
  });

  test('moves a repeat of the same url and target within one minute to the top instead of adding a row', () async {
    await store.record(_item('a', at: t0));
    await store.record(_item('b', at: t0.add(const Duration(seconds: 10))));
    final String id = await store.record(_item('a', at: t0.add(const Duration(seconds: 30))));
    expect(store.items().map((i) => i.fullUrl), ['a', 'b']);
    expect(store.items().first.id, id);
    expect(store.items().first.appliedAt, t0.add(const Duration(seconds: 30)));
  });

  test('record returns the id of the new row', () async {
    final String id = await store.record(_item('a', at: t0));
    expect(store.items().single.id, id);
  });

  test('keeps the same url on another target or after a minute', () async {
    await store.record(_item('a', at: t0));
    await store.record(_item('a', target: 'lock', at: t0.add(const Duration(seconds: 30))));
    await store.record(_item('a', at: t0.add(const Duration(minutes: 2))));
    expect(store.items(), hasLength(3));
  });

  test('caps the list at 100 and drops the oldest', () async {
    for (int i = 0; i < 105; i++) {
      await store.record(_item('wall$i', at: t0.add(Duration(minutes: 2 * i))));
    }
    final List<AppliedWallpaper> items = store.items();
    expect(items, hasLength(wallpaperHistoryLimit));
    expect(items.first.fullUrl, 'wall104');
    expect(items.last.fullUrl, 'wall5');
  });

  test('persists under the history key and survives a new store instance', () async {
    await store.record(_item('a', at: t0));
    expect(backing.data.containsKey(PersistenceKeys.settings(PersistenceKeys.wallpaperHistoryItems)), isTrue);
    final WallpaperHistoryStore reopened = WallpaperHistoryStore(SettingsLocalDataSource(backing));
    expect(reopened.items().single.fullUrl, 'a');
    expect(reopened.items().single.appliedAt.toUtc(), t0);
  });

  test('remove deletes one row and keeps the rest', () async {
    await store.record(_item('a', at: t0));
    await store.record(_item('b', at: t0.add(const Duration(minutes: 5))));
    await store.remove(store.items().last.id);
    expect(store.items().map((i) => i.fullUrl), ['b']);
    expect(WallpaperHistoryStore(SettingsLocalDataSource(backing)).items().map((i) => i.fullUrl), ['b']);
  });

  test('remove ignores an unknown id', () async {
    await store.record(_item('a', at: t0));
    await store.remove('missing');
    expect(store.items(), hasLength(1));
  });

  group('currentFor', () {
    test('is null before anything was set', () {
      expect(store.currentFor('home'), isNull);
      expect(store.currentFor('lock'), isNull);
    });

    test('is the newest row for the screen', () async {
      await store.record(_item('a', at: t0));
      await store.record(_item('b', target: 'lock', at: t0.add(const Duration(minutes: 5))));
      await store.record(_item('c', at: t0.add(const Duration(minutes: 10))));
      expect(store.currentFor('home')?.fullUrl, 'c');
      expect(store.currentFor('lock')?.fullUrl, 'b');
    });

    test('a both row counts for each screen until a newer row replaces it', () async {
      await store.record(_item('a', target: 'both', at: t0));
      expect(store.currentFor('home')?.fullUrl, 'a');
      expect(store.currentFor('lock')?.fullUrl, 'a');
      await store.record(_item('b', target: 'lock', at: t0.add(const Duration(minutes: 5))));
      expect(store.currentFor('home')?.fullUrl, 'a');
      expect(store.currentFor('lock')?.fullUrl, 'b');
    });
  });

  test('clear empties the list', () async {
    await store.record(_item('a', at: t0));
    await store.clear();
    expect(store.items(), isEmpty);
    expect(WallpaperHistoryStore(SettingsLocalDataSource(backing)).items(), isEmpty);
  });

  test('ignores corrupt stored data', () async {
    await backing.set(PersistenceKeys.settings(PersistenceKeys.wallpaperHistoryItems), 'not json');
    expect(store.items(), isEmpty);
    await backing.set(PersistenceKeys.settings(PersistenceKeys.wallpaperHistoryItems), '[1, {"id": "x"}]');
    expect(WallpaperHistoryStore(SettingsLocalDataSource(backing)).items(), isEmpty);
  });
}
