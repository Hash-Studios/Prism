import 'dart:async';

import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/favourite_walls/data/favourite_wall_doc_mapper.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_merger.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

/// The signed-in user's favourites as the server last reported them.
class FavouritesSyncUpdate {
  const FavouritesSyncUpdate({required this.userId, required this.items});

  final String userId;
  final List<FavouriteWallEntity> items;
}

/// Keeps the local heart set and the favourites list in step with `usersv2/{uid}/images`.
/// It listens for the whole session, so a favourite saved on another device shows up here.
@lazySingleton
class FavouritesSyncService {
  FavouritesSyncService(this._firestoreClient, this._favoritesLocal, this._guestMerger);

  final FirestoreClient _firestoreClient;
  final FavoritesLocalDataSource _favoritesLocal;
  final GuestFavouritesMerger _guestMerger;

  final StreamController<FavouritesSyncUpdate> _updates = StreamController<FavouritesSyncUpdate>.broadcast();
  // stop() cancels it.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _subscription;
  String? _activeUserId;
  FavouritesSyncUpdate? _latest;
  final Set<String> _retryingUsers = <String>{};

  String _imagesPath(String uid) => 'usersv2/$uid/images';

  /// Calls [onUpdate] with the latest update at once, if there is one, then with each new one.
  StreamSubscription<FavouritesSyncUpdate> listen(void Function(FavouritesSyncUpdate update) onUpdate) {
    final FavouritesSyncUpdate? latest = _latest;
    if (latest != null) scheduleMicrotask(() => onUpdate(latest));
    return _updates.stream.listen(onUpdate);
  }

  /// Starts the listener for [userId], then moves any guest favourites into the account.
  /// Calling it again for the same user keeps the running listener.
  Future<void> start(String userId) async {
    final String uid = userId.trim();
    if (uid.isEmpty) {
      await stop();
      return;
    }
    if (_activeUserId != uid) {
      await stop();
      _activeUserId = uid;
      _subscription = _firestoreClient
          .watchQueryWithMetadata<FavouriteWallEntity>(
            FirestoreQuerySpec(collection: _imagesPath(uid), sourceTag: 'favourite_walls.watch', isStream: true),
            (data, docId) => mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(data), docId),
          )
          .asyncMap((snapshot) => _apply(uid, snapshot.items, isFromCache: snapshot.isFromCache))
          .listen(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              logger.w('Favourites sync stream failed.', tag: 'Favourites', error: error, stackTrace: stackTrace);
            },
          );
    }
    try {
      await _guestMerger.mergeInto(uid);
    } catch (error, stackTrace) {
      logger.w(
        'Guest favourites merge failed; they stay on this device.',
        tag: 'Favourites',
        error: error,
        stackTrace: stackTrace,
      );
    }
    unawaited(_retryPending(uid));
  }

  Future<void> stop() async {
    final StreamSubscription<void>? subscription = _subscription;
    _subscription = null;
    _activeUserId = null;
    _latest = null;
    await subscription?.cancel();
  }

  Future<void> _apply(String uid, List<FavouriteWallEntity> items, {required bool isFromCache}) async {
    if (app_state.prismUser.id != uid) {
      await stop();
      return;
    }
    // A cold cache looks like an account with no favourites. Wait for the server before believing it.
    if (isFromCache && items.isEmpty) return;
    final local = await _favoritesLocal.readWallSnapshot(uid);
    final merged = await _favoritesLocal.mergeServerWallSnapshot(uid, <FavouriteWallEntity>[
      ...items,
      ...local.where(_isBundledStarter),
    ]);
    if (app_state.prismUser.id != uid) return;
    final FavouritesSyncUpdate update = FavouritesSyncUpdate(userId: uid, items: merged);
    _latest = update;
    _updates.add(update);
    if (!isFromCache) unawaited(_retryPending(uid));
  }

  Future<void> _retryPending(String uid) async {
    if (!_retryingUsers.add(uid)) return;
    try {
      var delay = const Duration(seconds: 2);
      while (_activeUserId == uid && app_state.prismUser.id == uid) {
        final operations = await _favoritesLocal.readFavouriteOperations(uid);
        var hasPending = false;
        for (final entry in operations.entries) {
          if (_activeUserId != uid || app_state.prismUser.id != uid) return;
          final operation = entry.value;
          if (operation['status'] != 'pending' || operation['owner'] != uid) continue;
          if (_isBundledStarterOperation(entry.key, operation)) {
            await _favoritesLocal.updateFavouriteOperationStatus(
              uid,
              entry.key,
              operation['operationId']?.toString() ?? '',
              status: 'synced',
            );
            continue;
          }
          hasPending = true;
          final String operationId = operation['operationId']?.toString() ?? '';
          try {
            final bool sent = await _favoritesLocal.runFavouriteOperationsIfCurrent(
              uid,
              <String, String>{entry.key: operationId},
              () async {
                if (operation['desired'] == true && operation['wall'] != null) {
                  await _firestoreClient
                      .setDoc(
                        _imagesPath(uid),
                        entry.key,
                        FavouriteWallDocDto.fromJson(Map<String, dynamic>.from(operation['wall']! as Map)).toJson(),
                        sourceTag: 'favourite_walls.retry.set',
                      )
                      .timeout(const Duration(seconds: 8));
                } else {
                  await _firestoreClient
                      .deleteDoc(_imagesPath(uid), entry.key, sourceTag: 'favourite_walls.retry.delete')
                      .timeout(const Duration(seconds: 8));
                }
              },
            );
            if (!sent) continue;
            if (_activeUserId != uid || app_state.prismUser.id != uid) return;
            await _favoritesLocal.updateFavouriteOperationStatus(uid, entry.key, operationId, status: 'synced');
          } on TimeoutException catch (error) {
            await _favoritesLocal.updateFavouriteOperationStatus(
              uid,
              entry.key,
              operationId,
              status: 'pending',
              error: error.toString(),
            );
          } catch (error, stackTrace) {
            if (_activeUserId != uid || app_state.prismUser.id != uid) return;
            final bool rejected = error is FirestoreError && error.code == 'permission-denied';
            final bool changed = await _favoritesLocal.updateFavouriteOperationStatus(
              uid,
              entry.key,
              operationId,
              status: rejected ? 'rejected' : 'pending',
              error: error.toString(),
            );
            if (changed && rejected && _activeUserId == uid && app_state.prismUser.id == uid) {
              await _publishOperationStatus(uid, entry.key, operation, FavouriteSyncStatus.rejected);
            }
            logger.w('Favourite retry failed.', tag: 'Favourites', error: error, stackTrace: stackTrace);
          }
        }
        if (!hasPending) return;
        await Future<void>.delayed(delay);
        delay = Duration(seconds: (delay.inSeconds * 2).clamp(2, 60));
      }
    } finally {
      _retryingUsers.remove(uid);
    }
  }

  bool _isBundledStarter(FavouriteWallEntity wall) => BundledWallpapers.isStarterIdentity(wall.id, wall.source);

  bool _isBundledStarterOperation(String id, Map<String, Object?> operation) {
    final wall = operation['wall'];
    if (wall == null) return false;
    final dto = FavouriteWallDocDto.fromJson(Map<String, dynamic>.from(wall as Map));
    return BundledWallpapers.isStarterIdentity(id, WallpaperSourceX.fromWire(dto.provider));
  }

  FavouriteWallEntity? _operationWall(String id, Map<String, Object?> operation) {
    if (operation['desired'] != true || operation['wall'] == null) return null;
    return mapFavouriteWallDoc(FavouriteWallDocDto.fromJson(Map<String, dynamic>.from(operation['wall']! as Map)), id);
  }

  Future<void> _publishOperationStatus(
    String uid,
    String wallId,
    Map<String, Object?> operation,
    FavouriteSyncStatus status,
  ) async {
    final wall = _operationWall(wallId, operation);
    if (wall == null) return;
    final snapshot = await _favoritesLocal.readWallSnapshot(uid);
    if (_activeUserId != uid || app_state.prismUser.id != uid) return;
    final items = await _favoritesLocal.mergeServerWallSnapshot(uid, <FavouriteWallEntity>[
      ...snapshot.where((item) => item.id != wallId),
      wall.withSyncStatus(status),
    ]);
    if (_activeUserId != uid || app_state.prismUser.id != uid) return;
    final update = FavouritesSyncUpdate(userId: uid, items: items);
    _latest = update;
    _updates.add(update);
  }
}
