import 'dart:convert';

import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._store, {@ignoreParam DurableJsonStore? durableStore})
    : _durable = durableStore ?? DurableJsonStore('favourites');

  final LocalStore _store;
  final DurableJsonStore _durable;
  final Map<String, Future<void>> _writeTails = <String, Future<void>>{};
  final Map<String, Future<void>> _sendTails = <String, Future<void>>{};
  static int _snapshotGeneration = 0;
  static const int _snapshotChunkBytes = 512 * 1024;

  static const String defaultUserScope = '__global';

  String _scope(String userId) => userId.trim().isEmpty ? defaultUserScope : userId.trim();

  Set<String> _wallSet(String scope) {
    final raw = _store.get(PersistenceKeys.favoritesWallSet(scope));
    try {
      return Set<String>.from((raw! as Iterable<Object?>).whereType<String>());
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveWallSet(String scope, Set<String> ids) {
    return _store.set(PersistenceKeys.favoritesWallSet(scope), ids.toList(growable: false));
  }

  bool isWallFavourite(String userId, String itemId) {
    return _wallSet(_scope(userId)).contains(itemId);
  }

  Future<void> setWallFavourite(String userId, String itemId, bool value) {
    final scope = _scope(userId);
    return _serialize(scope, () async {
      final ids = _wallSet(scope);
      if (value) {
        ids.add(itemId);
      } else {
        ids.remove(itemId);
      }
      await _saveWallSet(scope, ids);
    });
  }

  Future<void> replaceWallFavourites(String userId, Iterable<String> itemIds) {
    final scope = _scope(userId);
    return _serialize(scope, () => _saveWallSet(scope, itemIds.where((id) => id.isNotEmpty).toSet()));
  }

  Future<List<FavouriteWallEntity>> readWallSnapshot(String userId) {
    final scope = _scope(userId);
    return _serialize(scope, () => _readWallSnapshot(scope));
  }

  Future<List<FavouriteWallEntity>> _readWallSnapshot(String scope) async {
    final record = await _durable.read('$scope::snapshot');
    if (record == null) return <FavouriteWallEntity>[];
    final walls = <FavouriteWallEntity>[];
    final String? generation = record['generation'] as String?;
    final int shardCount = record['shardCount'] as int? ?? 0;
    final List<Object?> rawWalls = <Object?>[];
    if (generation != null) {
      for (int index = 0; index < shardCount; index++) {
        final shard = await _durable.read('$scope::snapshot:$generation:$index');
        if (shard != null) rawWalls.addAll(shard['walls'] as List? ?? const <Object?>[]);
      }
    } else {
      rawWalls.addAll(record['walls'] as List? ?? const <Object?>[]);
    }
    for (final raw in rawWalls) {
      final data = Map<String, dynamic>.from(raw! as Map);
      final dto = FavouriteWallDocDto.fromJson(data);
      walls.add(mapFavouriteWallDoc(dto, dto.id));
    }
    final operations = await readFavouriteOperations(scope);
    final withStatus = walls.map((wall) {
      final FavouriteSyncStatus status = switch (operations[wall.id]?['status']) {
        'pending' => FavouriteSyncStatus.pending,
        'rejected' => FavouriteSyncStatus.rejected,
        _ => FavouriteSyncStatus.synced,
      };
      return wall.withSyncStatus(status);
    }).toList();
    return withStatus..sort(compareByCreatedAtDesc);
  }

  Future<void> saveWallSnapshot(String userId, Iterable<FavouriteWallEntity> walls) {
    final scope = _scope(userId);
    return _serialize(scope, () => _writeWallSnapshot(scope, walls));
  }

  Future<void> updateWallSnapshot(
    String userId,
    Iterable<FavouriteWallEntity> Function(List<FavouriteWallEntity> current) update,
  ) {
    final scope = _scope(userId);
    return _serialize(scope, () async {
      final current = await _readWallSnapshot(scope);
      await _writeWallSnapshot(scope, update(current));
    });
  }

  Future<List<FavouriteWallEntity>> mergeServerWallSnapshot(String userId, Iterable<FavouriteWallEntity> serverWalls) {
    final String scope = _scope(userId);
    return _serialize(scope, () async {
      final Map<String, FavouriteWallEntity> desired = <String, FavouriteWallEntity>{
        for (final wall in serverWalls) wall.id: wall,
      };
      final operations = await readFavouriteOperations(userId);
      for (final entry in operations.entries) {
        final operation = entry.value;
        final status = operation['status'];
        if (status != 'pending' && status != 'rejected') continue;
        if (operation['desired'] == false) {
          if (status == 'pending') {
            desired.remove(entry.key);
          } else if (desired[entry.key] != null) {
            final wall = desired[entry.key]!;
            desired[entry.key] = wall.withSyncStatus(FavouriteSyncStatus.rejected);
          }
        } else if (operation['wall'] != null) {
          final doc = FavouriteWallDocDto.fromJson(Map<String, dynamic>.from(operation['wall']! as Map));
          final wall = mapFavouriteWallDoc(doc, entry.key);
          desired[entry.key] = wall.withSyncStatus(
            status == 'pending' ? FavouriteSyncStatus.pending : FavouriteSyncStatus.rejected,
          );
        }
      }
      final List<FavouriteWallEntity> merged = desired.values.toList()..sort(compareByCreatedAtDesc);
      await _saveWallSet(scope, merged.map((wall) => wall.id).toSet());
      await _writeWallSnapshot(scope, merged);
      return merged;
    });
  }

  Future<void> _writeWallSnapshot(String scope, Iterable<FavouriteWallEntity> walls) async {
    final docs = <Map<String, Object?>>[];
    final Set<String> seen = <String>{};
    for (final wall in walls) {
      if (wall.id.isEmpty || !seen.add(wall.id)) continue;
      docs.add(_jsonFavouriteDoc(wall));
    }
    final List<List<Map<String, Object?>>> chunks = <List<Map<String, Object?>>>[];
    var chunk = <Map<String, Object?>>[];
    for (final doc in docs) {
      final candidate = <Map<String, Object?>>[...chunk, doc];
      if (chunk.isNotEmpty && utf8.encode(jsonEncode(candidate)).length > _snapshotChunkBytes) {
        chunks.add(chunk);
        chunk = <Map<String, Object?>>[doc];
      } else {
        chunk = candidate;
      }
    }
    if (chunk.isNotEmpty) chunks.add(chunk);

    final String generation = '${DateTime.now().microsecondsSinceEpoch}-${_snapshotGeneration++}';
    for (int index = 0; index < chunks.length; index++) {
      await _durable.write('$scope::snapshot:$generation:$index', <String, Object?>{'walls': chunks[index]});
    }
    await _durable.write('$scope::snapshot', <String, Object?>{'generation': generation, 'shardCount': chunks.length});
    final records = await _durable.readAll();
    final String prefix = '$scope::snapshot:';
    for (final key in records.keys.where((key) => key.startsWith(prefix) && !key.startsWith('$prefix$generation:'))) {
      await _durable.delete(key);
    }
  }

  Future<Map<String, Object?>?> readFavouriteOperation(String userId, String wallId) =>
      _durable.read('${_scope(userId)}::op:$wallId');

  Future<Map<String, Map<String, Object?>>> readFavouriteOperations(String userId) async {
    final records = await _durable.readAll();
    final prefix = '${_scope(userId)}::op:';
    return Map<String, Map<String, Object?>>.fromEntries(
      records.entries
          .where((entry) => entry.key.startsWith(prefix))
          .map((entry) => MapEntry<String, Map<String, Object?>>(entry.key.substring(prefix.length), entry.value)),
    );
  }

  Future<void> writeFavouriteOperation(String userId, String wallId, Map<String, Object?> operation) =>
      _serialize(_scope(userId), () => _durable.write('${_scope(userId)}::op:$wallId', operation));

  Future<bool> runFavouriteOperationsIfCurrent(
    String userId,
    Map<String, String> operationIds,
    Future<void> Function() send,
  ) {
    final String scope = _scope(userId);
    return _serializeSend<bool>(scope, () async {
      final bool isCurrent = await _serialize(scope, () async {
        for (final entry in operationIds.entries) {
          final current = await _durable.read('$scope::op:${entry.key}');
          if (current?['operationId'] != entry.value || current?['owner'] != scope) return false;
        }
        return true;
      });
      if (!isCurrent) return false;
      await send();
      return true;
    });
  }

  Future<Map<String, Object?>> createFavouriteOperation(
    String userId,
    String wallId, {
    required bool desired,
    required Map<String, Object?> wall,
  }) async {
    final scope = _scope(userId);
    late Map<String, Object?> operation;
    await _serialize(scope, () async {
      final previous = await _durable.read('$scope::op:$wallId');
      final revision = (previous?['revision'] as int? ?? 0) + 1;
      operation = <String, Object?>{
        'owner': scope,
        'revision': revision,
        'operationId': '$scope:$wallId:$revision',
        'desired': desired,
        'status': 'pending',
        'wall': _jsonDateValues(wall),
        'attempts': 0,
      };
      await _durable.write('$scope::op:$wallId', operation);
    });
    return operation;
  }

  Map<String, Object?> _jsonFavouriteDoc(FavouriteWallEntity wall) =>
      _jsonDateValues(Map<String, Object?>.from(favouriteWallToDoc(wall)));

  Map<String, Object?> _jsonDateValues(Map<String, Object?> values) => <String, Object?>{
    for (final entry in values.entries)
      entry.key: entry.value is DateTime ? (entry.value! as DateTime).toIso8601String() : entry.value,
  };

  Future<bool> updateFavouriteOperationStatus(
    String userId,
    String wallId,
    String operationId, {
    required String status,
    String? error,
  }) async {
    final scope = _scope(userId);
    var changed = false;
    await _serialize(scope, () async {
      final current = await _durable.read('$scope::op:$wallId');
      if (current?['operationId'] != operationId) return;
      await _durable.write('$scope::op:$wallId', <String, Object?>{
        ...current!,
        'status': status,
        if (status == 'pending') 'attempts': (current['attempts'] as int? ?? 0) + 1,
        if (error != null) 'error': error,
      });
      changed = true;
    });
    return changed;
  }

  Future<bool> hasCurrentFavouriteOperation(String userId, String wallId, String operationId) async {
    final operation = await readFavouriteOperation(userId, wallId);
    return operation?['operationId'] == operationId && operation?['owner'] == _scope(userId);
  }

  Future<Map<String, String>> readFavouriteSyncStatuses(String userId) async {
    final operations = await readFavouriteOperations(userId);
    return Map<String, String>.fromEntries(
      operations.entries.map((entry) => MapEntry<String, String>(entry.key, entry.value['status']?.toString() ?? '')),
    );
  }

  Future<void> clearUser(String userId) async {
    final scope = _scope(userId);
    await _serialize(scope, () async {
      final records = await _durable.readAll();
      for (final key in records.keys.where((key) => key == '$scope::snapshot' || key.startsWith('$scope::op:'))) {
        await _durable.delete(key);
      }
      for (final key in records.keys.where((key) => key.startsWith('$scope::snapshot:'))) {
        await _durable.delete(key);
      }
      await _saveWallSet(scope, <String>{});
    });
  }

  Future<T> _serialize<T>(String scope, Future<T> Function() action) {
    final previous = _writeTails[scope] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => action());
    final Future<void> tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _writeTails[scope] = tail;
    return next.whenComplete(() {
      if (identical(_writeTails[scope], tail)) _writeTails.remove(scope);
    });
  }

  Future<T> _serializeSend<T>(String scope, Future<T> Function() action) {
    final Future<void> previous = _sendTails[scope] ?? Future<void>.value();
    final Future<T> next = previous.catchError((Object _) {}).then((_) => action());
    final Future<void> tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _sendTails[scope] = tail;
    return next.whenComplete(() {
      if (identical(_sendTails[scope], tail)) _sendTails.remove(scope);
    });
  }
}
