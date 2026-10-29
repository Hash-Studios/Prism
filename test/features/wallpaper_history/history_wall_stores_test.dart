import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _Batch implements FirestoreBatch {
  _Batch(this.ops, this.documents);

  final List<String> ops;
  final Map<String, Map<String, dynamic>> documents;

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data) {
    ops.add('set:$collection/$id');
    documents['$collection/$id'] = data;
  }

  @override
  void deleteDoc(String collection, String id) => ops.add('delete:$collection/$id');

  @override
  void addDoc(String collection, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  void updateDoc(String collection, String id, Map<String, dynamic> data) => throw UnimplementedError();
}

class _FakeFirestore extends Fake implements FirestoreClient {
  final List<String> ops = <String>[]; // 'set:<collection>/<id>' or 'delete:<collection>/<id>'
  List<Map<String, dynamic>> serverDocs = <Map<String, dynamic>>[]; // returned by query
  List<String> serverIds = <String>[];
  Object? throwOnQuery;
  int batches = 0;
  int queries = 0;
  Completer<void>? queryGate;
  Completer<void>? batchGate;
  final Map<String, Map<String, dynamic>> documents = <String, Map<String, dynamic>>{};
  final Map<String, Completer<void>> actionGates = <String, Completer<void>>{};
  final List<FirestoreQuerySpec> querySpecs = <FirestoreQuerySpec>[];

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    queries++;
    querySpecs.add(spec);
    final List<(String, Map<String, dynamic>)> rows = <(String, Map<String, dynamic>)>[
      for (int i = 0; i < serverIds.length; i++)
        (serverIds[i], i < serverDocs.length ? serverDocs[i] : const <String, dynamic>{}),
    ];
    for (final FirestoreOrderBy order in spec.orderBy.reversed) {
      rows.sort((a, b) {
        final int comparison = (a.$2[order.field] as DateTime).compareTo(b.$2[order.field] as DateTime);
        return order.descending ? -comparison : comparison;
      });
    }
    await queryGate?.future;
    if (throwOnQuery != null) throw throwOnQuery!;
    return rows.take(spec.limit ?? rows.length).map((row) => map(row.$2, row.$1)).toList();
  }

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) async {
    batches++;
    final Completer<void>? gate = actionGates[sourceTag];
    if (gate != null) await gate.future;
    await action(_Batch(ops, documents));
    await batchGate?.future;
  }
}

class _FailingSetLocalStore extends InMemoryLocalStore {
  bool fail = true;

  @override
  Future<void> set(String key, Object? value) async {
    if (fail) throw StateError('write failed');
    await super.set(key, value);
  }
}

class _GatedSetLocalStore extends InMemoryLocalStore {
  _GatedSetLocalStore([this.gate]);

  Completer<void>? gate;

  @override
  Future<void> set(String key, Object? value) async {
    await gate?.future;
    await super.set(key, value);
  }
}

class _GatedMarkerLocalStore extends InMemoryLocalStore {
  final Completer<void> firstMarker = Completer<void>();
  final Completer<void> markerStarted = Completer<void>();
  int _markers = 0;

  @override
  Future<void> set(String key, Object? value) async {
    if (key == PersistenceKeys.settings(PersistenceKeys.syncedHistoryRestoredFor) && _markers++ == 0) {
      markerStarted.complete();
      await firstMarker.future;
    }
    await super.set(key, value);
  }
}

HistoryWall _wall(String id, DateTime at, {HistoryAction action = HistoryAction.set}) => HistoryWall.tryCreate(
  id: id,
  source: WallpaperSource.wallhaven,
  thumbnailUrl: 'https://th.wallhaven.cc/small/ab/$id.jpg',
  action: action,
  at: at,
)!;

final DateTime _base = DateTime.utc(2026, 10, 20);

void main() {
  late InMemoryLocalStore backing;
  late SettingsLocalDataSource settings;
  late _FakeFirestore firestore;
  late String uid;

  setUp(() {
    backing = InMemoryLocalStore();
    settings = SettingsLocalDataSource(backing);
    firestore = _FakeFirestore();
    uid = 'u1';
  });

  group('RecentlyViewedStore', () {
    test('record moves an existing wall to the top with no duplicate', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      await store.record(_wall('a', _base.add(const Duration(hours: 1))));
      await store.record(_wall('b', _base.add(const Duration(hours: 2))));
      await store.record(_wall('a', _base.add(const Duration(hours: 3))));
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_a', 'wallhaven_b']);
    });

    test('record stores the action as view', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      await store.record(_wall('a', _base));
      expect(store.items().single.action, HistoryAction.view);
    });

    test('caps the list at 100 and drops the oldest 5', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      for (int i = 0; i < 105; i++) {
        await store.record(_wall('w$i', _base.add(Duration(minutes: i))));
      }
      expect(store.items(), hasLength(100));
      expect(store.items().first.id, 'w104');
      expect(store.items().last.id, 'w5');
    });

    test('is enabled by default and setEnabled(false) clears and stops recording', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      expect(store.enabled, isTrue);
      await store.record(_wall('a', _base));
      await store.setEnabled(false);
      expect(store.enabled, isFalse);
      expect(store.items(), isEmpty);
      await store.record(_wall('b', _base.add(const Duration(minutes: 1))));
      expect(store.items(), isEmpty);
    });

    test('setEnabled(true) lets record work again', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      await store.setEnabled(false);
      await store.setEnabled(true);
      await store.record(_wall('c', _base));
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_c']);
    });

    test('clear empties the list', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      await store.record(_wall('a', _base));
      await store.clear();
      expect(store.items(), isEmpty);
    });

    test('a new store on the same settings reads the saved list', () async {
      final RecentlyViewedStore store = RecentlyViewedStore(settings);
      await store.record(_wall('a', _base.add(const Duration(hours: 1))));
      await store.record(_wall('b', _base.add(const Duration(hours: 2))));
      final RecentlyViewedStore reloaded = RecentlyViewedStore(SettingsLocalDataSource(backing));
      expect(reloaded.items().map((wall) => wall.key), <String>['wallhaven_b', 'wallhaven_a']);
    });
  });

  group('SyncedHistoryStore', () {
    test('recordingSession changes on owner switch and same-uid local cleanup', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      final (String, int) session = store.recordingSession;
      uid = 'u2';
      expect(store.recordingSession, isNot(session));
      uid = 'u1';
      await store.clearLocal();
      expect(store.recordingSession, isNot(session));
    });

    test('failed local persistence does not publish the new cache value', () async {
      final SettingsLocalDataSource failingSettings = SettingsLocalDataSource(_FailingSetLocalStore());
      final SyncedHistoryStore store = SyncedHistoryStore(failingSettings, firestore, ownerId: () => '');
      await expectLater(store.record(_wall('a', _base)), throwsStateError);
      expect(store.items(), isEmpty);
    });

    test('a failed update preserves the prior cache and does not poison subsequent updates', () async {
      final _FailingSetLocalStore local = _FailingSetLocalStore()..fail = false;
      final SyncedHistoryStore store = SyncedHistoryStore(SettingsLocalDataSource(local), firestore, ownerId: () => '');
      await store.record(_wall('a', _base));
      local.fail = true;
      await expectLater(store.record(_wall('failed', _base.add(const Duration(minutes: 1)))), throwsStateError);
      expect(store.items().single.id, 'a');
      local.fail = false;
      await store.record(_wall('b', _base.add(const Duration(minutes: 2))));
      expect(store.items().map((wall) => wall.id), <String>['b', 'a']);
    });

    test('record while signed in writes one set in one batch', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      expect(firestore.ops, <String>['set:usersv2/u1/history/wallhaven_a']);
      expect(firestore.batches, 1);
    });

    test('concurrent records enqueue writes without waiting for server acknowledgements', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      firestore.batchGate = Completer<void>();

      await store.record(_wall('a', _base));
      await store.record(_wall('b', _base.add(const Duration(minutes: 1))));

      expect(firestore.batches, 2);
      firestore.batchGate!.complete();
    });

    test('simultaneous records merge after local persistence is serialized', () async {
      final Completer<void> gate = Completer<void>();
      final SyncedHistoryStore store = SyncedHistoryStore(
        SettingsLocalDataSource(_GatedSetLocalStore(gate)),
        firestore,
        ownerId: () => uid,
      );
      final Future<void> first = store.record(_wall('a', _base));
      final Future<void> second = store.record(_wall('b', _base.add(const Duration(minutes: 1))));
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(store.items().map((wall) => wall.id), <String>['b', 'a']);
    });

    test('clearLocal invalidates queued records even when the uid remains the same', () async {
      final Completer<void> gate = Completer<void>();
      final SyncedHistoryStore store = SyncedHistoryStore(
        SettingsLocalDataSource(_GatedSetLocalStore(gate)),
        firestore,
        ownerId: () => uid,
      );
      final Future<void> first = store.record(_wall('a', _base));
      final Future<void> second = store.record(_wall('b', _base));
      await Future<void>.delayed(Duration.zero);
      final Future<void> clearing = store.clearLocal();
      expect(store.items(), isEmpty);
      gate.complete();
      await Future.wait(<Future<void>>[first, second, clearing]);
      expect(store.items(), isEmpty);
      expect(firestore.ops, isEmpty);
    });

    test('clearLocal immediately hides the prior cache while an old local write finishes', () async {
      final _GatedSetLocalStore local = _GatedSetLocalStore();
      final SyncedHistoryStore store = SyncedHistoryStore(
        SettingsLocalDataSource(local),
        firestore,
        ownerId: () => uid,
      );
      await store.record(_wall('old', _base));
      local.gate = Completer<void>();
      final Future<void> writing = store.record(_wall('pending', _base));
      await Future<void>.delayed(Duration.zero);
      final Future<void> clearing = store.clearLocal();
      expect(store.items(), isEmpty);
      local.gate!.complete();
      await Future.wait(<Future<void>>[writing, clearing]);
      expect(store.items(), isEmpty);
    });

    test('an offline clear keeps the device list and the account docs', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      await Future<void>.delayed(Duration.zero);
      firestore.ops.clear();
      firestore.throwOnQuery = StateError('offline');

      await expectLater(store.clear(), throwsStateError);

      expect(store.items().map((wall) => wall.key), <String>['wallhaven_a']);
      expect(firestore.ops, isEmpty);
    });

    test('clear supersedes a pending local record without republishing its cache', () async {
      final _GatedSetLocalStore local = _GatedSetLocalStore();
      final SyncedHistoryStore store = SyncedHistoryStore(
        SettingsLocalDataSource(local),
        firestore,
        ownerId: () => uid,
      );
      await store.record(_wall('old', _base));
      local.gate = Completer<void>();
      final Future<void> writing = store.record(_wall('pending', _base));
      await Future<void>.delayed(Duration.zero);
      final Future<void> clearing = store.clear();
      await Future<void>.delayed(Duration.zero);
      expect(store.items(), isEmpty);
      local.gate!.complete();
      await Future.wait(<Future<void>>[writing, clearing]);
      expect(store.items(), isEmpty);
    });

    test('an old restore cannot remove the marker of a new same-uid restore', () async {
      final _GatedMarkerLocalStore local = _GatedMarkerLocalStore();
      final SettingsLocalDataSource localSettings = SettingsLocalDataSource(local);
      final SyncedHistoryStore store = SyncedHistoryStore(localSettings, firestore, ownerId: () => uid);
      firestore.serverDocs = <Map<String, dynamic>>[_wall('a', _base).toDoc()];
      firestore.serverIds = <String>['wallhaven_a'];
      final Future<int> first = store.restore(uid);
      await local.markerStarted.future;
      final Future<void> clearing = store.clearLocal();
      final Future<int> second = store.restore(uid);
      await Future<void>.delayed(Duration.zero);
      local.firstMarker.complete();
      await Future.wait(<Future<Object?>>[first, clearing, second]);
      expect(localSettings.get<String>(PersistenceKeys.syncedHistoryRestoredFor, defaultValue: ''), uid);
      expect(store.items().single.id, 'a');
      expect(firestore.queries, 2);
    });

    test('a restore batch resolves current values instead of overwriting a newer record', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      final Completer<void> gate = Completer<void>();
      firestore.actionGates['wallpaper_history.synced.restore_merge'] = gate;
      final Future<int> restoring = store.restore(uid, seed: <HistoryWall>[_wall('a', _base)]);
      await Future<void>.delayed(Duration.zero);
      final DateTime newer = _base.add(const Duration(hours: 1));
      await store.record(_wall('a', newer));
      gate.complete();
      await restoring;
      expect(firestore.documents['usersv2/u1/history/wallhaven_a']!['at'], newer);
    });

    test('clearLocal invalidates deferred batch callbacks after a same-uid login', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      final Completer<void> gate = Completer<void>();
      firestore.actionGates['wallpaper_history.synced.record'] = gate;
      await store.record(_wall('a', _base));
      await store.clearLocal();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(firestore.ops, isEmpty);
    });

    test('restore enqueues every chunk before server acknowledgements and sign-out stops its marker', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      firestore.batchGate = Completer<void>();
      final Future<int> restoring = store.restore(
        uid,
        seed: <HistoryWall>[for (int i = 0; i < 500; i++) _wall('w$i', _base.add(Duration(minutes: i)))],
      );
      await Future<void>.delayed(Duration.zero);
      expect(firestore.batches, 2);
      await store.record(_wall('later', _base.add(const Duration(days: 1))));
      expect(firestore.batches, 3);
      await store.clearLocal();
      firestore.batchGate!.complete();
      expect(await restoring, 0);
      expect(settings.get<String>(PersistenceKeys.syncedHistoryRestoredFor, defaultValue: ''), isEmpty);
      expect(store.items(), isEmpty);
    });

    test('record while signed out writes nothing and keeps the item locally', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      expect(firestore.ops, isEmpty);
      expect(firestore.batches, 0);
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_a']);
    });

    test('record does not write to the previous account after owner changes during local persistence', () async {
      final Completer<void> gate = Completer<void>();
      final SyncedHistoryStore store = SyncedHistoryStore(
        SettingsLocalDataSource(_GatedSetLocalStore(gate)),
        firestore,
        ownerId: () => uid,
      );
      final Future<void> recording = store.record(_wall('a', _base));
      await Future<void>.delayed(Duration.zero);
      uid = '';
      gate.complete();

      await recording;
      expect(firestore.ops, isEmpty);
      expect(store.items().single.id, 'a');
    });

    test('recording an older entry keeps the newer local one and writes the newer doc', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', DateTime.utc(2026, 10, 20, 5)));
      uid = 'u1';
      await store.record(_wall('a', DateTime.utc(2026, 10, 20, 2)));
      expect(store.items(), hasLength(1));
      expect(store.items().single.at, DateTime.utc(2026, 10, 20, 5));
      expect(firestore.ops, <String>['set:usersv2/u1/history/wallhaven_a']);
    });

    test('prune past 500 writes the new set and deletes the single oldest key', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      for (int i = 0; i < 500; i++) {
        await store.record(_wall('w$i', _base.add(Duration(minutes: i))));
      }
      uid = 'u1';
      await store.record(_wall('new', _base.add(const Duration(minutes: 1000))));
      expect(firestore.ops, <String>['set:usersv2/u1/history/wallhaven_new', 'delete:usersv2/u1/history/wallhaven_w0']);
      expect(store.items(), hasLength(500));
      expect(store.items().first.id, 'new');
      expect(store.items().last.id, 'w1');
    });

    test('remove deletes locally and writes one delete', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      firestore.ops.clear();
      await store.remove('wallhaven_a');
      expect(store.items(), isEmpty);
      expect(firestore.ops, <String>['delete:usersv2/u1/history/wallhaven_a']);
    });

    test('clear deletes every account doc and empties the local list', () async {
      firestore.serverIds = <String>['wallhaven_a', 'wallhaven_b'];
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.clear();
      expect(firestore.ops, <String>['delete:usersv2/u1/history/wallhaven_a', 'delete:usersv2/u1/history/wallhaven_b']);
      expect(store.items(), isEmpty);
    });

    test('a stale remove during clear does not cancel account-wide deletion', () async {
      firestore.serverIds = <String>['wallhaven_a', 'wallhaven_b'];
      firestore.queryGate = Completer<void>();
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      final Future<void> clearing = store.clear();
      await Future<void>.delayed(Duration.zero);
      await store.remove('wallhaven_a');
      firestore.queryGate!.complete();
      await clearing;
      expect(firestore.ops, <String>['delete:usersv2/u1/history/wallhaven_a', 'delete:usersv2/u1/history/wallhaven_b']);
    });

    test('clearLocal empties the list, writes nothing, and the next restore runs again', () async {
      firestore.serverDocs = <Map<String, dynamic>>[_wall('a', DateTime.utc(2026, 10, 18, 10)).toDoc()];
      firestore.serverIds = <String>['wallhaven_a'];
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      expect(await store.restore('u1'), 1);
      firestore.ops.clear();

      await store.clearLocal();
      expect(store.items(), isEmpty);
      expect(firestore.ops, isEmpty);

      expect(await store.restore('u1'), 1);
      expect(firestore.queries, 2);
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_a']);
    });

    test('restore merges the newest of each wall, keeps action download, and uploads only local changes', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', DateTime.utc(2026, 10, 21, 10), action: HistoryAction.download));
      await store.record(_wall('c', DateTime.utc(2026, 10, 19, 11)));
      uid = 'u1';
      firestore.serverDocs = <Map<String, dynamic>>[
        _wall('a', DateTime.utc(2026, 10, 20, 10)).toDoc(),
        _wall('b', DateTime.utc(2026, 10, 19, 10)).toDoc(),
      ];
      firestore.serverIds = <String>['wallhaven_a', 'wallhaven_b'];

      expect(await store.restore('u1'), 2);
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_a', 'wallhaven_c', 'wallhaven_b']);
      expect(store.items().first.action, HistoryAction.download);
      expect(firestore.ops, <String>['set:usersv2/u1/history/wallhaven_a', 'set:usersv2/u1/history/wallhaven_c']);
    });

    test('restore uploads the seed walls like local ones', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      expect(await store.restore('u1', seed: <HistoryWall>[_wall('s', DateTime.utc(2026, 10, 18, 10))]), 0);
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_s']);
      expect(firestore.ops, <String>['set:usersv2/u1/history/wallhaven_s']);
    });

    test('applied Prism original is not used as a synced thumbnail seed', () async {
      final WallpaperHistoryStore applied = WallpaperHistoryStore(settings);
      const String gatedOriginal = 'https://storage.googleapis.com/private/original.jpg';
      await applied.record(
        AppliedWallpaper(
          id: 'history-1',
          source: 'prism',
          thumbnailUrl: gatedOriginal,
          fullUrl: gatedOriginal,
          target: 'home',
          appliedAt: _base,
          wallpaperId: 'catalogue-wall',
        ),
      );

      expect(appliedHistoryForSync(applied), isEmpty);
    });

    test('restore runs once per uid', () async {
      firestore.serverDocs = <Map<String, dynamic>>[_wall('a', DateTime.utc(2026, 10, 18, 10)).toDoc()];
      firestore.serverIds = <String>['wallhaven_a'];
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      expect(await store.restore('u1'), 1);
      firestore.ops.clear();
      expect(await store.restore('u1'), 0);
      expect(firestore.queries, 1);
      expect(firestore.ops, isEmpty);
    });

    test('overlapping restores for one uid share one server read', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      firestore.serverDocs = <Map<String, dynamic>>[_wall('a', _base).toDoc()];
      firestore.serverIds = <String>['wallhaven_a'];
      firestore.queryGate = Completer<void>();

      final Future<int> first = store.restore('u1');
      final Future<int> second = store.restore('u1');
      await Future<void>.delayed(Duration.zero);
      expect(firestore.queries, 1);
      firestore.queryGate!.complete();
      expect(await first, 1);
      expect(await second, 1);
      expect(firestore.queries, 1);
    });

    test('restore rethrows a failed query and a later restore tries again', () async {
      firestore.throwOnQuery = StateError('offline');
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await expectLater(store.restore('u1'), throwsStateError);

      firestore.throwOnQuery = null;
      firestore.serverDocs = <Map<String, dynamic>>[_wall('a', DateTime.utc(2026, 10, 18, 10)).toDoc()];
      firestore.serverIds = <String>['wallhaven_a'];
      expect(await store.restore('u1'), 1);
      expect(firestore.queries, 2);
    });

    test('restore caps at 500 and deletes the server walls that fall off', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      for (int i = 0; i < 200; i++) {
        await store.record(_wall('loc$i', _base.add(Duration(minutes: 400 + i))));
      }
      uid = 'u1';
      firestore.serverDocs = <Map<String, dynamic>>[
        for (int i = 0; i < 400; i++) _wall('srv$i', _base.add(Duration(minutes: i))).toDoc(),
      ];
      firestore.serverIds = <String>[for (int i = 0; i < 400; i++) 'wallhaven_srv$i'];
      firestore.ops.clear();

      expect(await store.restore('u1'), 400);
      expect(store.items(), hasLength(500));
      final List<String> deletes = firestore.ops.where((op) => op.startsWith('delete:')).toList();
      expect(deletes, hasLength(100));
      expect(deletes.toSet(), <String>{for (int i = 0; i < 100; i++) 'delete:usersv2/u1/history/wallhaven_srv$i'});
    });

    test('restore reads and deletes server entries beyond the 500-item cap', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      firestore.serverDocs = <Map<String, dynamic>>[
        for (int i = 0; i < 600; i++) _wall('srv$i', _base.add(Duration(minutes: i))).toDoc(),
      ];
      firestore.serverIds = <String>[for (int i = 0; i < 600; i++) 'wallhaven_srv$i'];

      expect(await store.restore('u1'), 600);
      expect(store.items(), hasLength(500));
      expect(firestore.ops.where((op) => op.startsWith('delete:')), hasLength(100));
      expect(firestore.querySpecs.single.cachePolicy, FirestoreCachePolicy.serverOnly);
    });

    test('restore does not resurrect an item removed while its server query is pending', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      uid = 'u1';
      firestore.serverDocs = <Map<String, dynamic>>[_wall('a', _base.add(const Duration(hours: 1))).toDoc()];
      firestore.serverIds = <String>['wallhaven_a'];
      firestore.queryGate = Completer<void>();

      final Future<int> restoring = store.restore('u1');
      await Future<void>.delayed(Duration.zero);
      await store.remove('wallhaven_a');
      firestore.queryGate!.complete();

      expect(await restoring, 0);
      expect(store.items(), isEmpty);
    });

    test('restore does not merge an account after the active uid changes', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      firestore.serverDocs = <Map<String, dynamic>>[_wall('server', _base).toDoc()];
      firestore.serverIds = <String>['wallhaven_server'];
      firestore.queryGate = Completer<void>();

      final Future<int> restoring = store.restore('u1');
      await Future<void>.delayed(Duration.zero);
      uid = '';
      firestore.queryGate!.complete();

      expect(await restoring, 0);
      expect(store.items(), isEmpty);
      expect(firestore.ops, isEmpty);
    });

    test('restore merges a record made while its server query is pending', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      firestore.serverDocs = <Map<String, dynamic>>[_wall('server', _base).toDoc()];
      firestore.serverIds = <String>['wallhaven_server'];
      firestore.queryGate = Completer<void>();

      final Future<int> restoring = store.restore('u1');
      await Future<void>.delayed(Duration.zero);
      await store.record(_wall('local', _base.add(const Duration(minutes: 1))));
      firestore.queryGate!.complete();

      expect(await restoring, 1);
      expect(store.items().map((wall) => wall.id), <String>['local', 'server']);
    });

    test('historyCountBucket maps counts to coarse buckets', () {
      expect(historyCountBucket(0), '0');
      expect(historyCountBucket(1), '1');
      expect(historyCountBucket(5), '2-5');
      expect(historyCountBucket(6), '6-20');
      expect(historyCountBucket(100), '21-100');
      expect(historyCountBucket(101), '101+');
    });
  });
}
