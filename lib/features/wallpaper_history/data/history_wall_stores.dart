import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

const int recentlyViewedLimit = 100;
const int syncedHistoryLimit = 500;
const int _maxBatchWrites = 400;
const Duration _networkTimeout = Duration(seconds: 15);

/// A JSON list of [HistoryWall]s in the local settings box, with a memory copy.
class _LocalHistoryList {
  _LocalHistoryList(this._settings, this._key);

  final SettingsLocalDataSource _settings;
  final String _key;
  List<HistoryWall>? _cache;

  List<HistoryWall> read() {
    final List<HistoryWall>? cached = _cache;
    if (cached != null) return cached;
    List<HistoryWall> loaded = <HistoryWall>[];
    try {
      final Object? decoded = jsonDecode(_settings.get<String>(_key, defaultValue: '[]'));
      if (decoded is List) loaded = decoded.map(HistoryWall.tryParse).nonNulls.toList(growable: false);
    } catch (error, stackTrace) {
      logger.w('History list $_key could not be read', error: error, stackTrace: stackTrace);
    }
    return _cache = loaded;
  }

  Future<void> save(List<HistoryWall> next) {
    _cache = List<HistoryWall>.unmodifiable(next);
    return _settings.set(_key, jsonEncode(next.map((item) => item.toJson()).toList(growable: false)));
  }
}

/// Walls the user looked at on this device. It never leaves the device.
@lazySingleton
class RecentlyViewedStore {
  RecentlyViewedStore(this._settings) : _list = _LocalHistoryList(_settings, PersistenceKeys.viewedHistoryItems);

  final SettingsLocalDataSource _settings;
  final _LocalHistoryList _list;

  /// The Save viewing history setting. On by default.
  bool get enabled => _settings.get<bool>(PersistenceKeys.viewedHistoryEnabled, defaultValue: true);

  /// Turning it off also clears the list.
  Future<void> setEnabled(bool value) async {
    await _settings.set(PersistenceKeys.viewedHistoryEnabled, value);
    if (!value) await clear();
  }

  List<HistoryWall> items() => _list.read();

  /// Moves [item] to the top. Does nothing while the setting is off.
  Future<void> record(HistoryWall item) async {
    if (!enabled) return;
    await _list.save(
      mergeHistory(<HistoryWall>[item.copyWith(action: HistoryAction.view)], items(), cap: recentlyViewedLimit),
    );
  }

  Future<void> clear() => _list.save(const <HistoryWall>[]);
}

/// Walls the user set or downloaded, kept on the device and in `usersv2/{uid}/history` for a signed-in user.
/// It writes only on a set or a download, one doc per wall, so the cost stays small.
@lazySingleton
class SyncedHistoryStore {
  SyncedHistoryStore(this._settings, this._firestore, {@ignoreParam String Function()? ownerId})
    : _ownerId = ownerId ?? _signedInId,
      _list = _LocalHistoryList(_settings, PersistenceKeys.syncedHistoryItems);

  final SettingsLocalDataSource _settings;
  final FirestoreClient _firestore;
  final String Function() _ownerId;
  final _LocalHistoryList _list;

  static String _signedInId() => app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';

  static String collectionFor(String uid) => '${FirebaseCollections.usersV2}/$uid/history';

  List<HistoryWall> items() => _list.read();

  /// Saves [item], keeps the newest [syncedHistoryLimit], and mirrors both to the account.
  Future<void> record(HistoryWall item) async {
    final List<HistoryWall> before = items();
    final List<HistoryWall> next = mergeHistory(<HistoryWall>[item], before, cap: syncedHistoryLimit);
    await _list.save(next);
    final String uid = _ownerId();
    if (uid.isEmpty) return;
    final HistoryWall? kept = next.where((entry) => entry.key == item.key).firstOrNull;
    final Set<String> keys = next.map((entry) => entry.key).toSet();
    final Iterable<String> dropped = before.map((entry) => entry.key).where((key) => !keys.contains(key));
    _send(uid, upserts: <HistoryWall>[?kept], deletes: dropped, sourceTag: 'wallpaper_history.synced.record');
  }

  /// Removes one wall here and in the account.
  Future<void> remove(String key) async {
    final List<HistoryWall> before = items();
    if (!before.any((entry) => entry.key == key)) return;
    await _list.save(before.where((entry) => entry.key != key).toList(growable: false));
    final String uid = _ownerId();
    if (uid.isEmpty) return;
    _send(uid, deletes: <String>[key], sourceTag: 'wallpaper_history.synced.remove');
  }

  /// Clears the list here and every doc in the account.
  Future<void> clear() async {
    await _list.save(const <HistoryWall>[]);
    final String uid = _ownerId();
    if (uid.isEmpty) return;
    final List<String> keys = await _firestore
        .query<String>(
          FirestoreQuerySpec(collection: collectionFor(uid), sourceTag: 'wallpaper_history.synced.clear.list'),
          (_, docId) => docId,
        )
        .timeout(_networkTimeout);
    await _write(uid, deletes: keys, sourceTag: 'wallpaper_history.synced.clear');
  }

  /// Forgets the device copy only, as on sign-out. The account keeps its history.
  Future<void> clearLocal() async {
    await _list.save(const <HistoryWall>[]);
    await _settings.delete(PersistenceKeys.syncedHistoryRestoredFor);
  }

  /// Merges the account history with this device once per account: the newest of each wall wins, at most
  /// [syncedHistoryLimit]. Walls only on this device, and [seed], go up to the account. Returns how many walls the
  /// account had. Throws when the network step fails, so the next launch tries again.
  Future<int> restore(String uid, {Iterable<HistoryWall> seed = const <HistoryWall>[]}) async {
    if (uid.isEmpty || _settings.get<String>(PersistenceKeys.syncedHistoryRestoredFor, defaultValue: '') == uid) {
      return 0;
    }
    final List<HistoryWall> server =
        (await _firestore
                .query<HistoryWall?>(
                  FirestoreQuerySpec(
                    collection: collectionFor(uid),
                    sourceTag: 'wallpaper_history.synced.restore',
                    orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'at', descending: true)],
                    limit: syncedHistoryLimit,
                  ),
                  (data, _) => HistoryWall.tryParse(data),
                )
                .timeout(_networkTimeout))
            .nonNulls
            .toList(growable: false);
    if (_ownerId() != uid) return 0;
    final List<HistoryWall> merged = mergeHistory(server, <HistoryWall>[...items(), ...seed], cap: syncedHistoryLimit);
    await _list.save(merged);
    final Map<String, HistoryWall> onServer = <String, HistoryWall>{
      for (final HistoryWall entry in server) entry.key: entry,
    };
    final Set<String> keys = merged.map((entry) => entry.key).toSet();
    await _write(
      uid,
      upserts: merged.where((entry) => onServer[entry.key] != entry),
      deletes: server.map((entry) => entry.key).where((key) => !keys.contains(key)),
      sourceTag: 'wallpaper_history.synced.restore_merge',
    );
    await _settings.set(PersistenceKeys.syncedHistoryRestoredFor, uid);
    return server.length;
  }

  /// Starts a write without waiting for the server. Offline, Firestore queues it and the list here is already right.
  void _send(
    String uid, {
    Iterable<HistoryWall> upserts = const <HistoryWall>[],
    Iterable<String> deletes = const <String>[],
    required String sourceTag,
  }) {
    unawaited(
      _write(uid, upserts: upserts, deletes: deletes, sourceTag: sourceTag).catchError((Object error, StackTrace st) {
        logger.w('Account history write failed ($sourceTag).', error: error, stackTrace: st);
      }),
    );
  }

  Future<void> _write(
    String uid, {
    Iterable<HistoryWall> upserts = const <HistoryWall>[],
    Iterable<String> deletes = const <String>[],
    required String sourceTag,
  }) async {
    final String path = collectionFor(uid);
    final List<void Function(FirestoreBatch batch)> writes = <void Function(FirestoreBatch batch)>[
      for (final HistoryWall entry in upserts) (batch) => batch.setDoc(path, entry.key, entry.toDoc()),
      for (final String key in deletes) (batch) => batch.deleteDoc(path, key),
    ];
    for (int start = 0; start < writes.length; start += _maxBatchWrites) {
      final Iterable<void Function(FirestoreBatch batch)> chunk = writes.sublist(
        start,
        math.min(start + _maxBatchWrites, writes.length),
      );
      await _firestore.runBatch((batch) async {
        for (final write in chunk) {
          write(batch);
        }
      }, sourceTag: sourceTag);
    }
  }
}

/// The walls in the applied history that can sync: catalogue walls with a public thumbnail.
Iterable<HistoryWall> appliedHistoryForSync(WallpaperHistoryStore store) => store
    .items()
    .map(
      (item) => HistoryWall.tryCreate(
        id: item.wallpaperId,
        source: WallpaperSourceX.fromWire(item.source),
        thumbnailUrl: item.thumbnailUrl,
        action: HistoryAction.set,
        at: item.appliedAt,
      ),
    )
    .nonNulls;

/// Restores the account history on this device once. Safe to call at each launch and sign-in.
Future<void> restoreAccountHistory(String uid) async {
  if (!getIt.isRegistered<SyncedHistoryStore>()) return;
  try {
    final Iterable<HistoryWall> seed = getIt.isRegistered<WallpaperHistoryStore>()
        ? appliedHistoryForSync(getIt<WallpaperHistoryStore>())
        : const <HistoryWall>[];
    final int restored = await getIt<SyncedHistoryStore>().restore(uid.trim(), seed: seed);
    if (restored > 0) unawaited(analytics.track(HistoryRestoredEvent(countBucket: historyCountBucket(restored))));
  } catch (error, stackTrace) {
    logger.w('Account history did not restore; the next launch tries again.', error: error, stackTrace: stackTrace);
  }
}

/// A coarse count for analytics.
String historyCountBucket(int count) => switch (count) {
  <= 0 => '0',
  1 => '1',
  <= 5 => '2-5',
  <= 20 => '6-20',
  <= 100 => '21-100',
  _ => '101+',
};
