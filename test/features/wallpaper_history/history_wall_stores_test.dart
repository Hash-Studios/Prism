import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

class _Batch implements FirestoreBatch {
  _Batch(this.ops);

  final List<String> ops;

  @override
  void setDoc(String collection, String id, Map<String, dynamic> data) => ops.add('set:$collection/$id');

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

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    queries++;
    if (throwOnQuery != null) throw throwOnQuery!;
    return <T>[
      for (int i = 0; i < serverIds.length; i++)
        map(i < serverDocs.length ? serverDocs[i] : const <String, dynamic>{}, serverIds[i]),
    ];
  }

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) async {
    batches++;
    await action(_Batch(ops));
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
    test('record while signed in writes one set in one batch', () async {
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      expect(firestore.ops, <String>['set:usersv2/u1/history/wallhaven_a']);
      expect(firestore.batches, 1);
    });

    test('record while signed out writes nothing and keeps the item locally', () async {
      uid = '';
      final SyncedHistoryStore store = SyncedHistoryStore(settings, firestore, ownerId: () => uid);
      await store.record(_wall('a', _base));
      expect(firestore.ops, isEmpty);
      expect(firestore.batches, 0);
      expect(store.items().map((wall) => wall.key), <String>['wallhaven_a']);
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
      expect(deletes.first, 'delete:usersv2/u1/history/wallhaven_srv0');
      expect(deletes.last, 'delete:usersv2/u1/history/wallhaven_srv99');
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
