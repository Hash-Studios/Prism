import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../../support/profile_user_fixture.dart';

class _GatedFirstWriteStore extends InMemorySharedPreferencesStore {
  _GatedFirstWriteStore() : super.empty();

  _GatedFirstWriteStore.withData(super.data) : super.withData();

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

  late Directory offlineDirectory;

  setUp(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    offlineDirectory = await Directory.systemTemp.createTemp('prism-shortcuts-assets-test');
    OfflineAssetStore.testOverride = OfflineAssetStore(
      directory: Directory('${offlineDirectory.path}/prism/offline/assets'),
    );
    ShortcutsFavouritesStore.supportDirectoryOverride = offlineDirectory;
  });

  tearDown(() async {
    OfflineAssetStore.testOverride = null;
    ShortcutsFavouritesStore.supportDirectoryOverride = null;
    if (await offlineDirectory.exists()) await offlineDirectory.delete(recursive: true);
  });

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
    test('account A cleanup leaves B native mirrors untouched when B is active', () async {
      app_state.prismUser = profileUser(id: 'owner-b', loggedIn: true);
      SharedPreferences.setMockInitialValues(<String, Object>{
        NativeAssetPathsStore.preferenceKey: '{"https://example.com/b.jpg":"assets/b.asset"}',
        '${NativeAssetPathsStore.preferenceKey}.favourites': '{"https://example.com/b.jpg":"assets/b.asset"}',
        '${NativeAssetPathsStore.preferenceKey}.shortcuts': '{"https://example.com/b.jpg":"assets/b.asset"}',
        PersistenceKeys.shortcutsFavourites: '[{"id":"b","url":"https://example.com/b.jpg"}]',
      });

      await NativeAssetPathsStore.clearForUser('owner-a');
      await ShortcutsFavouritesStore.clearForUser('owner-a');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(NativeAssetPathsStore.preferenceKey), contains('b.jpg'));
      expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.favourites'), contains('b.jpg'));
      expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.shortcuts'), contains('b.jpg'));
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), contains('b.jpg'));
    });

    test('account A cleanup preserves mirrors owned by B after sign-out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        NativeAssetPathsStore.privateOwnerKey: 'owner-b',
        '${NativeAssetPathsStore.preferenceKey}.favourites': '{"https://example.com/b.jpg":"assets/b.asset"}',
        '${NativeAssetPathsStore.preferenceKey}.shortcuts': '{"https://example.com/b.jpg":"assets/b.asset"}',
        PersistenceKeys.shortcutsFavourites: '[{"id":"b","url":"https://example.com/b.jpg"}]',
      });

      await NativeAssetPathsStore.clearForUser('owner-a');
      await ShortcutsFavouritesStore.clearForUser('owner-a');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.favourites'), contains('b.jpg'));
      expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.shortcuts'), contains('b.jpg'));
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), contains('b.jpg'));
    });

    test('a late private path mirror cannot land after an account clear', () async {
      app_state.prismUser = profileUser(id: 'owner-a');
      final _GatedFirstWriteStore store = _GatedFirstWriteStore.withData(<String, Object>{
        'flutter.${NativeAssetPathsStore.privateOwnerKey}': 'owner-a',
        'flutter.${NativeAssetPathsStore.preferenceKey}.wotd': '{"today":"assets/today.asset"}',
        'flutter.${NativeAssetPathsStore.preferenceKey}.category': '{"space":"assets/space.asset"}',
      });
      SharedPreferencesStorePlatform.instance = store;
      SharedPreferences.resetStatic();

      final Future<void> oldMirror = NativeAssetPathsStore.replaceGroup('shortcuts', const <String, String>{
        'https://example.com/private.jpg': 'assets/private.asset',
      });
      await store.firstWriteStarted.future;
      final Future<void> clear = NativeAssetPathsStore.clearForUser('owner-a');
      store.firstWriteGate.complete();
      await Future.wait(<Future<void>>[oldMirror, clear]);

      SharedPreferences.resetStatic();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(NativeAssetPathsStore.preferenceKey)!), <String, Object?>{
        'today': 'assets/today.asset',
        'space': 'assets/space.asset',
      });
      expect(jsonDecode(prefs.getString('${NativeAssetPathsStore.preferenceKey}.shortcuts')!), isEmpty);
      expect(jsonDecode(prefs.getString('${NativeAssetPathsStore.preferenceKey}.favourites')!), isEmpty);
    });

    test('save writes the raw string under the shared contract key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('a')]);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(PersistenceKeys.shortcutsFavourites, 'shortcuts.favourites');
      expect(prefs.getString('shortcuts.favourites'), '[{"id":"a","url":"https://example.com/a.jpg"}]');
    });

    test('save mirrors only committed retained files as container-relative paths', () async {
      final File source = File('${offlineDirectory.path}/wall.png')
        ..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      await OfflineAssetStore.instance.retain('https://example.com/a.jpg', file: source);
      await ShortcutsFavouritesStore.save(<FavouriteWallEntity>[_wall('a')]);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> shortcutsPaths =
          jsonDecode(prefs.getString('${ShortcutsFavouritesStore.nativeAssetPathsKey}.shortcuts')!)
              as Map<String, dynamic>;
      final Map<String, dynamic> nativePaths =
          jsonDecode(prefs.getString(ShortcutsFavouritesStore.nativeAssetPathsKey)!) as Map<String, dynamic>;
      expect(shortcutsPaths['https://example.com/a.jpg'], startsWith('assets/'));
      expect(nativePaths['https://example.com/a.jpg'], startsWith('assets/'));
      final List<Map<String, dynamic>> favouriteValues =
          (jsonDecode(prefs.getString(PersistenceKeys.shortcutsFavourites)!) as List<Object?>)
              .cast<Map<String, dynamic>>();
      expect(favouriteValues.single['url'], 'https://example.com/a.jpg');
    });

    test('clear writes an empty array', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.shortcutsFavourites: '[{"id":"a","url":"https://example.com/a.jpg"}]',
      });
      await ShortcutsFavouritesStore.clear();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFavourites), '[]');
      expect(prefs.getString(ShortcutsFavouritesStore.nativeAssetPathsKey), '{}');
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
