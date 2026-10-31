import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_folders_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/profile_user_fixture.dart';

FolderEntity _folder(String id, {DateTime? updatedAt, int itemCount = 1}) => FolderEntity(
  id: id,
  ownerId: 'owner-a',
  name: 'Folder $id',
  createdAt: DateTime.utc(2026),
  updatedAt: updatedAt ?? DateTime.utc(2026, 2),
  itemCount: itemCount,
  covers: const <String>[],
);

FavouriteWallEntity _wall(String id, {String? url}) => LegacyFavouriteWall(
  id: id,
  source: WallpaperSource.prism,
  legacyPayload: <String, dynamic>{'url': url ?? 'https://example.com/$id.jpg'},
);

class _FakeFetcher {
  _FakeFetcher([Map<String, List<FavouriteWallEntity>?>? walls])
    : walls = walls ?? <String, List<FavouriteWallEntity>?>{};

  final Map<String, List<FavouriteWallEntity>?> walls;
  final Set<String> failing = <String>{};
  final Map<String, int> calls = <String, int>{};

  Future<Result<List<FavouriteWallEntity>?>> call(String folderId) async {
    calls[folderId] = (calls[folderId] ?? 0) + 1;
    if (failing.contains(folderId)) return Result.error<List<FavouriteWallEntity>?>(const ServerFailure('boom'));
    return Result.success<List<FavouriteWallEntity>?>(walls[folderId]);
  }
}

Future<Map<String, dynamic>> _snapshot() async {
  final String? raw = (await SharedPreferences.getInstance()).getString(PersistenceKeys.shortcutsFolders);
  return jsonDecode(raw!) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _folderEntries(Map<String, dynamic> snapshot) =>
    (snapshot['folders'] as List<Object?>).cast<Map<String, dynamic>>();

List<String> _folderIds(Map<String, dynamic> snapshot) =>
    _folderEntries(snapshot).map((folder) => folder['id'] as String).toList();

Map<String, dynamic> _entry(Map<String, dynamic> snapshot, String id) =>
    _folderEntries(snapshot).singleWhere((folder) => folder['id'] == id);

List<String> _itemIds(Map<String, dynamic> folder) =>
    (folder['items'] as List<Object?>).cast<Map<String, dynamic>>().map((item) => item['id'] as String).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory offlineDirectory;

  setUp(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    offlineDirectory = await Directory.systemTemp.createTemp('prism-shortcuts-folders-test');
    OfflineAssetStore.testOverride = OfflineAssetStore(
      directory: Directory('${offlineDirectory.path}/prism/offline/assets'),
    );
    NativeAssetPathsStore.supportDirectoryOverride = offlineDirectory;
  });

  tearDown(() async {
    OfflineAssetStore.testOverride = null;
    NativeAssetPathsStore.supportDirectoryOverride = null;
    if (await offlineDirectory.exists()) await offlineDirectory.delete(recursive: true);
  });

  group('sync', () {
    test('writes owner, folders newest first, and items keyed by folderItemKey', () async {
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'new': <FavouriteWallEntity>[_wall('a'), _wall('a')],
        'old': <FavouriteWallEntity>[_wall('c')],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[
          _folder('old', updatedAt: DateTime.utc(2026, 1, 5), itemCount: 2),
          _folder('new', updatedAt: DateTime.utc(2026, 3, 5), itemCount: 3),
        ],
        fetchItems: fetcher.call,
      );

      final Map<String, dynamic> snapshot = await _snapshot();
      expect(snapshot['ownerId'], 'owner-a');
      expect(_folderIds(snapshot), <String>['new', 'old']);
      final Map<String, dynamic> newEntry = _entry(snapshot, 'new');
      expect(newEntry['name'], 'Folder new');
      expect(newEntry['itemCount'], 3);
      expect(newEntry['updatedAt'], DateTime.utc(2026, 3, 5).millisecondsSinceEpoch);
      expect(newEntry['items'], <Map<String, String>>[
        <String, String>{'id': folderItemKey(_wall('a')), 'url': 'https://example.com/a.jpg'},
      ]);
      expect(_entry(snapshot, 'old')['items'], <Map<String, String>>[
        <String, String>{'id': folderItemKey(_wall('c')), 'url': 'https://example.com/c.jpg'},
      ]);
    });

    test('leaves out walls with an http url or an empty id', () async {
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'f1': <FavouriteWallEntity>[
          _wall('ok'),
          _wall('plain', url: 'http://example.com/plain.jpg'),
          _wall('blank', url: ''),
          _wall(' '),
          _wall('again'),
        ],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1')],
        fetchItems: fetcher.call,
      );

      expect(_itemIds(_entry(await _snapshot(), 'f1')), <String>[
        folderItemKey(_wall('ok')),
        folderItemKey(_wall('again')),
      ]);
    });

    test('caps a folder at 200 items', () async {
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'f1': <FavouriteWallEntity>[for (int i = 0; i < 250; i++) _wall('w$i')],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1')],
        fetchItems: fetcher.call,
      );

      final List<String> ids = _itemIds(_entry(await _snapshot(), 'f1'));
      expect(ids, hasLength(ShortcutsFoldersStore.maxItems));
      expect(ids.first, folderItemKey(_wall('w0')));
      expect(ids.last, folderItemKey(_wall('w199')));
    });

    test('caps the snapshot at 50 folders', () async {
      final DateTime base = DateTime.utc(2026);
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[for (int i = 0; i < 60; i++) _folder('f$i', updatedAt: base.add(Duration(minutes: i)))],
        fetchItems: _FakeFetcher(<String, List<FavouriteWallEntity>?>{
          for (int i = 0; i < 60; i++) 'f$i': <FavouriteWallEntity>[_wall('w$i')],
        }).call,
      );

      expect(_folderIds(await _snapshot()), hasLength(ShortcutsFoldersStore.maxFolders));
    });

    test('keeps the rotation folder even when it is the oldest of 60', () async {
      final DateTime base = DateTime.utc(2026);
      await ShortcutsFoldersStore.setRotationFolder('f0');
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[for (int i = 0; i < 60; i++) _folder('f$i', updatedAt: base.add(Duration(minutes: i)))],
        fetchItems: _FakeFetcher(<String, List<FavouriteWallEntity>?>{
          for (int i = 0; i < 60; i++) 'f$i': <FavouriteWallEntity>[_wall('w$i')],
        }).call,
      );

      final List<String> ids = _folderIds(await _snapshot());
      expect(ids, hasLength(ShortcutsFoldersStore.maxFolders));
      expect(ids, contains('f0'));
      expect(await ShortcutsFoldersStore.rotationFolderId(), 'f0');
    });

    test('a folder with the same update time and count is not fetched again and keeps its items', () async {
      final DateTime at = DateTime.utc(2026, 2);
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'f1': <FavouriteWallEntity>[_wall('a'), _wall('b')],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: at, itemCount: 2)],
        fetchItems: fetcher.call,
      );
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: at, itemCount: 2)],
        fetchItems: fetcher.call,
      );

      expect(fetcher.calls['f1'], 1);
      expect(_itemIds(_entry(await _snapshot(), 'f1')), <String>[folderItemKey(_wall('a')), folderItemKey(_wall('b'))]);
    });

    test('a folder with a changed update time is fetched again', () async {
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'f1': <FavouriteWallEntity>[_wall('a')],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: DateTime.utc(2026, 2))],
        fetchItems: fetcher.call,
      );
      fetcher.walls['f1'] = <FavouriteWallEntity>[_wall('c')];
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: DateTime.utc(2026, 2, 2))],
        fetchItems: fetcher.call,
      );

      expect(fetcher.calls['f1'], 2);
      expect(_itemIds(_entry(await _snapshot(), 'f1')), <String>[folderItemKey(_wall('c'))]);
    });

    test('a failed fetch keeps the previous items and the next sync fetches the folder again', () async {
      final DateTime at = DateTime.utc(2026, 2);
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'f1': <FavouriteWallEntity>[_wall('a')],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: at)],
        fetchItems: fetcher.call,
      );

      fetcher.failing.add('f1');
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: at.add(const Duration(days: 1)))],
        fetchItems: fetcher.call,
      );
      final Map<String, dynamic> afterFailure = _entry(await _snapshot(), 'f1');
      expect(_itemIds(afterFailure), <String>[folderItemKey(_wall('a'))]);
      expect(afterFailure['updatedAt'], 0);

      fetcher.failing.clear();
      fetcher.walls['f1'] = <FavouriteWallEntity>[_wall('b')];
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1', updatedAt: at.add(const Duration(days: 1)))],
        fetchItems: fetcher.call,
      );

      expect(fetcher.calls['f1'], 3);
      expect(_itemIds(_entry(await _snapshot(), 'f1')), <String>[folderItemKey(_wall('b'))]);
    });

    test('a folder whose fetch returns null is left out', () async {
      final _FakeFetcher fetcher = _FakeFetcher(<String, List<FavouriteWallEntity>?>{
        'f1': <FavouriteWallEntity>[_wall('a')],
      });
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1'), _folder('gone')],
        fetchItems: fetcher.call,
      );

      expect(_folderIds(await _snapshot()), <String>['f1']);
    });

    test('removes a rotation folder that is no longer in the folders list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{PersistenceKeys.shortcutsRotationFolder: 'gone'});
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1')],
        fetchItems: _FakeFetcher().call,
      );

      expect(await ShortcutsFoldersStore.rotationFolderId(), isNull);
    });

    test('keeps a rotation folder that is still in the folders list', () async {
      await ShortcutsFoldersStore.setRotationFolder('f1');
      await ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1')],
        fetchItems: _FakeFetcher().call,
      );

      expect(await ShortcutsFoldersStore.rotationFolderId(), 'f1');
    });
  });

  group('rotation folder', () {
    test('set then read, and null stops it', () async {
      await ShortcutsFoldersStore.setRotationFolder('f1');
      expect(await ShortcutsFoldersStore.rotationFolderId(), 'f1');

      await ShortcutsFoldersStore.setRotationFolder(null);
      expect(await ShortcutsFoldersStore.rotationFolderId(), isNull);
    });
  });

  group('clear', () {
    test('writes an empty snapshot and removes the rotation folder and shuffle bags', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.shortcutsFolders: '{"ownerId":"owner-a","folders":[{"id":"f1"}]}',
        PersistenceKeys.shortcutsRotationFolder: 'f1',
        PersistenceKeys.shortcutsShuffleBags: '{"f1":[0,1]}',
      });

      await ShortcutsFoldersStore.clear();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFolders), '{"folders":[]}');
      expect(prefs.getString(PersistenceKeys.shortcutsRotationFolder), isNull);
      expect(prefs.getString(PersistenceKeys.shortcutsShuffleBags), isNull);
    });

    test('a sync still waiting in fetchItems does not write after the clear', () async {
      final Completer<void> started = Completer<void>();
      final Completer<void> gate = Completer<void>();
      final Future<void> sync = ShortcutsFoldersStore.sync(
        ownerId: 'owner-a',
        folders: <FolderEntity>[_folder('f1')],
        fetchItems: (String folderId) async {
          started.complete();
          await gate.future;
          return Result.success<List<FavouriteWallEntity>?>(<FavouriteWallEntity>[_wall('a')]);
        },
      );
      await started.future;

      final Future<void> clear = ShortcutsFoldersStore.clear();
      gate.complete();
      await Future.wait(<Future<void>>[sync, clear]);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFolders), '{"folders":[]}');
    });
  });

  group('clearForUser', () {
    test('clears when the snapshot owner matches', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.shortcutsFolders: '{"ownerId":"owner-a","folders":[{"id":"f1"}]}',
        PersistenceKeys.shortcutsRotationFolder: 'f1',
      });

      await ShortcutsFoldersStore.clearForUser('owner-a');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFolders), '{"folders":[]}');
      expect(prefs.getString(PersistenceKeys.shortcutsRotationFolder), isNull);
    });

    test('does nothing when the snapshot owner is another user', () async {
      const String saved = '{"ownerId":"owner-b","folders":[{"id":"f1"}]}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        PersistenceKeys.shortcutsFolders: saved,
        PersistenceKeys.shortcutsRotationFolder: 'f1',
      });

      await ShortcutsFoldersStore.clearForUser('owner-a');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersistenceKeys.shortcutsFolders), saved);
      expect(prefs.getString(PersistenceKeys.shortcutsRotationFolder), 'f1');
    });
  });
}
