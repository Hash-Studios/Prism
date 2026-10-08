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
}
