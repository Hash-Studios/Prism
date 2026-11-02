import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';

void main() {
  late InMemoryLocalStore store;
  late FakeFirestoreClient firestore;

  LayoutPrefsStore newStore() => LayoutPrefsStore(SettingsLocalDataSource(store), firestore);

  setUp(() {
    store = InMemoryLocalStore();
    firestore = FakeFirestoreClient();
    app_state.prismUser = profileUser(loggedIn: false);
  });

  tearDown(() {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  test('a new store on the same device reads back the feed tab, density and hidden tabs', () async {
    final LayoutPrefsStore first = newStore();
    await first.setFeedTab(HomeFeedChip.latest);
    await first.update(
      first.value.copyWith(density: WallGridDensity.large).withTabVisible(NavTab.search, visible: false),
    );

    final LayoutPrefsStore restarted = newStore();

    expect(restarted.value.feedTab, HomeFeedChip.latest);
    expect(restarted.value.density, WallGridDensity.large);
    expect(restarted.value.hiddenTabs, <NavTab>{NavTab.search});
  });

  test('signed out update saves on the device and writes nothing to the account', () async {
    final LayoutPrefsStore layout = newStore();

    await layout.update(layout.value.withTabVisible(NavTab.search, visible: false));
    await pumpEventQueue();

    expect(layout.value.hiddenTabs, <NavTab>{NavTab.search});
    expect(firestore.writes, isEmpty);
    expect(firestore.docs[FirebaseCollections.usersV2]?['u1']?.containsKey('layoutPrefs') ?? false, isFalse);
  });

  test('signed in update writes tabs, hidden, density and changedAt to the account', () async {
    app_state.prismUser = profileUser();
    final LayoutPrefsStore layout = newStore();

    await layout.update(
      layout.value.copyWith(density: WallGridDensity.compact).withTabVisible(NavTab.rewards, visible: false),
    );
    await pumpEventQueue();

    expect(firestore.writes.single.op, 'update');
    expect(firestore.writes.single.collection, FirebaseCollections.usersV2);
    expect(firestore.writes.single.id, 'u1');
    final Map<String, Object?> pushed = firestore.writes.single.data!['layoutPrefs'] as Map<String, Object?>;
    expect(pushed.keys, unorderedEquals(<String>['tabs', 'hidden', 'density', 'changedAt']));
    expect(pushed['tabs'], <String>['home', 'search', 'rewards', 'collection']);
    expect(pushed['hidden'], <String>['rewards']);
    expect(pushed['density'], 'compact');
    expect(pushed['changedAt'], isA<int>());
  });

  test('sync applies a newer account copy and keeps the feed tab', () async {
    final LayoutPrefsStore layout = newStore();
    await layout.setFeedTab(HomeFeedChip.latest);
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'layoutPrefs': <String, Object>{
          'tabs': <String>['collection', 'home', 'search', 'rewards'],
          'hidden': <String>['rewards'],
          'density': 'compact',
          'changedAt': 1000,
        },
      },
    };

    await layout.syncWithAccount('u1');

    final LayoutPrefs applied = layout.value;
    expect(applied.tabOrder, <NavTab>[NavTab.collection, NavTab.home, NavTab.search, NavTab.rewards]);
    expect(applied.hiddenTabs, <NavTab>{NavTab.rewards});
    expect(applied.density, WallGridDensity.compact);
    expect(applied.feedTab, HomeFeedChip.latest);

    final LayoutPrefsStore restarted = newStore();
    expect(restarted.value, equals(applied));
    expect(store.data['settings.layout.changed_at'], 1000);
    expect(firestore.writes, isEmpty);
  });

  test('sync applies the account copy when this device has no local change', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'layoutPrefs': <String, Object>{
          'tabs': <String>['home', 'search', 'rewards', 'collection'],
          'hidden': <String>['search'],
          'density': 'large',
          'changedAt': 1000,
        },
      },
    };

    await newStore().syncWithAccount('u1');

    final LayoutPrefs restarted = newStore().value;
    expect(restarted.hiddenTabs, <NavTab>{NavTab.search});
    expect(restarted.density, WallGridDensity.large);
    expect(firestore.writes, isEmpty);
  });

  test('sync applies a newer account copy over an older local change', () async {
    await newStore().update(const LayoutPrefs().withTabVisible(NavTab.search, visible: false));
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'layoutPrefs': <String, Object>{
          'tabs': <String>['home', 'search', 'rewards', 'collection'],
          'hidden': <String>[],
          'density': 'large',
          'changedAt': 4102444800000,
        },
      },
    };

    final LayoutPrefsStore layout = newStore();
    await layout.syncWithAccount('u1');

    expect(layout.value.hiddenTabs, isEmpty);
    expect(layout.value.density, WallGridDensity.large);
    expect(store.data['settings.layout.changed_at'], 4102444800000);
  });

  test('sync uploads a local change that is newer than the account copy', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'layoutPrefs': <String, Object>{
          'tabs': <String>['home', 'search', 'rewards', 'collection'],
          'hidden': <String>[],
          'density': 'comfortable',
          'changedAt': 1000,
        },
      },
    };
    await newStore().update(const LayoutPrefs(density: WallGridDensity.large));

    await newStore().syncWithAccount('u1');

    expect(firestore.writes.single.op, 'update');
    expect(firestore.writes.single.id, 'u1');
    final Map<String, Object?> pushed = firestore.writes.single.data!['layoutPrefs'] as Map<String, Object?>;
    expect(pushed['density'], 'large');
    expect(pushed['hidden'], <String>[]);
    expect(pushed['changedAt'], store.data['settings.layout.changed_at']);
  });

  test('reset keeps the feed tab and restores the default layout', () async {
    final LayoutPrefsStore layout = newStore();
    await layout.setFeedTab(HomeFeedChip.latest);
    await layout.update(layout.value.withTabVisible(NavTab.search, visible: false));

    await layout.update(layout.value.resetLayout());

    expect(layout.value.isDefaultLayout, isTrue);
    expect(layout.value.feedTab, HomeFeedChip.latest);
  });

  test('setFeedTab never writes to the account, even when signed in', () async {
    app_state.prismUser = profileUser();
    final LayoutPrefsStore layout = newStore();

    await layout.setFeedTab(HomeFeedChip.trending);
    await pumpEventQueue();

    expect(layout.value.feedTab, HomeFeedChip.trending);
    expect(firestore.writes, isEmpty);
  });
}
