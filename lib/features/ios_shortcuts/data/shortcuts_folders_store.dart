import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef FolderItemsFetcher = Future<Result<List<FavouriteWallEntity>?>> Function(String folderId);

/// Writes a snapshot of the user's folders as a raw JSON string, so the iOS "Get Prism Wallpaper" intent can
/// shuffle a folder without a running Flutter engine. Also keeps the folder the "Rotation folder" source uses.
class ShortcutsFoldersStore {
  const ShortcutsFoldersStore._();

  static const int maxFolders = 50;
  static const int maxItems = 200;
  static const String sessionRevisionKey = 'shortcuts.session_revision';

  static Future<void>? _tail;
  static int _generation = 0;
  static int _syncRevision = 0;
  static final StreamController<void> _rotationFolderChanges = StreamController<void>.broadcast();

  static Stream<void> get rotationFolderChanges => _rotationFolderChanges.stream;

  /// `{"ownerId", "folders": [{"id", "name", "itemCount", "updatedAt", "items": [{"id", "url"}]}]}`. Items are
  /// newest first, at most [maxItems], each with an https URL or, for a protected wall, an `asset` key instead.
  static String encode(String ownerId, List<({FolderEntity folder, List<Map<String, String>> items})> folders) =>
      jsonEncode(<String, Object>{
        'ownerId': ownerId,
        'folders': <Map<String, Object>>[
          for (final entry in folders)
            <String, Object>{
              'id': entry.folder.id,
              'name': entry.folder.name,
              'itemCount': entry.folder.itemCount,
              'updatedAt': entry.folder.updatedAt.millisecondsSinceEpoch,
              'items': entry.items,
            },
        ],
      });

  /// A wall without an https URL is kept only when [originals] has its downloaded original's asset key.
  static List<Map<String, String>> encodeItems(
    Iterable<FavouriteWallEntity> walls, {
    Set<String> originals = const <String>{},
  }) {
    final Set<String> seen = <String>{};
    final List<Map<String, String>> items = <Map<String, String>>[];
    for (final FavouriteWallEntity wall in walls) {
      final String url = wall.fullUrl.trim();
      final String id = folderItemKey(wall);
      final String asset = NativeAssetPathsStore.originalAssetKey(wall);
      if (wall.id.trim().isEmpty || !seen.add(id)) continue;
      if (url.startsWith('https://')) {
        items.add(<String, String>{'id': id, 'url': url});
      } else if (originals.contains(asset)) {
        items.add(<String, String>{'id': id, 'asset': asset});
      } else {
        continue;
      }
      if (items.length == maxItems) break;
    }
    return items;
  }

  /// Writes the snapshot for [ownerId]'s [folders]. A folder whose update time and count match the last snapshot
  /// keeps its items, so an app open reads only folders that changed. Clears the rotation folder when it is gone.
  static Future<void> sync({
    required String ownerId,
    required List<FolderEntity> folders,
    required FolderItemsFetcher fetchItems,
  }) {
    final int generation = _generation;
    final int syncRevision = ++_syncRevision;
    final String owner = ownerId.trim();
    final List<FolderEntity> sorted = folders.where((folder) => folder.ownerId.trim() == owner).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    bool current() =>
        owner.isNotEmpty && generation == _generation && syncRevision == _syncRevision && _activeOwnerMatches(owner);
    return () async {
      final Future<void>? pendingWrite = _tail;
      if (pendingWrite != null) await pendingWrite;
      if (!current()) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      final String? rotation = prefs.getString(PersistenceKeys.shortcutsRotationFolder);
      // The rotation folder always makes the cut, even when the user has more than [maxFolders] folders.
      final List<FolderEntity> selected = <FolderEntity>[
        ...sorted.where((folder) => folder.id == rotation),
        ...sorted.where((folder) => folder.id != rotation),
      ].take(maxFolders).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final Map<String, Map<String, Object?>> previous = _previousFolders(prefs, ownerId);
      final List<({FolderEntity folder, List<Map<String, String>> items})> entries =
          <({FolderEntity folder, List<Map<String, String>> items})>[];
      final Map<String, String> originals = <String, String>{};
      for (final FolderEntity folder in selected) {
        final Map<String, Object?>? old = previous[folder.id];
        final List<Map<String, String>> oldItems = _items(old?['items']);
        // A folder with protected walls is read again, so a new download joins and a deleted one leaves.
        // ponytail: also re-reads folders with http-only walls on each sync; track skipped walls if reads matter.
        if (old != null &&
            old['updatedAt'] == folder.updatedAt.millisecondsSinceEpoch &&
            old['itemCount'] == folder.itemCount &&
            oldItems.length == min(folder.itemCount, maxItems) &&
            oldItems.every((item) => item.containsKey('url'))) {
          entries.add((folder: folder, items: oldItems));
          continue;
        }
        final Result<List<FavouriteWallEntity>?> result = await fetchItems(folder.id);
        if (!current()) return;
        if (result.failure != null) {
          // With no earlier copy, leave the folder out: the intent then says to open Prism, which syncs again, and
          // never reports a folder with walls as empty.
          if (old == null) continue;
          // Keep what the last snapshot had. The epoch update time makes the next sync read the folder again.
          entries.add((
            folder: folder.copyWith(updatedAt: DateTime.fromMillisecondsSinceEpoch(0)),
            items: oldItems.where((item) => item.containsKey('url')).toList(),
          ));
          continue;
        }
        final List<FavouriteWallEntity>? walls = result.data;
        if (walls == null) continue;
        Map<String, String> folderOriginals = const <String, String>{};
        try {
          folderOriginals = await NativeAssetPathsStore.downloadedOriginalPaths(walls);
        } catch (_) {}
        if (!current()) return;
        originals.addAll(folderOriginals);
        entries.add((folder: folder, items: encodeItems(walls, originals: folderOriginals.keys.toSet())));
      }
      Map<String, String> relativePaths = <String, String>{};
      try {
        relativePaths = await NativeAssetPathsStore.retainedRelativePaths(
          entries.expand((entry) => entry.items).map((item) => item['url']).whereType<String>(),
        );
      } catch (_) {}
      relativePaths.addAll(originals);
      if (!current()) return;
      await _enqueue(() async {
        if (!current()) return;
        await NativeAssetPathsStore.replaceGroup('folders', relativePaths, isCurrent: current);
        if (!current()) return;
        if (!await prefs.setString(PersistenceKeys.shortcutsFolders, encode(ownerId, entries))) {
          throw StateError('Shortcuts folders could not be persisted');
        }
        if (rotation != null && !folders.any((folder) => folder.id == rotation)) {
          await prefs.remove(PersistenceKeys.shortcutsRotationFolder);
        }
      });
    }();
  }

  /// [sync] with each changed folder's newest [maxItems] walls read from [repository].
  static Future<void> syncFrom(
    FoldersRepository repository, {
    required String ownerId,
    required List<FolderEntity> folders,
  }) => sync(
    ownerId: ownerId,
    folders: folders,
    fetchItems: (folderId) => repository.fetchItems(folderId, userId: ownerId, limit: maxItems),
  );

  static Future<String?> rotationFolderId() async {
    final String? id = (await SharedPreferences.getInstance()).getString(PersistenceKeys.shortcutsRotationFolder);
    return id == null || id.isEmpty ? null : id;
  }

  /// Sets the folder the "Rotation folder" source shuffles. Null stops it.
  static Future<void> setRotationFolder(String? folderId) => _enqueue(() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool ok = folderId == null
        ? await prefs.remove(PersistenceKeys.shortcutsRotationFolder)
        : await prefs.setString(PersistenceKeys.shortcutsRotationFolder, folderId);
    if (!ok) throw StateError('Shortcuts rotation folder could not be persisted');
    _rotationFolderChanges.add(null);
  });

  /// Drops the snapshot, the rotation folder and the intent's shuffle passes. A sync called before it is dropped.
  static Future<void> clear() {
    _generation++;
    _syncRevision++;
    return _enqueue(_clearAll);
  }

  static Future<void> clearForUser(String userId) async {
    final String owner = userId.trim();
    if (owner.isEmpty || _otherOwnerIsActive(owner)) return;
    _generation++;
    _syncRevision++;
    await _enqueue(() async {
      if (_otherOwnerIsActive(owner)) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String savedOwner = _snapshotOwner(prefs);
      if (savedOwner.isNotEmpty && savedOwner != owner) return;
      await _clearAll();
    });
  }

  /// Runs every step even when one fails, so one failure cannot leave the rest of the private state behind.
  static Future<void> _clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Future<bool> Function()> steps = <Future<bool> Function()>[
      () => prefs.setInt(sessionRevisionKey, (prefs.getInt(sessionRevisionKey) ?? 0) + 1),
      () async {
        await NativeAssetPathsStore.replaceGroup('folders', const <String, String>{});
        return true;
      },
      () => prefs.setString(PersistenceKeys.shortcutsFolders, '{"folders":[]}'),
      () => prefs.remove(PersistenceKeys.shortcutsRotationFolder),
      () => prefs.remove(PersistenceKeys.shortcutsShuffleBags),
    ];
    bool cleared = true;
    for (final Future<bool> Function() step in steps) {
      try {
        cleared = await step() && cleared;
      } catch (_) {
        cleared = false;
      }
    }
    if (!cleared) throw StateError('Shortcuts folders could not be cleared');
  }

  static Map<String, Object?>? _snapshot(SharedPreferences prefs) {
    try {
      final Object? decoded = jsonDecode(prefs.getString(PersistenceKeys.shortcutsFolders) ?? '');
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String _snapshotOwner(SharedPreferences prefs) {
    final Object? owner = _snapshot(prefs)?['ownerId'];
    return owner is String ? owner.trim() : '';
  }

  static Map<String, Map<String, Object?>> _previousFolders(SharedPreferences prefs, String ownerId) {
    final Map<String, Object?>? snapshot = _snapshot(prefs);
    final Object? folders = snapshot?['folders'];
    if (snapshot?['ownerId'] != ownerId || folders is! List) return const <String, Map<String, Object?>>{};
    return <String, Map<String, Object?>>{
      for (final Object? folder in folders)
        if (folder is Map<String, Object?> && folder['id'] is String) folder['id']! as String: folder,
    };
  }

  static List<Map<String, String>> _items(Object? raw) => <Map<String, String>>[
    if (raw is List)
      for (final Object? item in raw)
        if (item is Map && item['id'] is String && item['url'] is String)
          <String, String>{'id': item['id'] as String, 'url': item['url'] as String}
        else if (item is Map && item['id'] is String && item['asset'] is String)
          <String, String>{'id': item['id'] as String, 'asset': item['asset'] as String},
  ];

  static bool _otherOwnerIsActive(String owner) {
    final String activeOwner = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
    return activeOwner.isNotEmpty && activeOwner != owner;
  }

  static bool _activeOwnerMatches(String owner) =>
      app_state.prismUser.loggedIn && app_state.prismUser.id.trim() == owner;

  static Future<void> _enqueue(Future<void> Function() write) {
    final Future<void>? previous = _tail;
    final Future<void> result = previous == null ? write() : previous.then((_) => write());
    final Future<void> tail = result.catchError((Object _) {});
    _tail = tail;
    tail.whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
    return result;
  }
}
