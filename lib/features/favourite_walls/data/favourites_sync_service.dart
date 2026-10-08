import 'dart:async';

import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
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
    await _favoritesLocal.replaceWallFavourites(uid, items.map((item) => item.id));
    final FavouritesSyncUpdate update = FavouritesSyncUpdate(userId: uid, items: items);
    _latest = update;
    _updates.add(update);
  }
}
