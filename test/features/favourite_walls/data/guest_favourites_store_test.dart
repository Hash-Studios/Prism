import 'dart:convert';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/guest_store_fixture.dart';

void main() {
  test('put keeps the order, turns dates into ISO strings and reports the count', () async {
    final GuestFavouritesStore store = tempGuestStore();

    expect(await store.put('a', <String, dynamic>{'id': 'a', 'favouritedAt': DateTime.utc(2026, 1, 2)}), 1);
    expect(await store.put('b', <String, dynamic>{'id': 'b'}), 2);
    expect(await store.put('a', <String, dynamic>{'id': 'a', 'favouritedAt': DateTime.utc(2026, 1, 3)}), 2);

    final Map<String, Map<String, Object?>> all = await store.readAll();
    expect(all.keys, <String>['b', 'a'], reason: 'saving an id again moves it to the end');
    expect(all['a']!['favouritedAt'], '2026-01-03T00:00:00.000Z');
  });

  test('the 201st favourite drops the oldest one', () async {
    final GuestFavouritesStore store = tempGuestStore();

    for (int i = 0; i < GuestFavouritesStore.maxItems + 1; i++) {
      await store.put('w$i', <String, dynamic>{'id': 'w$i'});
    }

    final Map<String, Map<String, Object?>> all = await store.readAll();
    expect(all, hasLength(GuestFavouritesStore.maxItems));
    expect(all.containsKey('w0'), isFalse);
    expect(all.containsKey('w200'), isTrue);
  });

  test('remove drops the given ids and clear empties the store', () async {
    final GuestFavouritesStore store = tempGuestStore();
    await store.put('a', <String, dynamic>{'id': 'a'});
    await store.put('b', <String, dynamic>{'id': 'b'});

    await store.remove(<String>['a', 'missing']);
    expect((await store.readAll()).keys, <String>['b']);

    await store.clear();
    expect(await store.readAll(), isEmpty);
  });

  test('a new store instance restores guest favourites from the durable record', () async {
    final GuestFavouritesStore beforeRestart = tempGuestStore();
    await beforeRestart.put('saved-wall', <String, dynamic>{'id': 'saved-wall', 'provider': 'prism'});

    final GuestFavouritesStore afterRestart = GuestFavouritesStore(
      durableStore: DurableJsonStore('guest_favourites'),
      legacyCache: LazyFileCache('guest_favourites'),
    );

    expect((await afterRestart.readAll()).keys, <String>['saved-wall']);
  });

  test('imports the legacy cache into the durable snapshot', () async {
    final LazyFileCache legacy = LazyFileCache('guest_favourites');
    await legacy.set(
      'guest.favourites',
      jsonEncode(<String, Object?>{
        'legacy-wall': <String, Object?>{'id': 'legacy-wall', 'provider': 'prism'},
      }),
    );
    await legacy.flush();
    final GuestFavouritesStore store = GuestFavouritesStore(
      durableStore: DurableJsonStore('guest_favourites'),
      legacyCache: legacy,
    );

    expect((await store.readAll()).keys, <String>['legacy-wall']);
    expect(await DurableJsonStore('guest_favourites').read('__guest::snapshot'), isNotNull);
  });

  test('a failed durable write is reported and does not claim the guest favourite was saved', () async {
    final store = GuestFavouritesStore(
      durableStore: _FailingDurableStore(),
      legacyCache: LazyFileCache('unused_legacy'),
    );

    await expectLater(store.put('not-saved', <String, dynamic>{'id': 'not-saved'}), throwsStateError);
  });
}

class _FailingDurableStore extends DurableJsonStore {
  _FailingDurableStore() : super('failing_guest_favourites');

  @override
  Future<Map<String, Object?>?> read(String key) async => null;

  @override
  Future<void> write(String key, Map<String, Object?> value) async => throw StateError('disk full');
}
