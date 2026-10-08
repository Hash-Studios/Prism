import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_merger.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';
import '../support/guest_store_fixture.dart';
import '../support/merge_firestore.dart';

void main() {
  late GuestFavouritesStore store;
  late FavoritesLocalDataSource local;
  late FakeAppAnalytics recorded;

  setUp(() {
    store = tempGuestStore();
    local = FavoritesLocalDataSource(InMemoryLocalStore());
    recorded = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorded;
  });

  tearDown(AnalyticsRuntime.reset);

  Future<void> saveGuest(String id) async {
    await store.put(id, <String, dynamic>{
      'id': id,
      'provider': 'pexels',
      'favouritedAt': DateTime.utc(2026, 2, 3),
      'createdAt': DateTime.utc(2026, 2, 3),
    });
    await local.setWallFavourite('', id, true);
  }

  test('adds the guest walls the account lacks, keeps existing server docs, then clears the guest list', () async {
    await saveGuest('new1');
    await saveGuest('already');
    final firestore = MergeFirestore(
      onQuery: (_) => <FakeDocRow>[
        (id: 'already', data: <String, dynamic>{'id': 'already'}),
      ],
    );

    final int merged = await GuestFavouritesMerger(firestore, store, local).mergeInto('uid');

    expect(merged, 1);
    expect(firestore.batchTags, <String>['favourite_walls.guest_merge']);
    final sets = firestore.batches.single.sets;
    expect(sets.map((set) => '${set.collection}/${set.id}'), <String>['usersv2/uid/images/new1']);
    expect(sets.single.data['favouritedAt'], DateTime.utc(2026, 2, 3), reason: 'dates go back to DateTime');
    expect(await store.readAll(), isEmpty);
    expect(local.isWallFavourite('', 'new1'), isFalse);
    expect(recorded.events.whereType<GuestFavouritesMergedEvent>().single.count, 1);
  });

  test('a full guest list of 200 goes in one batch', () async {
    for (int i = 0; i < GuestFavouritesStore.maxItems; i++) {
      await store.put('w$i', <String, dynamic>{'id': 'w$i'});
    }
    final firestore = MergeFirestore();

    final int merged = await GuestFavouritesMerger(firestore, store, local).mergeInto('uid');

    expect(merged, 200);
    expect(firestore.batches.map((batch) => batch.sets.length), <int>[200]);
  });

  test('a failed write keeps the guest list for the next try and tracks nothing', () async {
    await saveGuest('new1');
    final firestore = MergeFirestore()..batchError = StateError('offline');

    await expectLater(GuestFavouritesMerger(firestore, store, local).mergeInto('uid'), throwsStateError);

    expect((await store.readAll()).keys, <String>['new1']);
    expect(local.isWallFavourite('', 'new1'), isTrue);
    expect(recorded.events.whereType<GuestFavouritesMergedEvent>(), isEmpty);
  });

  test('an empty guest list does nothing and does not query', () async {
    final firestore = MergeFirestore();

    final int merged = await GuestFavouritesMerger(firestore, store, local).mergeInto('uid');

    expect(merged, 0);
    expect(firestore.querySpecs, isEmpty);
  });
}
