import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

const int _maxBatchDeletes = 400;

/// A Firestore write waits for the server. Offline it never completes, so the app stops waiting
/// after this long. The SDK keeps the write and sends it when the network returns.
const Duration _writeTimeout = Duration(seconds: 8);

@LazySingleton(as: FavouriteWallsRepository)
class FavouriteWallsRepositoryImpl implements FavouriteWallsRepository {
  FavouriteWallsRepositoryImpl(this._firestoreClient, this._favoritesLocal, this._guestStore);

  final FirestoreClient _firestoreClient;
  final FavoritesLocalDataSource _favoritesLocal;
  final GuestFavouritesStore _guestStore;

  String _collectionPath(String userId) => 'usersv2/$userId/images';

  Future<List<FavouriteWallEntity>> _read(String userId) async {
    if (userId.isEmpty) {
      final Map<String, Map<String, Object?>> saved = await _guestStore.readAll();
      return saved.entries
          .map(
            (entry) =>
                mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(Map<String, dynamic>.of(entry.value)), entry.key),
          )
          .toList()
        ..sort(compareByCreatedAtDesc);
    }
    final rows = await _firestoreClient.query<({String docId, FavouriteWallDocDto doc})>(
      FirestoreQuerySpec(
        collection: _collectionPath(userId),
        sourceTag: 'favourite_walls.read',
        cachePolicy: FirestoreCachePolicy.memoryFirst,
        dedupeWindowMs: 1500,
      ),
      (data, docId) => (docId: docId, doc: FavouriteWallDocDto.fromJson(data)),
    );
    final items = rows.map((row) => mapFavouriteWallDoc(row.doc, row.docId)).toList();

    items.sort(compareByCreatedAtDesc);

    return items;
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async {
    try {
      final items = await _read(userId);
      await _favoritesLocal.replaceWallFavourites(userId, items.map((item) => item.id));
      return Result.success(items);
    } catch (error) {
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
      if (userId.isEmpty) {
        if (add) {
          await _guestStore.put(wall.id, favouriteWallToDoc(wall));
        } else {
          await _guestStore.remove(<String>[wall.id]);
        }
        await _favoritesLocal.setWallFavourite(userId, wall.id, add);
        return Result.success(add);
      }
      await _favoritesLocal.setWallFavourite(userId, wall.id, add);
      final Future<void> write = add
          ? _firestoreClient.setDoc(
              _collectionPath(userId),
              wall.id,
              favouriteWallToDoc(wall),
              sourceTag: 'favourite_walls.toggle.set',
            )
          : _firestoreClient.deleteDoc(_collectionPath(userId), wall.id, sourceTag: 'favourite_walls.toggle.delete');
      try {
        await write.timeout(_writeTimeout);
      } on TimeoutException {
        logger.w('Favourite write queued offline for ${wall.id}.', tag: 'Favourites');
      } catch (_) {
        await _favoritesLocal.setWallFavourite(userId, wall.id, !add);
        rethrow;
      }
      return Result.success(add);
    } catch (error) {
      return Result.error(ServerFailure('Unable to toggle favourite wall: $error'));
    }
  }

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
        for (final String id in chunk) {
          await _favoritesLocal.setWallFavourite(userId, id, false);
        }
        try {
          await _firestoreClient
              .runBatch((batch) async {
                for (final String id in chunk) {
                  batch.deleteDoc(_collectionPath(userId), id);
                }
              }, sourceTag: 'favourite_walls.clear_all.delete')
              .timeout(_writeTimeout);
        } on TimeoutException {
          logger.w('Favourite clear queued offline for ${chunk.length} walls.', tag: 'Favourites');
        } catch (_) {
          for (final String id in chunk) {
            await _favoritesLocal.setWallFavourite(userId, id, true);
          }
          rethrow;
        }
      }
      return Result.success(true);
    } catch (error) {
      return Result.error(ServerFailure('Unable to clear favourite walls: $error'));
    }
  }
}
