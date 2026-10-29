import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/data/hydrate_prism_favourites.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

const int _maxBatchDeletes = 400;

/// A Firestore write waits for the server. Offline it never completes, so the app stops waiting
/// after this long. The SDK keeps the write and sends it when the network returns.
const Duration _writeTimeout = Duration(seconds: 8);
const Duration _readTimeout = Duration(seconds: 8);
const Duration _cachedReadGrace = Duration(milliseconds: 500);
typedef _FavouriteSnapshot = ({List<FavouriteWallEntity> items, bool isFromCache});

bool _isPermanentFavouriteFailure(Object error) => const <String>{
  'permission-denied',
  'invalid-argument',
  'failed-precondition',
  'unauthenticated',
}.contains(mapFirestoreError(error).code);

@LazySingleton(as: FavouriteWallsRepository)
class FavouriteWallsRepositoryImpl implements FavouriteWallsRepository {
  FavouriteWallsRepositoryImpl(this._firestoreClient, this._favoritesLocal, this._guestStore, this._prismWallpapers);

  final FirestoreClient _firestoreClient;
  final FavoritesLocalDataSource _favoritesLocal;
  final GuestFavouritesStore _guestStore;
  final PrismWallpaperRepository _prismWallpapers;

  String _collectionPath(String userId) => 'usersv2/$userId/images';

  Future<({List<FavouriteWallEntity> items, bool isFromCache})> _read(String userId) async {
    if (userId.isEmpty) {
      final Map<String, Map<String, Object?>> saved = await _guestStore.readAll();
      final items =
          saved.entries
              .map(
                (entry) =>
                    mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(Map<String, dynamic>.of(entry.value)), entry.key),
              )
              .toList()
            ..sort(compareByCreatedAtDesc);
      return (items: items, isFromCache: false);
    }
    List<FavouriteWallEntity>? cachedItems;
    StreamSubscription<_FavouriteSnapshot>? subscription;
    final serverSnapshot = Completer<_FavouriteSnapshot?>();
    final cachedSnapshotReceived = Completer<void>();
    Timer? cachedReadGraceTimer;
    var readFinished = false;
    serverSnapshot.future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    try {
      final metadataStream = _firestoreClient.watchQueryWithMetadata<FavouriteWallEntity>(
        FirestoreQuerySpec(
          collection: _collectionPath(userId),
          sourceTag: 'favourite_walls.read',
          isStream: true,
          cachePolicy: FirestoreCachePolicy.memoryFirst,
        ),
        (data, docId) => mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(data), docId),
      );
      subscription = metadataStream.listen(
        (snapshot) {
          if (snapshot.isFromCache) {
            cachedItems = snapshot.items;
            if (!cachedSnapshotReceived.isCompleted) cachedSnapshotReceived.complete();
          } else if (!serverSnapshot.isCompleted) {
            serverSnapshot.complete(snapshot);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!serverSnapshot.isCompleted) serverSnapshot.completeError(error, stackTrace);
        },
        onDone: () {
          if (cachedItems == null && !serverSnapshot.isCompleted) serverSnapshot.complete(null);
        },
      );
      final snapshot = await Future.any<_FavouriteSnapshot?>(<Future<_FavouriteSnapshot?>>[
        serverSnapshot.future,
        cachedSnapshotReceived.future.then((_) async {
          if (serverSnapshot.isCompleted) return serverSnapshot.future;
          if (readFinished) return null;
          final graceElapsed = Completer<_FavouriteSnapshot?>();
          cachedReadGraceTimer = Timer(_cachedReadGrace, () {
            if (!graceElapsed.isCompleted) graceElapsed.complete(null);
          });
          return Future.any<_FavouriteSnapshot?>(<Future<_FavouriteSnapshot?>>[
            serverSnapshot.future,
            graceElapsed.future,
          ]);
        }),
      ]).timeout(_readTimeout, onTimeout: () => null);
      if (snapshot == null) {
        return (items: cachedItems ?? const <FavouriteWallEntity>[], isFromCache: true);
      }
      final items = snapshot.items.toList()..sort(compareByCreatedAtDesc);
      return (items: items, isFromCache: snapshot.isFromCache);
    } catch (_) {
      if (cachedItems == null) rethrow;
      final items = cachedItems!..sort(compareByCreatedAtDesc);
      return (items: items, isFromCache: true);
    } finally {
      readFinished = true;
      cachedReadGraceTimer?.cancel();
      if (subscription != null) {
        unawaited(
          subscription.cancel().catchError((Object error, StackTrace stackTrace) {
            logger.w('Could not finish the favourite metadata listener cleanup', error: error, stackTrace: stackTrace);
          }),
        );
      }
    }
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async {
    try {
      final snapshot = await _read(userId);
      final List<FavouriteWallEntity> items = snapshot.items;
      final local = userId.isEmpty ? const <FavouriteWallEntity>[] : await _favoritesLocal.readWallSnapshot(userId);
      final retainedLocal = snapshot.isFromCache && items.isEmpty ? local : local.where(_isBundledStarter);
      final merged = await _favoritesLocal.mergeServerWallSnapshot(userId, <FavouriteWallEntity>[
        ...items,
        ...retainedLocal,
      ]);
      return Result.success(await hydratePrismFavourites(merged, _prismWallpapers));
    } catch (error) {
      try {
        final cached = await _favoritesLocal.readWallSnapshot(userId);
        if (cached.isNotEmpty) return Result.success(await hydratePrismFavourites(cached, _prismWallpapers));
      } catch (cacheError) {
        return Result.error(ServerFailure('Unable to fetch favourite walls: $error; local read failed: $cacheError'));
      }
      return Result.error(ServerFailure('Unable to fetch favourite walls: $error'));
    }
  }

  @override
  Future<Result<bool>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
    required bool currentlyFavourited,
  }) async {
    final bool add = !currentlyFavourited;
    try {
      if (_isBundledStarter(wall)) {
        if (userId.isEmpty) {
          if (add) {
            await _guestStore.put(wall.id, favouriteWallToDoc(wall));
          } else {
            await _guestStore.remove(<String>[wall.id]);
          }
        }
        await _favoritesLocal.setWallFavourite(userId, wall.id, add);
        if (userId.isNotEmpty) {
          await _favoritesLocal.updateWallSnapshot(
            userId,
            (current) => <FavouriteWallEntity>[...current.where((item) => item.id != wall.id), if (add) wall],
          );
        }
        return Result.success(add);
      }
      final Map<String, Object?> operation = await _favoritesLocal.createFavouriteOperation(
        userId,
        wall.id,
        desired: add,
        wall: Map<String, Object?>.from(favouriteWallToDoc(wall)),
      );
      final String operationId = operation['operationId']! as String;
      if (userId.isEmpty) {
        if (add) {
          await _guestStore.put(wall.id, favouriteWallToDoc(wall));
        } else {
          await _guestStore.remove(<String>[wall.id]);
        }
        await _favoritesLocal.setWallFavourite(userId, wall.id, add);
        await _favoritesLocal.updateFavouriteOperationStatus(userId, wall.id, operationId, status: 'synced');
        return Result.success(add);
      }
      await _favoritesLocal.setWallFavourite(userId, wall.id, add);
      if (add) {
        await _favoritesLocal.updateWallSnapshot(
          userId,
          (current) => <FavouriteWallEntity>[
            ...current.where((item) => item.id != wall.id),
            wall.withSyncStatus(FavouriteSyncStatus.pending),
          ],
        );
      } else {
        await _favoritesLocal.updateWallSnapshot(
          userId,
          (current) => current.where((item) => item.id != wall.id).toList(growable: false),
        );
      }
      try {
        final bool sent = await _favoritesLocal.runFavouriteOperationsIfCurrent(
          userId,
          <String, String>{wall.id: operationId},
          () async {
            if (add) {
              await _firestoreClient
                  .setDoc(
                    _collectionPath(userId),
                    wall.id,
                    favouriteWallToDoc(wall),
                    sourceTag: 'favourite_walls.toggle.set',
                  )
                  .timeout(_writeTimeout);
            } else {
              await _firestoreClient
                  .deleteDoc(_collectionPath(userId), wall.id, sourceTag: 'favourite_walls.toggle.delete')
                  .timeout(_writeTimeout);
            }
          },
        );
        if (!sent) return Result.error(const ServerFailure('A newer favourite choice replaced this action.'));
        await _favoritesLocal.updateFavouriteOperationStatus(userId, wall.id, operationId, status: 'synced');
      } on TimeoutException {
        logger.w('Favourite write queued offline for ${wall.id}.', tag: 'Favourites');
      } catch (error) {
        if (!_isPermanentFavouriteFailure(error)) {
          logger.w('Favourite write remains pending for retry: ${wall.id}.', tag: 'Favourites', error: error);
          return Result.success(add);
        }
        final rejected = await _favoritesLocal.updateFavouriteOperationStatus(
          userId,
          wall.id,
          operationId,
          status: 'rejected',
        );
        if (rejected) {
          await _favoritesLocal.setWallFavourite(userId, wall.id, !add);
          await _favoritesLocal.updateWallSnapshot(
            userId,
            (current) => <FavouriteWallEntity>[
              ...current.where((item) => item.id != wall.id),
              if (!add) wall.withSyncStatus(FavouriteSyncStatus.rejected),
            ],
          );
        }
        rethrow;
      }
      return Result.success(add);
    } catch (error) {
      return Result.error(ServerFailure('Unable to toggle favourite wall: $error'));
    }
  }

  @override
  Future<Result<void>> setPinned({
    required String userId,
    required FavouriteWallEntity wall,
    DateTime? pinnedAt,
  }) async {
    final FavouriteWallEntity next = wall.withPinnedAt(pinnedAt);
    try {
      if (userId.isEmpty) {
        await _guestStore.put(wall.id, favouriteWallToDoc(next));
        return Result.success(null);
      }
      await _favoritesLocal.updateWallSnapshot(
        userId,
        (current) => <FavouriteWallEntity>[
          for (final FavouriteWallEntity item in current) item.id == wall.id ? item.withPinnedAt(pinnedAt) : item,
        ],
      );
      // A bundled starter wall lives only on this device.
      if (_isBundledStarter(wall)) return Result.success(null);
      try {
        await _firestoreClient
            .updateDoc(_collectionPath(userId), wall.id, <String, dynamic>{
              'pinnedAt': pinnedAt ?? FirestoreSentinels.delete(),
            }, sourceTag: 'favourite_walls.pin')
            .timeout(_writeTimeout);
      } on TimeoutException {
        logger.w('Favourite pin queued offline for ${wall.id}.', tag: 'Favourites');
      } catch (error) {
        await _favoritesLocal.updateWallSnapshot(
          userId,
          (current) => <FavouriteWallEntity>[
            for (final FavouriteWallEntity item in current)
              item.id == wall.id ? item.withPinnedAt(wall.pinnedAt) : item,
          ],
        );
        rethrow;
      }
      return Result.success(null);
    } catch (error) {
      return Result.error(ServerFailure('Unable to pin favourite wall: $error'));
    }
  }

  bool _isBundledStarter(FavouriteWallEntity wall) => BundledWallpapers.isStarterIdentity(wall.id, wall.source);

  @override
  Future<Result<bool>> clearAll({required String userId, required List<String> wallIds}) async {
    try {
      final List<String> ids = wallIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
      if (userId.isEmpty) {
        await _guestStore.remove(ids);
        for (final String id in ids) {
          await _favoritesLocal.setWallFavourite(userId, id, false);
        }
        return Result.success(true);
      }
      for (int start = 0; start < ids.length; start += _maxBatchDeletes) {
        final List<String> chunk = ids.sublist(start, math.min(start + _maxBatchDeletes, ids.length));
        final Map<String, String> operationIds = <String, String>{};
        final cachedBefore = await _favoritesLocal.readWallSnapshot(userId);
        final Set<String> bundledStarterIds = cachedBefore
            .where((wall) => chunk.contains(wall.id) && _isBundledStarter(wall))
            .map((wall) => wall.id)
            .toSet();
        for (final String id in chunk) {
          if (bundledStarterIds.contains(id)) {
            await _favoritesLocal.setWallFavourite(userId, id, false);
            continue;
          }
          final oldWall = cachedBefore.where((wall) => wall.id == id).firstOrNull;
          final operation = await _favoritesLocal.createFavouriteOperation(
            userId,
            id,
            desired: false,
            wall: oldWall == null ? const <String, Object?>{} : Map<String, Object?>.from(favouriteWallToDoc(oldWall)),
          );
          await _favoritesLocal.setWallFavourite(userId, id, false);
          operationIds[id] = operation['operationId']! as String;
        }
        await _favoritesLocal.updateWallSnapshot(
          userId,
          (current) => current.where((wall) => !chunk.contains(wall.id)).toList(growable: false),
        );
        if (operationIds.isEmpty) continue;
        try {
          final bool sent = await _favoritesLocal.runFavouriteOperationsIfCurrent(
            userId,
            operationIds,
            () => _firestoreClient
                .runBatch((batch) async {
                  for (final String id in operationIds.keys) {
                    batch.deleteDoc(_collectionPath(userId), id);
                  }
                }, sourceTag: 'favourite_walls.clear_all.delete')
                .timeout(_writeTimeout),
          );
          if (!sent) return Result.error(const ServerFailure('Newer favourite choices replaced this removal.'));
          for (final entry in operationIds.entries) {
            await _favoritesLocal.updateFavouriteOperationStatus(userId, entry.key, entry.value, status: 'synced');
          }
        } on TimeoutException {
          logger.w('Favourite clear queued offline for ${chunk.length} walls.', tag: 'Favourites');
        } catch (error) {
          if (!_isPermanentFavouriteFailure(error)) {
            logger.w('Favourite clear remains pending for retry.', tag: 'Favourites', error: error);
            continue;
          }
          for (final entry in operationIds.entries) {
            final rejected = await _favoritesLocal.updateFavouriteOperationStatus(
              userId,
              entry.key,
              entry.value,
              status: 'rejected',
            );
            if (rejected) await _favoritesLocal.setWallFavourite(userId, entry.key, true);
          }
          await _favoritesLocal.updateWallSnapshot(
            userId,
            (current) => <FavouriteWallEntity>[
              ...current.where((wall) => !chunk.contains(wall.id)),
              ...cachedBefore.where((wall) => chunk.contains(wall.id)),
            ],
          );
          rethrow;
        }
      }
      return Result.success(true);
    } catch (error) {
      return Result.error(ServerFailure('Unable to clear favourite walls: $error'));
    }
  }
}
