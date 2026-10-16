import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _GatedFirstWriteStore extends InMemorySharedPreferencesStore {
  _GatedFirstWriteStore() : super.empty();

  final Completer<void> firstWriteGate = Completer<void>();
  final Completer<void> firstWriteStarted = Completer<void>();
  bool _gated = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_gated) {
      _gated = true;
      firstWriteStarted.complete();
      await firstWriteGate.future;
    }
    return super.setValue(valueType, key, value);
  }
}

FavouriteWallEntity _wall(String id, {String? url, DateTime? at}) => LegacyFavouriteWall(
  id: id,
  source: WallpaperSource.prism,
  legacyPayload: <String, dynamic>{'url': url ?? 'https://example.com/$id.jpg'},
  favouritedAt: at,
);

List<Map<String, Object?>> _decode(String json) => (jsonDecode(json) as List<Object?>).cast<Map<String, Object?>>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encode', () {
    test('writes id and url objects, newest first', () {
      final List<Map<String, dynamic>> out = _decode(
        ShortcutsFavouritesStore.encode(<FavouriteWallEntity>[
          _wall('old', at: DateTime.utc(2026, 1, 5)),
          _wall('new', at: DateTime.utc(2026, 3, 5)),
          _wall('mid', at: DateTime.utc(2026, 2, 5)),
        ]),
      );
      expect(out, <Map<String, dynamic>>[
        <String, dynamic>{'id': 'new', 'url': 'https://example.com/new.jpg'},
        <String, dynamic>{'id': 'mid', 'url': 'https://example.com/mid.jpg'},
        <String, dynamic>{'id': 'old', 'url': 'https://example.com/old.jpg'},
      ]);
    });

    test('is an empty array with no favourites', () {
      expect(ShortcutsFavouritesStore.encode(const <FavouriteWallEntity>[]), '[]');
    });

    test('caps the list at 200 and keeps the newest', () {
      final DateTime base = DateTime.utc(2026, 1, 5);
      final List<FavouriteWallEntity> walls = <FavouriteWallEntity>[
        for (int i = 0; i < 250; i++) _wall('w$i', at: base.add(Duration(minutes: i))),
      ];
      final List<Map<String, dynamic>> out = _decode(ShortcutsFavouritesStore.encode(walls));
      expect(out, hasLength(ShortcutsFavouritesStore.maxItems));
      expect(out.first['id'], 'w249');
      expect(out.last['id'], 'w50');
    });

    test('leaves out walls without an id or an https url, and duplicates', () {
      final List<Map<String, dynamic>> out = _decode(
        ShortcutsFavouritesStore.encode(<FavouriteWallEntity>[
          _wall('ok'),
          _wall('ok'),
          _wall('plain', url: 'http://example.com/plain.jpg'),
          _wall('blank', url: ''),
          _wall(' '),
        ]),
      );
      expect(out.map((entry) => entry['id']), <String>['ok']);
    });
  });

  group('storage', () {
    test('save writes the raw string under the shared contract key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('a')]);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(PersistenceKeys.shortcutsFavourites, 'shortcuts.favourites');
      expect(prefs.getString('shortcuts.favourites'), '[{"id":"a","url":"https://example.com/a.jpg"}]');
    });

    test('clear writes an empty array', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.shortcutsFavourites: '[{"id":"a","url":"https://example.com/a.jpg"}]',
      });
      await ShortcutsFavouritesStore.clear();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), '[]');
    });

    test('a clear after a save that is already writing leaves an empty array', () async {
      final _GatedFirstWriteStore store = _GatedFirstWriteStore();
      SharedPreferencesStorePlatform.instance = store;
      SharedPreferences.resetStatic();

      final Future<void> save = ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('a')]);
      await store.firstWriteStarted.future;
      final Future<void> clear = ShortcutsFavouritesStore.clear();
      store.firstWriteGate.complete();
      await Future.wait(<Future<void>>[save, clear]);

      SharedPreferences.resetStatic();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), '[]');
    });

    test('a save that is still queued when a clear runs is dropped', () async {
      final _GatedFirstWriteStore store = _GatedFirstWriteStore();
      SharedPreferencesStorePlatform.instance = store;
      SharedPreferences.resetStatic();

      final Future<void> first = ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('a')]);
      await store.firstWriteStarted.future;
      final Future<void> queued = ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('b')]);
      final Future<void> clear = ShortcutsFavouritesStore.clear();
      store.firstWriteGate.complete();
      await Future.wait(<Future<void>>[first, queued, clear]);

      SharedPreferences.resetStatic();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), '[]');
    });

    test('a save called after a clear still writes', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ShortcutsFavouritesStore.clear();
      await ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('a')]);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), '[{"id":"a","url":"https://example.com/a.jpg"}]');
    });
  });
}
