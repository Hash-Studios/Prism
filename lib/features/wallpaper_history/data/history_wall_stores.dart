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
import 'package:flutter/foundation.dart';
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
  Future<void>? _tail;
  int _clearVersion = 0;

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
    return _cache = List<HistoryWall>.unmodifiable(loaded);
  }

  Future<T> serialize<T>(Future<T> Function() action) {
    final Future<T> result = (_tail ?? Future<void>.value()).then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> clear({Future<void> Function()? afterClear}) {
    _clearVersion++;
    _cache = const <HistoryWall>[];
    return serialize(() async {
      try {
        await _settings.set(_key, '[]');
      } finally {
        await afterClear?.call();
      }
    });
  }

  Future<List<HistoryWall>?> update(
    List<HistoryWall> Function(List<HistoryWall> current) transform, {
    bool Function()? isCurrent,
  }) {
    final int version = _clearVersion;
    bool current() => version == _clearVersion && (isCurrent?.call() ?? true);
    return serialize(() async {
      if (!current()) return null;
      final List<HistoryWall> next = transform(read());
      await _settings.set(_key, jsonEncode(next.map((item) => item.toJson()).toList(growable: false)));
      if (!current()) return null;
      return _cache = List<HistoryWall>.unmodifiable(next);
    });
  }
}

/// Walls the user looked at on this device. It never leaves the device.
@lazySingleton
class RecentlyViewedStore extends ChangeNotifier {
  RecentlyViewedStore(this._settings) : _list = _LocalHistoryList(_settings, PersistenceKeys.viewedHistoryItems);

  final SettingsLocalDataSource _settings;
  final _LocalHistoryList _list;

  /// The Save viewing history setting. On by default.
  bool get enabled => _settings.get<bool>(PersistenceKeys.viewedHistoryEnabled, defaultValue: true);

  /// Turning it off also clears the list.
  Future<void> setEnabled(bool value) async {
    await _settings.set(PersistenceKeys.viewedHistoryEnabled, value);
    if (!value) {
      await clear();
    } else {
      notifyListeners();
    }
  }

  List<HistoryWall> items() => _list.read();

  /// Moves [item] to the top. Does nothing while the setting is off.
  Future<void> record(HistoryWall item) async {
    if (!enabled) return;
    await _list.update(
      (current) =>
          mergeHistory(<HistoryWall>[item.copyWith(action: HistoryAction.view)], current, cap: recentlyViewedLimit),
      isCurrent: () => enabled,
    );
    notifyListeners();
  }

  Future<void> clear() async {
    await _list.clear();
    notifyListeners();
  }
}

/// Walls the user set or downloaded, kept on the device and in `usersv2/{uid}/history` for a signed-in user.
/// It writes only on a set or a download, one doc per wall, so the cost stays small.
@lazySingleton
class SyncedHistoryStore extends ChangeNotifier {
  SyncedHistoryStore(this._settings, this._firestore, {@ignoreParam String Function()? ownerId})
    : _ownerId = ownerId ?? _signedInId,
      _list = _LocalHistoryList(_settings, PersistenceKeys.syncedHistoryItems);

  final SettingsLocalDataSource _settings;
  final FirestoreClient _firestore;
  final String Function() _ownerId;
  final _LocalHistoryList _list;
  int _mutationVersion = 0;
  int _accountEpoch = 0;
  final Map<(String, int, int), Future<int>> _restores = <(String, int, int), Future<int>>{};

  bool _current(String uid, int epoch) => _accountEpoch == epoch && _ownerId() == uid;

  static String _signedInId() => app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';

  static String collectionFor(String uid) => '${FirebaseCollections.usersV2}/$uid/history';

  /// Capture before an asynchronous action, then compare before recording its completion.
  (String, int) get recordingSession => (_ownerId(), _accountEpoch);

  List<HistoryWall> items() => _list.read();

  /// Saves [item], keeps the newest [syncedHistoryLimit], and mirrors both to the account.
  Future<void> record(HistoryWall item) async {
    final String uid = _ownerId();
    final int epoch = _accountEpoch;
    List<HistoryWall> before = <HistoryWall>[];
    final List<HistoryWall>? next = await _list.update((current) {
      before = current;
      return mergeHistory(<HistoryWall>[item], current, cap: syncedHistoryLimit);
    }, isCurrent: () => epoch == _accountEpoch);
    if (next == null) return;
    notifyListeners();
    if (uid.isEmpty || !_current(uid, epoch)) return;
    final HistoryWall? kept = next.where((entry) => entry.key == item.key).firstOrNull;
    final Set<String> keys = next.map((entry) => entry.key).toSet();
    final Iterable<String> dropped = before.map((entry) => entry.key).where((key) => !keys.contains(key));
    _send(
      uid,
      epoch: epoch,
      upserts: <HistoryWall>[?kept],
      deletes: dropped,
      sourceTag: 'wallpaper_history.synced.record',
    );
  }

  /// Removes one wall here and in the account.
  Future<void> remove(String key) async {
    _mutationVersion++;
    final String uid = _ownerId();
    final int epoch = _accountEpoch;
    bool removed = false;
    await _list.update((before) {
      removed = before.any((entry) => entry.key == key);
      return before.where((entry) => entry.key != key).toList(growable: false);
    }, isCurrent: () => epoch == _accountEpoch);
    if (!removed) return;
    notifyListeners();
    if (uid.isEmpty || !_current(uid, epoch)) return;
    _send(uid, epoch: epoch, deletes: <String>[key], sourceTag: 'wallpaper_history.synced.remove');
  }

  /// Clears the list here and every doc in the account.
  /// A signed-in clear reads the account first, so an offline clear throws and keeps both copies instead of leaving
  /// account docs that come back on another phone.
  Future<void> clear() async {
    final String uid = _ownerId();
    final int epoch = _accountEpoch;
    final List<String> keys = uid.isEmpty
        ? const <String>[]
        : await _firestore
              .query<String>(
                FirestoreQuerySpec(
                  collection: collectionFor(uid),
                  sourceTag: 'wallpaper_history.synced.clear.list',
                  cachePolicy: FirestoreCachePolicy.serverOnly,
                ),
                (_, docId) => docId,
              )
              .timeout(_networkTimeout);
    if (uid.isNotEmpty && !_current(uid, epoch)) return;
    _mutationVersion++;
    final Set<String> deleteKeys = <String>{...keys, ...items().map((item) => item.key)};
    await _list.clear();
    notifyListeners();
    if (uid.isEmpty) return;
    _send(uid, epoch: epoch, deletes: deleteKeys, sourceTag: 'wallpaper_history.synced.clear');
  }

  /// Forgets the device copy only, as on sign-out. The account keeps its history.
  Future<void> clearLocal() async {
    _accountEpoch++;
    await _list.clear(afterClear: () => _settings.delete(PersistenceKeys.syncedHistoryRestoredFor));
    notifyListeners();
  }

  /// Merges the account history with this device once per account: the newest of each wall wins, at most
  /// [syncedHistoryLimit]. Walls only on this device, and [seed], go up to the account. Returns how many walls the
  /// account had. Throws when the network step fails, so the next launch tries again.
  Future<int> restore(String uid, {Iterable<HistoryWall> seed = const <HistoryWall>[]}) {
    uid = uid.trim();
    final (String, int, int) key = (uid, _accountEpoch, _mutationVersion);
    final Future<int>? pending = _restores[key];
    if (pending != null) return pending;
    final Future<int> future = _restore(uid, epoch: key.$2, version: key.$3, seed: seed);
    _restores[key] = future;
    return future.whenComplete(() {
      if (identical(_restores[key], future)) _restores.remove(key);
    });
  }

  Future<int> _restore(
    String uid, {
    required int epoch,
    required int version,
    required Iterable<HistoryWall> seed,
  }) async {
    bool current() => _current(uid, epoch) && version == _mutationVersion;
    if (uid.isEmpty || !current()) return 0;
    final bool restored = await _list.serialize(
      () async => _settings.get<String>(PersistenceKeys.syncedHistoryRestoredFor, defaultValue: '') == uid,
    );
    if (restored || !current()) return 0;
    final List<HistoryWall> server =
        (await _firestore
                .query<HistoryWall?>(
                  FirestoreQuerySpec(
                    collection: collectionFor(uid),
                    sourceTag: 'wallpaper_history.synced.restore',
                    orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'at', descending: true)],
                    cachePolicy: FirestoreCachePolicy.serverOnly,
                  ),
                  (data, _) => HistoryWall.tryParse(data),
                )
                .timeout(_networkTimeout))
            .nonNulls
            .toList(growable: false);
    if (!current()) return 0;
    final List<HistoryWall>? merged = await _list.update(
      (current) => mergeHistory(server, <HistoryWall>[...current, ...seed], cap: syncedHistoryLimit),
      isCurrent: current,
    );
    if (merged == null || !current()) return 0;
    notifyListeners();
    final Map<String, HistoryWall> onServer = <String, HistoryWall>{
      for (final HistoryWall entry in server) entry.key: entry,
    };
    final Set<String> keys = merged.map((entry) => entry.key).toSet();
    await _write(
      uid,
      epoch: epoch,
      upserts: merged.where((entry) => onServer[entry.key] != entry),
      deletes: server.map((entry) => entry.key).where((key) => !keys.contains(key)),
      sourceTag: 'wallpaper_history.synced.restore_merge',
    );
    return _list.serialize(() async {
      if (!current()) return 0;
      await _settings.set(PersistenceKeys.syncedHistoryRestoredFor, uid);
      return current() ? server.length : 0;
    });
  }

  /// Starts a write without waiting for the server. Offline, Firestore queues it and the list here is already right.
  void _send(
    String uid, {
    required int epoch,
    Iterable<HistoryWall> upserts = const <HistoryWall>[],
    Iterable<String> deletes = const <String>[],
    required String sourceTag,
  }) {
    unawaited(
      _write(uid, epoch: epoch, upserts: upserts, deletes: deletes, sourceTag: sourceTag).catchError((
        Object error,
        StackTrace st,
      ) {
        logger.w('Account history write failed ($sourceTag).', error: error, stackTrace: st);
      }),
    );
  }

  Future<void> _write(
    String uid, {
    required int epoch,
    Iterable<HistoryWall> upserts = const <HistoryWall>[],
    Iterable<String> deletes = const <String>[],
    required String sourceTag,
  }) async {
    final String path = collectionFor(uid);
    final List<void Function(FirestoreBatch batch)> writes = <void Function(FirestoreBatch batch)>[
      for (final HistoryWall entry in upserts)
        (batch) {
          final HistoryWall? latest = items().where((item) => item.key == entry.key).firstOrNull;
          if (latest != null) batch.setDoc(path, latest.key, latest.toDoc());
        },
      for (final String key in deletes)
        (batch) {
          if (!items().any((item) => item.key == key)) batch.deleteDoc(path, key);
        },
    ];
    final List<Future<void>> pending = <Future<void>>[];
    for (int start = 0; start < writes.length; start += _maxBatchWrites) {
      if (!_current(uid, epoch)) break;
      final Iterable<void Function(FirestoreBatch batch)> chunk = writes.sublist(
        start,
        math.min(start + _maxBatchWrites, writes.length),
      );
      pending.add(
        _firestore.runBatch((batch) async {
          if (!_current(uid, epoch)) return;
          for (final write in chunk) {
            write(batch);
          }
        }, sourceTag: sourceTag),
      );
    }
    await Future.wait(pending);
  }
}

/// The walls in the applied history that can sync: catalogue walls with a public thumbnail.
Iterable<HistoryWall> appliedHistoryForSync(WallpaperHistoryStore store) => store.items().map((item) {
  final WallpaperSource source = WallpaperSourceX.fromWire(item.source);
  final String? thumbnail = source == WallpaperSource.prism && item.thumbnailUrl == item.fullUrl
      ? null
      : item.thumbnailUrl;
  return HistoryWall.tryCreate(
    id: item.wallpaperId,
    source: source,
    thumbnailUrl: thumbnail,
    action: HistoryAction.set,
    at: item.appliedAt,
  );
}).nonNulls;

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
